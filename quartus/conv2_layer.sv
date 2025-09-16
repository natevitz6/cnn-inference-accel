// conv2_layer.sv
// Multi-channel convolution layer
// Takes a 3x3xN_IN input window and applies OUT_CH filters
// Outputs OUT_CH 32-bit accumulated values

module conv2_layer #(
    parameter N_IN    = 16,   // input channels
    parameter OUT_CH  = 32,   // number of filters
    parameter K       = 3,    // kernel size
    parameter DATA_W  = 8,    // input activation width
    parameter W_W     = 8,    // weight width
    parameter ACC_W   = 32    // accumulation width
)(
    input  logic clk,
    input  logic rst,

    // Input window: 3x3xN_IN
    input  logic signed [DATA_W-1:0] window [0:K*K-1][0:N_IN-1],
    input  logic window_valid,

    // Output: OUT_CH accumulated results
    output logic signed [ACC_W-1:0] out_vec [0:OUT_CH-1],
    output logic out_valid
);

    // Weights: OUT_CH filters, each with N_IN * K*K weights
    // Assume preloaded from external memory/file
    logic signed [W_W-1:0] weights [0:OUT_CH-1][0:N_IN-1][0:K*K-1];
    logic signed [ACC_W-1:0] bias [0:OUT_CH-1];

    // Accumulators
    logic signed [ACC_W-1:0] acc [0:OUT_CH-1];

    // Convolution compute
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int f = 0; f < OUT_CH; f++) begin
                out_vec[f] <= '0;
            end
            out_valid <= 1'b0;
        end else begin
            if (window_valid) begin
                for (int f = 0; f < OUT_CH; f++) begin
                    acc[f] = bias[f];
                    for (int ch = 0; ch < N_IN; ch++) begin
                        for (int k = 0; k < K*K; k++) begin
                            acc[f] += window[k][ch] * weights[f][ch][k];
                        end
                    end
                    out_vec[f] <= acc[f];
                end
                out_valid <= 1'b1;
            end else begin
                out_valid <= 1'b0;
            end
        end
    end

endmodule
