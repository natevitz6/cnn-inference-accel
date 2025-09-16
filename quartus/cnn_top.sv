// cnn_top.sv
// Top-level CNN module
// Chains conv → relu → pool → conv → relu → pool → flatten → dense → relu → dense

module cnn_top #(
    // Layer 1
    parameter IN_H     = 28,
    parameter IN_W     = 28,
    parameter IN_CH    = 1,
    parameter CONV1_OUT_CH = 16,
    parameter string CONV1_W_FILE = "../../weights/conv1_weights.hex",
    parameter string CONV1_B_FILE = "../../weights/conv1_bias.hex",

    // Layer 2
    parameter CONV2_OUT_CH = 32,
    parameter string CONV2_W_FILE = "../../weights/conv2_weights.hex",
    parameter string CONV2_B_FILE = "../../weights/conv2_bias.hex",

    // Dense1
    parameter DENSE1_OUT   = 128,
    parameter string DENSE1_W_FILE = "../../weights/dense1_weights.hex",
    parameter string DENSE1_B_FILE = "../../weights/dense1_bias.hex",

    // Dense2
    parameter DENSE2_OUT   = 10,
    parameter string DENSE2_W_FILE = "../../weights/dense2_weights.hex",
    parameter string DENSE2_B_FILE = "../../weights/dense2_bias.hex",

    // Data widths
    parameter DATA_W   = 8,    // activations int8
    parameter W_W      = 8,    // weights int8
    parameter B_W      = 32,   // biases int32
    parameter ACC_W    = 32    // accumulators int32
)(
    input  logic clk,
    input  logic rst,

    // Input image stream
    input  logic signed [DATA_W-1:0] in_pixel,
    input  logic in_valid,
    output logic in_ready,

    // Final classification output
    output logic signed [DATA_W-1:0] class_scores [0:DENSE2_OUT-1],
    output logic out_valid
);

    // =========================================================
    // Conv1 → ReLU → Pool1
    // =========================================================
    logic signed [DATA_W-1:0] conv1_out [0:CONV1_OUT_CH-1];
    logic conv1_valid;

    conv_block #(
        .IN_CH(IN_CH),
        .OUT_CH(CONV1_OUT_CH),
        .IN_H(IN_H),
        .IN_W(IN_W),
        .WEIGHT_FILE(CONV1_W_FILE),
        .BIAS_FILE(CONV1_B_FILE)
    ) CONV1 (
        .clk(clk), .rst(rst),
        .in_pixel(in_pixel),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .out_vector(conv1_out),
        .out_valid(conv1_valid)
    );

    logic signed [DATA_W-1:0] relu1_out;
    logic relu1_valid;

    relu RELU1 (
        .clk(clk), .rst(rst),
        .in_data(conv1_out),
        .in_valid(conv1_valid),
        .out_data(relu1_out),
        .out_valid(relu1_valid)
    );

    logic signed [DATA_W-1:0] pool1_out;
    logic pool1_valid;

    maxpool #(
        .N_FILTERS(CONV1_OUT_CH),
        .DATA_W(DATA_W)
    ) MAXP1 (
        .clk(clk),
        .rst(rst),
        .in_data(relu1_out),
        .in_valid(relu1_valid),
        .out_data(pool1_out),
        .out_valid(pool1_valid)
    );

    // =========================================================
    // Conv2 → ReLU → Pool2
    // =========================================================
    logic signed [DATA_W-1:0] conv2_out [0:CONV2_OUT_CH-1];
    logic conv2_valid;

    conv2_block #(
        .IN_CH(CONV1_OUT_CH),
        .OUT_CH(CONV2_OUT_CH),
        .IN_H(IN_H/2),
        .IN_W(IN_W/2),
        .WEIGHT_FILE(CONV2_W_FILE),
        .BIAS_FILE(CONV2_B_FILE)
    ) CONV2 (
        .clk(clk), .rst(rst),
        .in_pixel(pool1_out),
        .in_valid(pool1_valid),
        .out_vector(conv2_out),
        .out_valid(conv2_valid)
    );

    logic signed [DATA_W-1:0] relu2_out;
    logic relu2_valid;

    relu RELU2 (
        .clk(clk), .rst(rst),
        .in_data(conv2_out),
        .in_valid(conv2_valid),
        .out_data(relu2_out),
        .out_valid(relu2_valid)
    );

    logic signed [DATA_W-1:0] pool2_out;
    logic pool2_valid;

    maxpool #(
        .N_FILTERS(CONV2_OUT_CH),
        .DATA_W(DATA_W)
    ) MAXP2 (
        .clk(clk),
        .rst(rst),
        .in_data(relu2_out),
        .in_valid(relu2_valid),
        .out_data(pool2_out),
        .out_valid(pool2_valid)
    );

    // =========================================================
    // Flatten → Dense1 → ReLU → Dense2
    // =========================================================
    logic signed [DATA_W-1:0] flat_out [0:(IN_H/4)*(IN_W/4)*CONV2_OUT_CH-1];
    logic flat_valid;

    flatten #(
        .IN_H(IN_H/4),
        .IN_W(IN_W/4),
        .IN_CH(CONV2_OUT_CH),
        .DATA_W(DATA_W)
    ) FLAT (
        .clk(clk), .rst(rst),
        .in_pixel(pool2_out),
        .in_valid(pool2_valid),
        .out_data(flat_out),
        .out_valid(flat_valid)
    );

    logic signed [DATA_W-1:0] dense1_out [0:DENSE1_OUT-1];
    logic dense1_valid;

    linear_layer #(
        .IN_SIZE((IN_H/4)*(IN_W/4)*CONV2_OUT_CH), // 1568
        .OUT_SIZE(DENSE1_OUT),
        .DATA_W(DATA_W),
        .W_W(W_W),
        .B_W(B_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(DENSE1_W_FILE),
        .BIAS_FILE(DENSE1_B_FILE)
    ) DENSE1 (
        .clk(clk), .rst(rst),
        .in_vec(flat_out),
        .start(flat_valid),
        .done(),
        .out_vec(dense1_out),
        .out_valid(dense1_valid)
    );

    logic signed [DATA_W-1:0] relu3_out;
    logic relu3_valid;

    relu RELU3 (
        .clk(clk), .rst(rst),
        .in_data(dense1_out),
        .in_valid(dense1_valid),
        .out_data(relu3_out),
        .out_valid(relu3_valid)
    );

    linear_layer #(
        .IN_SIZE(DENSE1_OUT),
        .OUT_SIZE(DENSE2_OUT),
        .DATA_W(DATA_W),
        .W_W(W_W),
        .B_W(B_W),
        .ACC_W(ACC_W),
        .WEIGHT_FILE(DENSE2_W_FILE),
        .BIAS_FILE(DENSE2_B_FILE)
    ) DENSE2 (
        .clk(clk), .rst(rst),
        .in_vec(relu3_out),
        .start(relu3_valid),
        .done(out_valid),
        .out_vec(class_scores),
        .out_valid()
    );

endmodule
