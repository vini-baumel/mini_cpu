module memory(
input wire clk,
input wire rst, // <= 1 quando ligar ou resetar
input wire we, // write enable
input wire [3:0] addr_r1, // Origem 1 (leitura)
input wire [3:0] addr_r2, // Origem 2 (leitura)
input wire [3:0] addr_w, // Destino (escrita)
input wire [15:0] data_in, // Input
output reg [15:0] data_out1,
output reg [15:0] data_out2
);

	reg [15:0] ram [0:15];
	integer i;
	
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			for (i = 0; i < 16; i = i + 1)begin
				ram[i] <= 16'b0;
			end
		end else if (we) begin
			ram[addr_w] <= data_in;
		end
	end
	
	// os dados de saída mudam sempre com os enderecos de entrada
	always @(*)begin
		data_out1 = ram[addr_r1];
		data_out2 = ram[addr_r2];
	end

endmodule