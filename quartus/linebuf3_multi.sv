// linebuf3_multi.sv
// Multi-channel version of linebuf3
// Streams 16-channel feature maps into 3x3 sliding windows
// with zero-padding for convolutional layers in CNN accelerator.
//
// Input:  one vector of N_CH 8-bit activations at a time
// Output: full 3x3 window of N_CH vectors, along with (x,y) position

module linebuf3_multi #(
    parameter IMG_H   = 28,
    parameter IMG_W   = 28,
    parameter DATA_W  = 8,
    parameter N_CH    = 16
)(
    input  logic clk,
    input  logic rst,

    // Input: one pixel-vector per cycle
    input  logic signed [DATA_W-1:0] in_vec [0:N_CH-1],
    input  logic in_valid,

    // Output: 3x3 window of pixel-vectors
    output logic signed [DATA_W-1:0] window [0:9-1][0:N_CH-1],
    output logic window_valid,

    output logic [$clog2(IMG_H)-1:0] y_pos,
    output logic [$clog2(IMG_W)-1:0] x_pos
);

    // Internal counters
    logic [$clog2(IMG_W)-1:0] col;
    logic [$clog2(IMG_H)-1:0] row;

    // Line buffers for previous two rows
    logic signed [DATA_W-1:0] linebuf0 [0:IMG_W-1][0:N_CH-1];
    logic signed [DATA_W-1:0] linebuf1 [0:IMG_W-1][0:N_CH-1];

    // Shift registers for current row
    logic signed [DATA_W-1:0] shift_reg0 [0:N_CH-1];
    logic signed [DATA_W-1:0] shift_reg1 [0:N_CH-1];

    // Control: column and row increment
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            col <= 0;
            row <= 0;
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

    // Feed pixel-vectors into line buffers
    always_ff @(posedge clk) begin
        if (in_valid) begin
            for (int ch = 0; ch < N_CH; ch++) begin
                // Shift registers for current row
                shift_reg1[ch] <= shift_reg0[ch];
                shift_reg0[ch] <= in_vec[ch];

                // Update line buffers
                linebuf1[col][ch] <= linebuf0[col][ch];
                linebuf0[col][ch] <= in_vec[ch];
            end
        end
    end

    // Zero-padding: produce window values
    always_comb begin
        // Default outputs
        for (int i = 0; i < 9; i++)
            for (int ch = 0; ch < N_CH; ch++)
                window[i][ch] = '0;

        window_valid = 0;
        x_pos = col;
        y_pos = row;

        if (in_valid) begin
            int r_top    = row - 1;
            int r_mid    = row;
            int r_bottom = row + 1;

            int c_left   = col - 1;
            int c_mid    = col;
            int c_right  = col + 1;

            // Top row
            if (r_top >= 0) begin
                if (c_left  >= 0)       for (int ch=0; ch<N_CH; ch++) window[0][ch] = linebuf1[c_left][ch];
                if (c_mid   >= 0)       for (int ch=0; ch<N_CH; ch++) window[1][ch] = linebuf1[c_mid][ch];
                if (c_right < IMG_W)    for (int ch=0; ch<N_CH; ch++) window[2][ch] = linebuf1[c_right][ch];
            end
            // Middle row
            if (r_mid >= 0 && r_mid < IMG_H) begin
                if (c_left  >= 0)       for (int ch=0; ch<N_CH; ch++) window[3][ch] = linebuf0[c_left][ch];
                if (c_mid   >= 0)       for (int ch=0; ch<N_CH; ch++) window[4][ch] = linebuf0[c_mid][ch];
                if (c_right < IMG_W)    for (int ch=0; ch<N_CH; ch++) window[5][ch] = linebuf0[c_right][ch];
            end
            // Bottom row (coming in from shift regs + current input)
            if (r_bottom < IMG_H) begin
                if (c_left  >= 0)       for (int ch=0; ch<N_CH; ch++) window[6][ch] = shift_reg1[ch];
                if (c_mid   >= 0)       for (int ch=0; ch<N_CH; ch++) window[7][ch] = shift_reg0[ch];
                if (c_right < IMG_W)    for (int ch=0; ch<N_CH; ch++) window[8][ch] = in_vec[ch];
            end

            // Mark valid once enough pixels streamed to fill 3x3
            if (row >= 0 && col >= 0)
                window_valid = 1;
        end
    end

endmodule
