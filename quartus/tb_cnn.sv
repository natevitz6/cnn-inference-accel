`timescale 1ns/1ps

module tb_cnn;

    // Parameters
    localparam CLK_PERIOD = 10;  // 100 MHz
    localparam DATA_W     = 8;
    localparam ACC_W      = 32;

    // Clock and reset
    logic clk;
    logic rst;

    always #(CLK_PERIOD/2) clk = ~clk;

    // Wires between image_streamer and cnn_top
    logic [DATA_W-1:0] img_pixel;
    logic              img_valid;
    logic              img_ready;
    logic              img_done;

    logic signed [ACC_W-1:0] class_scores [0:9];
    logic out_valid;

    // DUTs
    image_streamer #(
        .IMG_H(28),
        .IMG_W(28),
        .DATA_W(DATA_W),
        .IMG_FILE("../../weights/mnist_image.hex")   // your input file
    ) IMG_SRC (
        .clk(clk),
        .rst(rst),
        .out_pixel(img_pixel),
        .out_valid(img_valid),
        .out_ready(img_ready),
        .done(img_done)
    );

    cnn_top DUT (
        .clk(clk),
        .rst(rst),
        .in_pixel(img_pixel),
        .in_valid(img_valid),
        .in_ready(img_ready),
        .class_scores(class_scores),
        .out_valid(out_valid)
    );

    // Reset sequence
    initial begin
        clk = 0;
        rst = 1;
        #(5*CLK_PERIOD);
        rst = 0;
    end

    // Monitor outputs
    always_ff @(posedge clk) begin
        if (out_valid) begin
            $display("== CNN Classification Scores ==");
            for (int i = 0; i < 10; i++) begin
                $display("Class %0d: %0d", i, class_scores[i]);
            end
            $finish;
        end
    end

endmodule
