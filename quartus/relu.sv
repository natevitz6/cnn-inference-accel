// ============================================================
// relu.sv
// Vectorized ReLU activation: OUT_CH parallel channels
// out[i] = max(0, in[i])
// ============================================================

module relu #(
    parameter DATA_W = 8,   // bit-width per channel
    parameter OUT_CH = 16   // number of channels
)(
    input  logic clk,
    input  logic rst,

    // Input activations
    input  logic signed [DATA_W-1:0] in_data [0:OUT_CH-1],
    input  logic in_valid,

    // Output activations
    output logic signed [DATA_W-1:0] out_data [0:OUT_CH-1],
    output logic out_valid
);

    integer i;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < OUT_CH; i++) begin
                out_data[i] <= '0;
            end
            out_valid <= 1'b0;
        end else begin
            if (in_valid) begin
                for (i = 0; i < OUT_CH; i++) begin
                    out_data[i] <= (in_data[i] > 0) ? in_data[i] : '0;
                end
                out_valid <= 1'b1;
            end else begin
                out_valid <= 1'b0;
            end
        end
    end

endmodule
