module module_alu(
input wire [2:0] opcode,
input wire signed [15:0] num1,
input wire signed [15:0] num2,
output reg signed [15:0] resultado
);

	always @(*) begin
		case(opcode)
			3'b000: // LOAD
				resultado = num1;
				
			3'b001, 3'b010: // ADD e ADDI
				resultado = num1 + num2;
				
			3'b011, 3'b100: // SUB e SUBI
				resultado = num1 - num2;
				
			3'b101: // MUL
				resultado = num1 * num2;
				
			3'b111: //DISPLAY
				resultado = num1;
				
			default:
				resultado = 16'd0;
		endcase
	end

endmodule