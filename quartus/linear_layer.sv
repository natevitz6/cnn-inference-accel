// linear_layer.sv
// Fully connected (dense) layer with streaming requantization
// IN_SIZE x OUT_SIZE matrix multiply + bias add
// Outputs requantized int8 activations

module linear_layer #(
    parameter IN_SIZE   = 1568,   // number of inputs
    parameter OUT_SIZE  = 128,    // number of outputs
    parameter DATA_W    = 8,      // input data width (int8 feature vector)
    parameter W_W       = 8,      // weight width (int8)
    parameter B_W       = 32,     // bias width (int32)
    parameter ACC_W     = 32,     // accumulator width (int32)
    parameter SCALE_W   = 16,     // requantization scale width

    // File parameters
    parameter string WEIGHT_FILE = "../../weights/dense1_weights.hex",
    parameter string BIAS_FILE   = "../../weights/dense1_bias.hex"
)(
    input  logic clk,
    input  logic rst,

    // Input vector (int8 activations after flatten/requantize)
    input  logic signed [DATA_W-1:0] in_vec [0:IN_SIZE-1],
    input  logic start,           // start one forward pass
    output logic done,            // all outputs ready

    // Outputs (requantized activations)
    output logic signed [DATA_W-1:0] out_vec [0:OUT_SIZE-1],
    output logic out_valid
);

    // =========================================================
    // ROMs for weights and biases
    // =========================================================
    localparam int W_DEPTH = IN_SIZE * OUT_SIZE;
    localparam int B_DEPTH = OUT_SIZE;

    logic signed [W_W-1:0] weight_mem [0:W_DEPTH-1];
    logic signed [B_W-1:0] bias_mem   [0:B_DEPTH-1];

    initial begin
        $readmemh(WEIGHT_FILE, weight_mem);
        $readmemh(BIAS_FILE,   bias_mem);
    end

    // =========================================================
    // Internal registers
    // =========================================================
    logic signed [ACC_W-1:0] acc;
    logic [$clog2(OUT_SIZE)-1:0] o;   // output neuron index
    logic [$clog2(IN_SIZE)-1:0]  i;   // input index
    logic running;

    // Buffer for final accum results (before requantization)
    logic signed [ACC_W-1:0] acc_buf [0:OUT_SIZE-1];

    // =========================================================
    // FSM for dot products
    // =========================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            acc       <= '0;
            o         <= '0;
            i         <= '0;
            running   <= 0;
            out_valid <= 0;
            done      <= 0;
        end else begin
            out_valid <= 0;
            done      <= 0;

            if (start && !running) begin
                // start fresh output neuron
                acc     <= 0;
                i       <= 0;
                o       <= 0;
                running <= 1;
            end else if (running) begin
                // accumulate input * weight
                acc <= acc + $signed(in_vec[i]) *
                             $signed(weight_mem[o*IN_SIZE + i]);

                if (i == IN_SIZE-1) begin
                    // finished dot product
                    acc_buf[o] <= acc + $signed(bias_mem[o]);

                    if (o == OUT_SIZE-1) begin
                        // all outputs done
                        running <= 0;
                        done    <= 1;
                    end else begin
                        // move to next output neuron
                        o   <= o + 1;
                        acc <= 0;
                        i   <= 0;
                    end
                end else begin
                    // next input
                    i <= i + 1;
                end
            end
        end
    end

    logic [15:0] linear_scale, linear_shift;

    requant_params_rom #(
        .REQUANT_FILE("../../weights/requant_params.hex")
    ) conv1_requant_rom (
        .layer_sel(2'd2),   // conv1.bias entry
        .scale(linear_scale),
        .shift(linear_shift)
    );

    // =========================================================
    // Requantize each output from acc_buf
    // =========================================================
    generate
        for (genvar j = 0; j < OUT_SIZE; j++) begin : REQ
            requantize #(
                .IN_W   (ACC_W),
                .OUT_W  (DATA_W),
                .SCALE_W(SCALE_W)
            ) u_requant (
                .clk(clk),
                .rst(rst),
                .in_data(acc_buf[j]),
                .in_valid(done),   // launch when all accumulations done
                .scale(linear_scale),
                .shift(linear_shift),
                .out_data(out_vec[j]),
                .out_valid(out_valid)
            );
        end
    endgenerate

endmodule
