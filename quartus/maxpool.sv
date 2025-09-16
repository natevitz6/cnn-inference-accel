// ============================================================
// maxpool.sv
// 2×2 MaxPooling layer with stride 2
// Produces one pooled OUT_CH vector (8-bit) per valid window
// Streams 14×14×OUT_CH outputs for a 28×28×OUT_CH input
// ============================================================

module maxpool #(
    parameter OUT_CH = 16,   // number of channels (e.g. 16)
    parameter DATA_W = 8,    // bit-width per channel
    parameter IN_W   = 28    // input feature map width
)(
    input  logic clk,
    input  logic rst,

    // Input: one OUT_CH-wide vector per cycle (a column of pixels across all channels)
    input  logic signed [DATA_W-1:0] in_data [0:OUT_CH-1],
    input  logic in_valid,

    // Output: pooled activation (16 channels, 8-bit each)
    output logic signed [DATA_W-1:0] out_data [0:OUT_CH-1],
    output logic out_valid
);

    // ============================================================
    // Buffers for two consecutive rows
    // ============================================================
    logic signed [DATA_W-1:0] row_buf0 [0:IN_W-1][0:OUT_CH-1];
    logic signed [DATA_W-1:0] row_buf1 [0:IN_W-1][0:OUT_CH-1];

    integer col_idx;
    integer row_idx;

    // Indicates when we can start pooling
    logic rows_ready;

    // ============================================================
    // State machine control
    // ============================================================
    typedef enum logic [1:0] {
        IDLE,
        FILLING,
        POOLING
    } state_t;

    state_t state;

    // Output indices (stride 2)
    integer pool_row;
    integer pool_col;

    // ============================================================
    // Input collection
    // ============================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            col_idx    <= 0;
            row_idx    <= 0;
            rows_ready <= 1'b0;
            state      <= IDLE;
            out_valid  <= 1'b0;
            pool_row   <= 0;
            pool_col   <= 0;
        end else begin
            out_valid <= 1'b0;

            case (state)
                IDLE: begin
                    if (in_valid) begin
                        // Store into first row buffer
                        for (int ch = 0; ch < OUT_CH; ch++)
                            row_buf0[col_idx][ch] <= in_data[ch];

                        col_idx <= col_idx + 1;
                        state   <= FILLING;
                    end
                end

                FILLING: begin
                    if (in_valid) begin
                        // Write current row (even -> row_buf0, odd -> row_buf1)
                        if (row_idx[0] == 0) begin
                            for (int ch = 0; ch < OUT_CH; ch++)
                                row_buf0[col_idx][ch] <= in_data[ch];
                        end else begin
                            for (int ch = 0; ch < OUT_CH; ch++)
                                row_buf1[col_idx][ch] <= in_data[ch];
                        end

                        // Increment column
                        if (col_idx == IN_W-1) begin
                            col_idx <= 0;
                            row_idx <= row_idx + 1;

                            if (row_idx[0] == 1) begin
                                // Two rows are ready
                                rows_ready <= 1'b1;
                                pool_row   <= 0;
                                pool_col   <= 0;
                                state      <= POOLING;
                            end
                        end else begin
                            col_idx <= col_idx + 1;
                        end
                    end
                end

                POOLING: begin
                    // Perform pooling for the current 2×2 block
                    for (int ch = 0; ch < OUT_CH; ch++) begin
                        logic signed [DATA_W-1:0] v00, v01, v10, v11, max_val;
                        int base_col = pool_col*2;
                        v00 = row_buf0[base_col+0][ch];
                        v01 = row_buf0[base_col+1][ch];
                        v10 = row_buf1[base_col+0][ch];
                        v11 = row_buf1[base_col+1][ch];
                        max_val = v00;
                        if (v01 > max_val) max_val = v01;
                        if (v10 > max_val) max_val = v10;
                        if (v11 > max_val) max_val = v11;
                        out_data[ch] <= max_val;
                    end

                    out_valid <= 1'b1;

                    // Advance to next pooling window
                    if (pool_col == (IN_W/2 - 1)) begin
                        pool_col <= 0;
                        if (pool_row == (IN_W/2 - 1)) begin
                            // Finished all 14×14 outputs for this 28×28 input
                            state      <= FILLING;
                            row_idx    <= 0;
                            rows_ready <= 1'b0;
                        end else begin
                            pool_row <= pool_row + 1;
                        end
                    end else begin
                        pool_col <= pool_col + 1;
                    end
                end
            endcase
        end
    end

endmodule
