// flatten_streaming.sv
// Collects 32x7x7 feature map streamed as 32x1x1 vectors (49 total).
// After receiving all, outputs a flattened 1568x1 vector one value per cycle.

module flatten_streaming #(
    parameter CH     = 32,
    parameter H      = 7,
    parameter W      = 7,
    parameter DATA_W = 8
)(
    input  logic clk,
    input  logic rst,

    // Input: 32 values (one per channel) per cycle
    input  logic in_valid,
    input  logic signed [DATA_W-1:0] in_vec [CH-1:0],

    // Output: one value per cycle (flattened stream)
    output logic out_valid,
    output logic signed [DATA_W-1:0] out_data,
    output logic [$clog2(CH*H*W)-1:0] out_index,
    output logic done
);

    // Internal buffer for full feature map
    logic signed [DATA_W-1:0] buffer [0:CH-1][0:H-1][0:W-1];

    // Counters for filling buffer
    logic [$clog2(H)-1:0] row_idx;
    logic [$clog2(W)-1:0] col_idx;

    // Counters for output stream
    logic [$clog2(CH)-1:0] ch_idx_out;
    logic [$clog2(H)-1:0] row_idx_out;
    logic [$clog2(W)-1:0] col_idx_out;

    typedef enum logic [1:0] {IDLE, COLLECT, STREAM} state_t;
    state_t state, next_state;

    // Count number of input vectors collected (0..48)
    logic [$clog2(H*W):0] vec_count;

    // Sequential state and buffer fill
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            vec_count  <= 0;
            row_idx    <= 0;
            col_idx    <= 0;
            ch_idx_out <= 0;
            row_idx_out<= 0;
            col_idx_out<= 0;
        end else begin
            state <= next_state;

            // Collect mode
            if (state == COLLECT && in_valid) begin
                for (int c = 0; c < CH; c++) begin
                    buffer[c][row_idx][col_idx] <= in_vec[c];
                end

                // Increment row/col
                if (col_idx == W-1) begin
                    col_idx <= 0;
                    row_idx <= row_idx + 1;
                end else begin
                    col_idx <= col_idx + 1;
                end

                vec_count <= vec_count + 1;
            end

            // Stream mode: increment indices
            if (state == STREAM && out_valid) begin
                if (col_idx_out == W-1) begin
                    col_idx_out <= 0;
                    if (row_idx_out == H-1) begin
                        row_idx_out <= 0;
                        if (ch_idx_out == CH-1) begin
                            ch_idx_out <= 0;
                        end else begin
                            ch_idx_out <= ch_idx_out + 1;
                        end
                    end else begin
                        row_idx_out <= row_idx_out + 1;
                    end
                end else begin
                    col_idx_out <= col_idx_out + 1;
                end
            end
        end
    end

    // FSM next state
    always_comb begin
        next_state = state;
        out_valid  = 0;
        done       = 0;

        case (state)
            IDLE: begin
                if (in_valid) next_state = COLLECT;
            end
            COLLECT: begin
                if (vec_count == H*W) next_state = STREAM;
            end
            STREAM: begin
                out_valid = 1;
                if (ch_idx_out == CH-1 && row_idx_out == H-1 && col_idx_out == W-1) begin
                    done       = 1;
                    next_state = IDLE; // ready for next feature map
                end
            end
        endcase
    end

    // Output flattened data
    assign out_data  = buffer[ch_idx_out][row_idx_out][col_idx_out];
    assign out_index = ch_idx_out*H*W + row_idx_out*W + col_idx_out;

endmodule
