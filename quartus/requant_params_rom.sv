module requant_params_rom #(
    parameter string REQUANT_FILE = "../../weights/requant_params.hex"
)(
    input  logic [1:0] layer_sel,   // 0=conv1, 1=conv2, 2=fc1, 3=fc2
    output logic [15:0] scale,
    output logic [15:0] shift
);

    logic [31:0] mem [0:3];

    initial begin
        $readmemh(REQUANT_FILE, mem);
    end

    assign scale = mem[layer_sel][31:16];
    assign shift = mem[layer_sel][15:0];

endmodule
