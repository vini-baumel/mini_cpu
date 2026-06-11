module lcd_controller_top (
	input wire clk,
   input wire rst,
    
	// Conexão com a CPU
	input wire start,
   input wire [2:0] opcode, // operacao
   input wire [3:0] addr_wr, // endereco do registrador
   input wire [15:0] data_in, // resultado
   output wire ocupado,   
	
	// Saídas para o LCD físico da Placa
	output wire [7:0] lcd_data,
   output wire lcd_rs,
   output wire lcd_rw,
   output wire lcd_e
);

	wire [7:0] init_data;
   wire init_rs;
   wire init_rw;
   wire init_e;
   wire init_done;
   reg start_init; 
	
	lcd_init_hd44780 lcd_init (
		.clk(clk),
		.rst(rst),
		.start(start_init),
		.done(init_done),
		.lcd_data(init_data),
		.lcd_rs(init_rs),
		.lcd_rw(init_rw),
		.lcd_e(init_e)
	);
	
	wire controller_mode = init_done;
	assign lcd_data = (controller_mode == 0) ? init_data : wr_data;
	assign lcd_rs = (controller_mode == 0) ? init_rs : wr_rs;
	assign lcd_rw = (controller_mode == 0) ? init_rw : wr_rw;
	assign lcd_e = (controller_mode == 0) ? init_e : wr_e;
	
	// ============================== formatacao de mensagem ==============================
	localparam integer MSG_LEN = 34; 
	
	// mensagem (o 8 bit indica se é comando (0) ou texto(1))
	reg [8:0] message [0:MSG_LEN-1]; 
	
	// dados da cpu no momento do start
	reg [15:0] latched_dado; 
	reg [3:0] latched_opcode;
	reg [3:0] latched_addr;
	
	// decodificador de opcode para texto
	reg [55:0] op_str;
	always @(*) begin
		case (latched_opcode)
			4'd0: op_str = "LOAD   ";
			4'd1: op_str = "ADD    ";
			4'd2: op_str = "ADDI   ";
			4'd3: op_str = "SUB    ";
			4'd4: op_str = "SUBI   ";
			4'd5: op_str = "MUL    ";
			4'd6: op_str = "CLEAR  ";
			4'd7: op_str = "DISPLAY";
			4'd8: op_str = "----   "; // mais um "estado" do opcode para a tela padrão
			default: op_str = "UNK    ";
		endcase
	end
	
	// extrator de sinal e absoluto para decimal
	// transforma o complemento de 2
	wire [15:0] abs_val = (latched_dado[15]) ? (~latched_dado + 16'd1) : latched_dado;
	wire [7:0] char_sign = (latched_dado[15]) ? 8'h2D : 8'h2B; // Hex 2D='-', 2B='+'
	
	// funcao para extrair os dígitos decimais
	function [7:0] get_digit;
		input [15:0] value;
		input [2:0] digit_idx;
		reg [15:0] temp;
		begin
			case (digit_idx)
				0: temp = (value % 10);
				1: temp = (value / 10) % 10;
				2: temp = (value / 100) % 10;
				3: temp = (value / 1000) % 10;
				4: temp = (value / 10000) % 10;
				default: temp = 0;
			endcase
			get_digit = temp[7:0] + 8'h30; // soma 0x30 para virar ASCII
		end
	endfunction
	
	// ============================== montagem da tela ==============================
	integer i;
	always @(*) begin
		// zera a tela inteira (transforma em espaços em branco)
		for (i = 0; i < MSG_LEN; i = i + 1) begin
			message[i] = {1'b1, 8'h20}; 
		end
		
		// cursor vai para o início da linha 1 (0x00)
		message[0] = {1'b0, 8'h80};
		
		// printa o nome da operacao
		message[1] = {1'b1, op_str[55:48]}; // letra 1
		message[2] = {1'b1, op_str[47:40]}; // letra 2
		message[3] = {1'b1, op_str[39:32]}; // letra 3
		message[4] = {1'b1, op_str[31:24]}; // letra 4
		message[5] = {1'b1, op_str[23:16]}; // letra 5
		message[6] = {1'b1, op_str[15:8]};  // letra 6
		message[7] = {1'b1, op_str[7:0]};   // letra 7
		
		if(latched_opcode != 4'd6)begin // caso nao seja CLEAR
			message[11] = {1'b1, 8'h5B}; // '['
			if (latched_opcode == 4'd8) begin // printa a tela padrao
				message[12] = {1'b1, 8'h2D}; // '-'
				message[13] = {1'b1, 8'h2D}; // '-'
				message[14] = {1'b1, 8'h2D}; // '-'
				message[15] = {1'b1, 8'h2D}; // '-'
			end else begin // printa a tela normal
				message[12] = {1'b1, latched_addr[3] ? 8'h31 : 8'h30};
				message[13] = {1'b1, latched_addr[2] ? 8'h31 : 8'h30};
				message[14] = {1'b1, latched_addr[1] ? 8'h31 : 8'h30};
				message[15] = {1'b1, latched_addr[0] ? 8'h31 : 8'h30};
			end
			message[16] = {1'b1, 8'h5D}; // ']'
			
			// quebra de linha
			message[17] = {1'b0, 8'hC0}; 
			
			// resultado da operacao
			message[28] = {1'b1, char_sign};
			message[29] = {1'b1, get_digit(abs_val, 4)};
			message[30] = {1'b1, get_digit(abs_val, 3)};
			message[31] = {1'b1, get_digit(abs_val, 2)};
			message[32] = {1'b1, get_digit(abs_val, 1)};
			message[33] = {1'b1, get_digit(abs_val, 0)};
		end else begin // CLEAR (preenche o resto da tela com vazio)
			message[11] = {1'b1, 8'h20};
			message[12] = {1'b1, 8'h20};
			message[13] = {1'b1, 8'h20};
			message[14] = {1'b1, 8'h20};
			message[15] = {1'b1, 8'h20};
			message[12] = {1'b1, 8'h20};
			message[13] = {1'b1, 8'h20};
			message[14] = {1'b1, 8'h20};
			message[15] = {1'b1, 8'h20};
			message[16] = {1'b1, 8'h20};
			message[17] = {1'b0, 8'hC0}; // quebra de linha
			message[28] = {1'b1, 8'h20};
			message[29] = {1'b1, 8'h20};
			message[30] = {1'b1, 8'h20};
			message[31] = {1'b1, 8'h20};
			message[32] = {1'b1, 8'h20};
			message[33] = {1'b1, 8'h20};
		end
	end
	
	// ============================== maquina de estados finitos ==============================
	localparam [31:0] DELAY_WRITE = 32'd2000;  // ~40 us
	localparam [31:0] DELAY_PULSE = 32'd50;    // ~1 us
	
	localparam [2:0] S_WAIT_INIT = 3'd0, S_IDLE = 3'd1, S_PREPARE = 3'd2, S_PULSE_E = 3'd3, S_WAIT = 3'd4, S_DONE = 3'd5;
	
	reg [2:0]  state, next_state;
	reg primeira_execucao;
	reg [31:0] delay_cnt, next_delay_cnt;
	reg [5:0]  msg_index, next_msg_index; 
	
	// faz a CPU esperar
	assign ocupado = (start || state == S_WAIT_INIT || state == S_PREPARE || state == S_PULSE_E || state == S_WAIT);
	
	
	always @(posedge clk or posedge rst) begin
		if (rst) begin // zera tudo
			state <= S_WAIT_INIT;
			delay_cnt <= 32'd0;
			msg_index <= 6'd0;
			latched_dado <= 16'd0;
			latched_opcode <= 4'd8; // força a tela padrao
			latched_addr <= 4'd0;
			primeira_execucao <= 1'b1;
		end else begin
			state <= next_state;
			delay_cnt <= next_delay_cnt;
			msg_index <= next_msg_index;
			
			if (state == S_IDLE && start) begin
				if (primeira_execucao) begin // ignora as entradas para printar a tela padrao
					primeira_execucao <= 1'b0;
				end else begin
					latched_dado <= data_in;
					latched_opcode <= {1'b0, opcode};
					latched_addr <= addr_wr;
				end
			end
		end
	end
	
	always @(*) begin
		next_state = state;
		next_delay_cnt = delay_cnt;
		next_msg_index = msg_index;
		
		case (state)
			S_WAIT_INIT: begin
				if (init_done) begin
					next_state = S_IDLE;
					next_msg_index = 6'd0;
				end
			end
			S_IDLE: begin
				if (start) begin
					next_state = S_PREPARE;
					next_msg_index = 6'd0;
				end
			end
			S_PREPARE: begin
				next_state = S_PULSE_E;
				next_delay_cnt = DELAY_PULSE; 
			end
			S_PULSE_E: begin
				if (delay_cnt > 0) begin
					next_delay_cnt = delay_cnt - 1;
				end else begin
					next_state = S_WAIT;
					next_delay_cnt = DELAY_WRITE;
				end
			end
			S_WAIT: begin
				if (delay_cnt > 0) begin 
					next_delay_cnt = delay_cnt - 1;
				end else if (msg_index == (MSG_LEN-1)) begin
					next_state = S_DONE; // terminou de escrever
				end else begin
					next_msg_index = msg_index + 1; // printa o proximo caractere
					next_state = S_PREPARE;
				end
			end
			S_DONE: begin
				next_state = S_IDLE;
			end
			default: begin
				next_state = S_WAIT_INIT;
				next_delay_cnt = 32'd0;
				next_msg_index = 6'd0;
			end
		endcase
	end
	
	// sinais fisicos
	reg [7:0] wr_data; reg wr_rs; reg wr_rw; reg wr_e;
	
	always @(*) begin
		start_init = (state == S_WAIT_INIT) ? 1'b1 : 1'b0;
		wr_data = 8'h00;
		wr_rs = 1'b0;
		wr_rw = 1'b0;
		wr_e  = 1'b0;
		
		case (state)
			S_PREPARE: begin // copia os dados
				wr_data = message[msg_index][7:0];
				wr_rs = message[msg_index][8];
				wr_rw = 1'b0;
				wr_e = 1'b0;
			end
			S_PULSE_E: begin
				wr_data = message[msg_index][7:0];
				wr_rs = message[msg_index][8];
				wr_rw = 1'b0;
				wr_e = 1'b1; // enable do lcd
			end
			S_WAIT: begin
				wr_data = message[msg_index][7:0];
				wr_rs = message[msg_index][8];
				wr_rw = 1'b0;
				wr_e = 1'b0; // volta o enable para 0
			end
			default: begin
				wr_rs = 1'b0;
				wr_rw = 1'b0;
				wr_e = 1'b0;
				wr_data = 8'h00;
			end
		endcase
	end
endmodule