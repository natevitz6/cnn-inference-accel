// conv_layer.sv
// Convolution layer with parallel output of all filters (no requantization)
// Takes in 3x3 window, applies OUT_CH filters, accumulates, adds bias
// Outputs OUT_CH parallel 32-bit accumulated results

module conv_layer #(
    parameter IN_CH    = 1,
    parameter OUT_CH   = 16,
    parameter K        = 3,
    parameter DATA_W   = 8,    // input activations
    parameter W_W      = 8,    // weights
    parameter B_W      = 32,   // bias width
    parameter ACC_W    = 32,   // accumulator

    parameter string WEIGHT_FILE = "../../weights/conv1_weights.hex",
    parameter string BIAS_FILE   = "../../weights/conv1_bias.hex",
    parameter string REQUANT_FILE   = "../../weights/requant_params"
)(
    input  logic clk,
    input  logic rst,

    // Flattened input window: K*K*IN_CH activations
    input  logic signed [DATA_W-1:0] window [0:K*K*IN_CH-1],

    input  logic start,
    output logic done,

    // Parallel outputs: one 32-bit accumulated result per filter
    output logic signed [ACC_W-1:0] out_data [0:OUT_CH-1]
);

    // =========================================================
    // ROMs for weights and biases
    // =========================================================
    localparam int W_DEPTH = K*K*IN_CH*OUT_CH;
    localparam int B_DEPTH = OUT_CH;

    logic signed [W_W-1:0] weight_mem [0:W_DEPTH-1];
    logic signed [B_W-1:0] bias_mem   [0:B_DEPTH-1];

    initial begin
        $readmemh(WEIGHT_FILE, weight_mem);
        $readmemh(BIAS_FILE,   bias_mem);
    end

    // =========================================================
    // Internal registers
    // =========================================================
    logic running;
    integer f, idx;

    // =========================================================
    // FSM for computing all filters
    // =========================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            running <= 0;
            done    <= 0;
            for (f = 0; f < OUT_CH; f++) begin
                out_data[f] <= '0;
            end
        end else begin
            done <= 0;

            if (start && !running) begin
                // Start convolution: clear accumulators
                for (f = 0; f < OUT_CH; f++) begin
                    out_data[f] <= bias_mem[f]; // preload with bias
                end
                running <= 1;
            end else if (running) begin
                // Perform convolution for all filters
                for (f = 0; f < OUT_CH; f++) begin
                    for (idx = 0; idx < IN_CH*K*K; idx++) begin
                        out_data[f] <= out_data[f] +
                                       $signed(window[idx]) *
                                       $signed(weight_mem[f*(IN_CH*K*K) + idx]);
                    end
                end

                running <= 0;
                done    <= 1;
            end
        end
    end

endmodule
