// ============================================================
// requantize.sv
// Converts int32 accumulators back to int8 feature maps
// Vectorized: handles OUT_CH parallel channels
// ============================================================

module requantize #(
    parameter IN_W    = 32,   // accumulator width
    parameter OUT_W   = 8,    // activation width
    parameter SCALE_W = 16,   // scale factor width (fixed-point Q-format)
    parameter OUT_CH  = 16    // number of channels (matches conv_layer)
)(
    input  logic clk,
    input  logic rst,

    // Input from conv accumulator: OUT_CH parallel int32s
    input  logic signed [IN_W-1:0] in_data [0:OUT_CH-1],
    input  logic in_valid,

    // Learned quantization parameters (shared across layer)
    input  logic [SCALE_W-1:0] scale, // fixed-point multiplier (Qx.y format)
    input  logic [7:0]         shift, // right-shift amount (for rescaling)

    // Output quantized activations: OUT_CH parallel int8s
    output logic signed [OUT_W-1:0] out_data [0:OUT_CH-1],
    output logic out_valid
);

    // Intermediate signals
    logic signed [IN_W+SCALE_W-1:0] mult_result [0:OUT_CH-1];
    logic signed [IN_W-1:0] shifted [0:OUT_CH-1];
    logic signed [IN_W-1:0] clamped [0:OUT_CH-1];

    integer i;

    // Multiply by scale
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < OUT_CH; i++) begin
                mult_result[i] <= '0;
            end
        end else if (in_valid) begin
            for (i = 0; i < OUT_CH; i++) begin
                mult_result[i] <= in_data[i] * scale;
            end
        end
    end

    // Shift + clamp
    always_comb begin
        for (i = 0; i < OUT_CH; i++) begin
            shifted[i] = mult_result[i] >>> shift;

            // Clamp to int8 range [-128, 127]
            if (shifted[i] > 127)
                clamped[i] = 127;
            else if (shifted[i] < -128)
                clamped[i] = -128;
            else
                clamped[i] = shifted[i];
        end
    end

    // Register outputs
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < OUT_CH; i++) begin
                out_data[i] <= '0;
            end
            out_valid <= 1'b0;
        end else begin
            for (i = 0; i < OUT_CH; i++) begin
                out_data[i] <= clamped[i][OUT_W-1:0];
            end
            out_valid <= in_valid;
        end
    end

endmodule
