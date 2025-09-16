// conv2_block.sv
// High-level convolutional block for Conv2
// Sweeps 3x3 windows across input feature map with multiple input channels
// Iterates across OUT_CH filters
// Instantiates conv2_layer with file-based weights/biases

module conv2_block #(
    parameter IN_CH    = 16,    // input channels (from Conv1)
    parameter OUT_CH   = 32,    // output filters
    parameter IN_H     = 14,    // input height after pooling
    parameter IN_W     = 14,    // input width after pooling
    parameter K        = 3,     // kernel size
    parameter DATA_W   = 8,     // input pixel width (int8)
    parameter W_W      = 8,     // weight width (int8)
    parameter B_W      = 32,    // bias width (int32 for accumulation scale)
    parameter ACC_W    = 32,    // accumulator width (int32)

    parameter string WEIGHT_FILE = "../../weights/conv2_weights.hex",
    parameter string BIAS_FILE   = "../../weights/conv2_bias.hex"
)(
    input  logic clk,
    input  logic rst,

    // Input feature map stream (int8 per channel)
    input  logic signed [DATA_W-1:0] in_pixel [0:IN_CH-1],
    input  logic in_valid,
    output logic in_ready,

    // Output feature map stream
    output logic signed [ACC_W-1:0] out_pixel,  // before requantization
    output logic out_valid,
    output logic [$clog2(OUT_CH)-1:0] out_filter, // which filter index
    output logic [$clog2(IN_H)-1:0]   out_y,
    output logic [$clog2(IN_W)-1:0]   out_x
);

    // =========================================================
    // Multi-channel line buffer
    // =========================================================
    logic signed [DATA_W-1:0] window [0:K*K-1][0:N_IN-1];
    logic              window_valid;
    logic [$clog2(IN_H)-1:0] y_pos;
    logic [$clog2(IN_W)-1:0] x_pos;

    linebuf3_multi #(
        .IN_CH(IN_CH),
        .IMG_H(IN_H),
        .IMG_W(IN_W),
        .DATA_W(DATA_W)
    ) LBUF (
        .clk(clk),
        .rst(rst),
        .in_pixel(in_pixel),
        .in_valid(in_valid),
        .window(window),
        .window_valid(window_valid),
        .y_pos(y_pos),
        .x_pos(x_pos)
    );

    // =========================================================
    // Instantiate conv2_layer
    // =========================================================
    logic signed [ACC_W-1:0] conv_out [0:OUT_CH-1];
    logic conv_valid, conv_done;
    logic conv_start;

    conv2_layer #(
        .IN_CH(IN_CH),
        .OUT_CH(OUT_CH),
        .K(K),
        .DATA_W(DATA_W),
        .W_W(W_W),
        .B_W(B_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(WEIGHT_FILE),
        .BIAS_FILE(BIAS_FILE)
    ) CENG (
        .clk(clk),
        .rst(rst),
        .window(window),
        .start(conv_start),
        .done(conv_done),
        .out_data(conv_out),
        .out_valid(conv_valid)
    );

    logic [15:0] conv2_scale, conv2_shift;

    requant_params_rom #(
        .REQUANT_FILE("../../weights/requant_params.hex")
    ) conv1_requant_rom (
        .layer_sel(2'd1), 
        .scale(conv2_scale),
        .shift(conv2_shift)
    );

    requantize #(
        .IN_W   (ACC_W),
        .OUT_W  (DATA_W),
        .SCALE_W(SCALE_W)
    ) u_requant (
        .clk(clk),
        .rst(rst),
        .in_data(conv_out),
        .in_valid(conv_valid),
        .scale(conv2_scale),
        .shift(conv2_shift),
        .out_data(out_pixel),
        .out_valid(out_valid)
    );

    // =========================================================
    // Control FSM
    // =========================================================
    typedef enum logic [1:0] {
        S_IDLE,
        S_WAIT_WINDOW,
        S_RUN_FILTER,
        S_OUTPUT
    } state_t;

    state_t state, next_state;
    logic [$clog2(OUT_CH)-1:0] f;   // filter index

    // State register
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            f <= 0;
        end else begin
            state <= next_state;
        end
    end

    // FSM logic
    always_comb begin
        next_state = state;
        conv_start = 0;
        in_ready   = 1;

        out_valid  = 0;
        out_pixel  = 0;
        out_filter = f;
        out_y      = y_pos;
        out_x      = x_pos;

        case (state)
            S_IDLE: begin
                if (window_valid) begin
                    f = 0;
                    next_state = S_RUN_FILTER;
                end
            end

            S_RUN_FILTER: begin
                conv_start = 1;
                if (conv_done) begin
                    next_state = S_OUTPUT;
                end
            end

            S_OUTPUT: begin
                if (conv_valid) begin
                    out_valid  = 1;
                    out_pixel  = conv_out;
                    out_filter = f;
                    out_y      = y_pos;
                    out_x      = x_pos;
                end

                if (f == OUT_CH-1) begin
                    next_state = S_WAIT_WINDOW;
                end else begin
                    f = f + 1;
                    next_state = S_RUN_FILTER;
                end
            end

            S_WAIT_WINDOW: begin
                if (window_valid) begin
                    f = 0;
                    next_state = S_RUN_FILTER;
                end
            end
        endcase
    end

endmodule
