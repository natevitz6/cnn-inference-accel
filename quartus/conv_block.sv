// conv_block.sv
// High-level convolutional layer controller (vectorized outputs)
// - Input: single pixel stream (int8) from image_streamer / previous layer
// - Output: per-window vector of OUT_CH activations (each int8 after requantize)
// - Behavior: linebuf3 produces a 3x3 window; conv_layer computes OUT_CH accumulations
//   (each ACC_W bits) for that window all at once; requantize converts the OUT_CH
//   ACC_W values -> OUT_CH DATA_W values. The block emits one OUT_CH-vector per window.

module conv_block #(
    parameter IN_CH    = 1,      // input channels
    parameter OUT_CH   = 16,     // output filters
    parameter IN_H     = 28,     // input height
    parameter IN_W     = 28,     // input width
    parameter K        = 3,      // kernel size
    parameter DATA_W   = 8,      // pixel/activation width (int8)  (output of requantize)
    parameter W_W      = 8,      // weight width (int8)
    parameter B_W      = 32,     // bias width (int32)
    parameter ACC_W    = 32,     // accumulator width (int32)
    parameter SCALE_W  = 16,     // requant scale width
    parameter REQ_LATENCY = 1,   // latency of requantize (cycles)

    parameter string WEIGHT_FILE = "../../weights/conv1_weights.hex",
    parameter string BIAS_FILE   = "../../weights/conv1_bias.hex"
)(
    input  logic clk,
    input  logic rst,

    // Input pixel stream (from image_streamer or prev layer)
    input  logic signed [DATA_W-1:0] in_pixel,  // int8 pixel
    input  logic in_valid,
    output logic in_ready,

    // Output feature map stream (vectorized after requantize)
    // out_vector[0] .. out_vector[OUT_CH-1], each DATA_W bits (int8)
    output logic signed [DATA_W-1:0] out_vector [0:OUT_CH-1],
    output logic out_valid
);

    // =========================================================
    // Window generator (line buffer)
    // window is K*K*IN_CH int8 values (unpacked array)
    // window_valid pulses when a 3x3 window (with padding) is available
    // =========================================================
    logic signed [DATA_W-1:0] window [0:9-1];
    logic window_valid;
    logic [$clog2(IN_H)-1:0] y_pos;
    logic [$clog2(IN_W)-1:0] x_pos;

    linebuf3 #(
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
        .x_pos(x_pos),
        .in_ready(in_ready)
    );

    // =========================================================
    // Convolution engine instantiation (vectorized)
    // - conv_layer is expected to compute all OUT_CH filter outputs for the current window
    //   and present them as conv_out[0..OUT_CH-1] with a single conv_valid pulse.
    // - Each conv_out[i] is ACC_W bits (signed).
    // =========================================================
    logic conv_start; // one-cycle start pulse for conv_layer (per window)
    logic signed [ACC_W-1:0] conv_out [0:OUT_CH-1];
    logic conv_valid; // pulses when conv_out vector is valid

    conv_layer #(
        .IN_CH(IN_CH),
        .OUT_CH(OUT_CH),
        .K(K),
        .DATA_W(DATA_W),
        .W_W(W_W),
        .B_W(B_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(WEIGHT_FILE),
        .BIAS_FILE(BIAS_FILE)
    ) u_conv_layer (
        .clk      (clk),
        .rst      (rst),
        .window   (window),      // expects window as unpacked array K*K*IN_CH
        .start    (conv_start),  // one-cycle pulse to compute this window
        .out_data (conv_out),    // OUT_CH-length array of ACC_W each
        .out_valid(conv_valid)
    );


    logic [15:0] conv1_scale, conv1_shift;

    requant_params_rom #(
        .REQUANT_FILE("../../weights/requant_params.hex")
    ) conv1_requant_rom (
        .layer_sel(2'd0),   // conv1.bias entry
        .scale(conv1_scale),
        .shift(conv1_shift)
    );

    // =========================================================
    // Vectorized Requantizer (ACC_W[0..OUT_CH-1] -> DATA_W[0..OUT_CH-1])
    // - Assumes a requantize module that accepts an array of inputs and produces
    //   an array of outputs, with a single out_valid when vector is ready.
    // - If your existing requantize is scalar, you can instantiate OUT_CH copies or
    //   write a wrapper that vectorizes them.
    // =========================================================
    logic signed [DATA_W-1:0] requant_out [0:OUT_CH-1];
    logic requant_valid;

    requantize #(
        .IN_W  (ACC_W),
        .OUT_W (DATA_W),
        .SCALE_W(SCALE_W),
        .CH    (OUT_CH)
    ) u_requant_vec (
        .clk      (clk),
        .rst      (rst),
        .in_data  (conv_out),   // array [0:OUT_CH-1] of ACC_W
        .in_valid (conv_valid),
        .scale    (conv1_scale),
        .shift    (conv1_shift),
        .out_data (requant_out), // array [0:OUT_CH-1] of DATA_W
        .out_valid(requant_valid)
    );

    // =========================================================
    // Simple control FSM:
    // - On window_valid & not busy: assert conv_start (one cycle)
    // - Wait for conv_valid (vector of ACC_W results)
    // - Wait for requant_valid (vectorized DATA_W results)
    // - When requant_valid: drive out_vector and pulse out_valid
    // =========================================================
    typedef enum logic [1:0] {
        S_IDLE,
        S_WAIT_CONV,
        S_WAIT_REQUANT
    } state_t;

    state_t state;
    logic busy;
    logic conv_start_pulse;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            busy <= 1'b0;
            conv_start_pulse <= 1'b0;
            out_valid <= 1'b0;
            // clear outputs
            for (int i = 0; i < OUT_CH; i++) begin
                out_vector[i] <= '0;
            end
        end else begin
            // default deassert pulses/valids
            conv_start_pulse <= 1'b0;
            out_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (window_valid) begin
                        // start convolution for this window (compute all OUT_CH filter outputs)
                        busy <= 1'b1;
                        conv_start_pulse <= 1'b1;
                        state <= S_WAIT_CONV;
                    end
                end

                S_WAIT_CONV: begin
                    if (conv_valid) begin
                        // conv_out vector is ready and has been presented to requantizer
                        state <= S_WAIT_REQUANT;
                    end
                end

                S_WAIT_REQUANT: begin
                    if (requant_valid) begin
                        // requant_out vector ready: drive outputs
                        for (int i = 0; i < OUT_CH; i++) begin
                            out_vector[i] <= requant_out[i];
                        end
                        out_valid <= 1'b1;
                        busy <= 1'b0;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // connect pulse
    assign conv_start = conv_start_pulse;

endmodule
