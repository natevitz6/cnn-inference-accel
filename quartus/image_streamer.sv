// image_streamer.sv
// Streams a single MNIST image (28x28, 8-bit pixels) into CNN
// Reads from a .hex file into internal BRAM, then outputs sequentially.

module image_streamer #(
    parameter IMG_H   = 28,
    parameter IMG_W   = 28,
    parameter DATA_W  = 8,
    parameter string IMG_FILE = "../../weights/mnist_image.hex"
)(
    input  logic clk,
    input  logic rst,

    // Stream output to cnn_top
    output logic [DATA_W-1:0] out_pixel, // 8-bit pixel
    output logic              out_valid,
    input  logic              out_ready,

    // Signal when image is done
    output logic done
);

    localparam TOTAL_PIXELS = IMG_H * IMG_W;
    localparam ADDR_W       = $clog2(TOTAL_PIXELS);

    // Memory to hold the image
    logic [DATA_W-1:0] image_mem [0:TOTAL_PIXELS-1];
    initial begin
        $readmemh(IMG_FILE, image_mem);
    end

    // Counters
    logic [ADDR_W-1:0] pixel_idx;
    logic streaming;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pixel_idx <= 0;
            streaming <= 1'b0;
            done      <= 1'b0;
        end else begin
            if (!streaming) begin
                // Start streaming after reset
                streaming <= 1'b1;
                pixel_idx <= 0;
                done      <= 1'b0;
            end else if (streaming && out_ready) begin
                if (pixel_idx == TOTAL_PIXELS-1) begin
                    streaming <= 1'b0;
                    done      <= 1'b1;
                    pixel_idx <= 0;
                end else begin
                    pixel_idx <= pixel_idx + 1;
                end
            end
        end
    end

    // Output pixel
    assign out_pixel = image_mem[pixel_idx];
    assign out_valid = streaming;

endmodule
