// linebuf3.sv
// Streams pixels into a 3x3 sliding window with zero-padding
// for convolutional layers in CNN accelerator.
//
// Input:  one pixel at a time
// Output: full 3x3 window when valid, along with (x,y) position

module linebuf3 #(
    parameter IMG_H   = 28,
    parameter IMG_W   = 28,
    parameter DATA_W  = 8
)(
    input  logic clk,
    input  logic rst,

    input  logic [DATA_W-1:0] in_pixel, // 8-bit
    input  logic in_valid,

    output logic [DATA_W-1:0] window [0:9-1], // 3x3=9 pixels
    output logic window_valid,

    output logic [$clog2(IMG_H)-1:0] y_pos,
    output logic [$clog2(IMG_W)-1:0] x_pos,
    output logic in_ready
)

    // Internal counters
    logic [$clog2(IMG_W)-1:0] col;
    logic [$clog2(IMG_H)-1:0] row;

    // Line buffers (store previous two rows)
    logic [DATA_W-1:0] linebuf0 [0:IMG_W-1];
    logic [DATA_W-1:0] linebuf1 [0:IMG_W-1];

    // Shift registers for current row
    logic [DATA_W-1:0] shift_reg0, shift_reg1;

    // Control: column and row increment
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            col <= 0;
            row <= 0;
            in_ready <= 1;
        end else if (in_valid) begin
            if (col == IMG_W-1) begin
                col <= 0;
                if (row == IMG_H-1)
                    row <= 0;
                else
                    row <= row + 1;
            end else begin
                col <= col + 1;
            end
        end
    end

    // Feed pixels into line buffers
    always_ff @(posedge clk) begin
        if (in_valid && in_ready) begin
            // Shift registers for current row
            shift_reg1 <= shift_reg0;
            shift_reg0 <= in_pixel;

            // Update line buffers
            linebuf1[col] <= linebuf0[col];
            linebuf0[col] <= in_pixel;
        end
    end

    // Zero-padding: produce window values
    integer i;
    always_comb begin
        // Default outputs
        for (i = 0; i < 9; i++)
            window[i] = '0;

        // Valid only when inside image grid
        window_valid = 0;
        x_pos = col;
        y_pos = row;

        if (in_valid) begin
            // Row indices for top/mid/bottom rows
            int r_top    = row - 1;
            int r_mid    = row;
            int r_bottom = row + 1;

            int c_left   = col - 1;
            int c_mid    = col;
            int c_right  = col + 1;

            // For each neighbor, check bounds
            // Top row
            if (r_top >= 0) begin
                if (c_left  >= 0) window[0] = linebuf1[c_left];
                if (c_mid   >= 0) window[1] = linebuf1[c_mid];
                if (c_right < IMG_W) window[2] = linebuf1[c_right];
            end
            // Middle row
            if (r_mid >= 0 && r_mid < IMG_H) begin
                if (c_left  >= 0) window[3] = linebuf0[c_left];
                if (c_mid   >= 0) window[4] = linebuf0[c_mid];
                if (c_right < IMG_W) window[5] = linebuf0[c_right];
            end
            // Bottom row (coming in from shift regs)
            if (r_bottom < IMG_H) begin
                if (c_left  >= 0) window[6] = (c_left == col-1) ? shift_reg1 : '0;
                if (c_mid   >= 0) window[7] = (c_mid == col)   ? shift_reg0 : '0;
                if (c_right < IMG_W) window[8] = in_pixel;
            end

            // Mark valid once enough pixels streamed to fill 3x3
            if (row >= 0 && col >= 0)
                window_valid = 1;
        end
    end

endmodule
