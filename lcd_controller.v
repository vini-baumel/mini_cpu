module lcd_controller (
    input  wire       clk,
    input  wire       rst,
	
	 // CPU
	 input  wire       start, // começar a escrever
	 input  wire       show_default, // mostra a tela padrao
    input  wire [2:0] opcode,
    input  wire [3:0] reg_dest, // registrador destino
    input  wire signed [15:0] resultado,
    output wire       lcd_busy, // flag para saber se o lcd esta ocupado
	 
    // Saídas para o LCD
    output wire  [7:0] lcd_data,
    output wire        lcd_rs,
    output wire        lcd_rw,
    output wire        lcd_e
);

    // -----------------------------------------------------------------------
    // Instância do módulo de inicialização
    // -----------------------------------------------------------------------
    wire [7:0] init_data;
    wire       init_rs;
    wire       init_rw;
    wire       init_e;
    wire       init_done;

    reg        start_init;  // gerado pelo controlador

    lcd_init_hd44780 lcd_init (
        .clk      (clk),
        .rst      (rst),
        .start    (start_init),
        .done     (init_done),
        .lcd_data (init_data),
        .lcd_rs   (init_rs),
        .lcd_rw   (init_rw),
        .lcd_e    (init_e)
    );

    // -----------------------------------------------------------------------
    // MUX: decide quem controla o LCD (init ou controlador principal)
    // -----------------------------------------------------------------------
    wire controller_mode = init_done;
    assign lcd_data = (controller_mode == 0) ? init_data : wr_data;
    assign lcd_rs   = (controller_mode == 0) ? init_rs   : wr_rs;
    assign lcd_rw   = (controller_mode == 0) ? init_rw   : wr_rw;
    assign lcd_e    = (controller_mode == 0) ? init_e    : wr_e;

    // -----------------------------------------------------------------------
    // Mensagem a ser exibida
    // -----------------------------------------------------------------------
    localparam integer MSG_LEN = 33; // 16(linha 1) + 1(pula linha) + 16(linha 2)
    reg [8:0] message [0:MSG_LEN-1];
	 
	 wire bit_sinal = resultado[15];
	 wire [15:0] abs_res = bit_sinal ? -resultado : resultado; // caso seja negativo, recebe -resultado
	 
	 
    integer i;
	 always @(*) begin
		// limpa a tela
		for (i = 0; i < MSG_LEN; i = i + 1) message[i] = {1'b1, 8'h20};
		
		// quebra de linha
		message[16] = {1'b0, 8'hC0};
		
		if (show_default) begin
            // Linha 1: "----            [----]"
            message[0]={1'b1, 8'h2D}; message[1]={1'b1, 8'h2D}; message[2]={1'b1, 8'h2D}; message[3]={1'b1, 8'h2D};
            message[10]={1'b1, 8'h5B}; message[11]={1'b1, 8'h2D}; message[12]={1'b1, 8'h2D}; message[13]={1'b1, 8'h2D}; message[14]={1'b1, 8'h2D}; message[15]={1'b1, 8'h5D};
            
            // Linha 2: "              +00000"
            message[27]={1'b1, 8'h2B}; message[28]={1'b1, 8'h30}; message[29]={1'b1, 8'h30}; message[30]={1'b1, 8'h30}; message[31]={1'b1, 8'h30}; message[32]={1'b1, 8'h30};
            
      end else begin
			// printa o nome da operacao atual
			case (opcode)
				3'b000: begin message[0]={1'b1, 8'h4C}; message[1]={1'b1, 8'h4F}; message[2]={1'b1, 8'h41}; message[3]={1'b1, 8'h44}; end // LOAD
				3'b001: begin message[0]={1'b1, 8'h41}; message[1]={1'b1, 8'h44}; message[2]={1'b1, 8'h44}; end // ADD
				3'b010: begin message[0]={1'b1, 8'h41}; message[1]={1'b1, 8'h44}; message[2]={1'b1, 8'h44}; message[3]={1'b1, 8'h49}; end // ADDI
				3'b011: begin message[0]={1'b1, 8'h53}; message[1]={1'b1, 8'h55}; message[2]={1'b1, 8'h42}; end // SUB
				3'b100: begin message[0]={1'b1, 8'h53}; message[1]={1'b1, 8'h55}; message[2]={1'b1, 8'h42}; message[3]={1'b1, 8'h49}; end // SUBI
				3'b101: begin message[0]={1'b1, 8'h4D}; message[1]={1'b1, 8'h55}; message[2]={1'b1, 8'h4C}; end // MUL
				3'b110: begin message[0]={1'b1, 8'h43}; message[1]={1'b1, 8'h4C}; message[2]={1'b1, 8'h45}; message[3]={1'b1, 8'h41}; message[4]={1'b1, 8'h52}; end // CLEAR
				3'b111: begin message[0]={1'b1, 8'h44}; message[1]={1'b1, 8'h50}; message[2]={1'b1, 8'h4C}; end // DPL
			 endcase
			
			// se a operacao nao for CLEAR, printa o registrador e o resultado
			if (opcode != 3'b110) begin
				// Linha 1: Registrador (ex: [0001])
				message[10] = {1'b1, 8'h5B}; // "["
				message[11] = {1'b1, 8'h30 + reg_dest[3]}; // Extrai o bit e converte em '0' ou '1'
				message[12] = {1'b1, 8'h30 + reg_dest[2]};
				message[13] = {1'b1, 8'h30 + reg_dest[1]};
				message[14] = {1'b1, 8'h30 + reg_dest[0]};
				message[15] = {1'b1, 8'h5D}; // "]"

				// Linha 2: Sinal e Resultado (ex: +00012)
				message[25] = {1'b1, bit_sinal ? 8'h2D : 8'h2B}; // "-" ou "+"
				message[26] = {1'b1, 8'h30 + (abs_res / 10000)};
				message[27] = {1'b1, 8'h30 + ((abs_res / 1000) % 10)};
				message[28] = {1'b1, 8'h30 + ((abs_res / 100) % 10)};
				message[29] = {1'b1, 8'h30 + ((abs_res / 10) % 10)};
				message[30] = {1'b1, 8'h30 + (abs_res % 10)};
		  end
		end
		  
	 end
    

    // -----------------------------------------------------------------------
    // Temporizações para escrita de caracteres (ajustar ao clock real)
    // -----------------------------------------------------------------------
    // Exemplo para 50 MHz:
    localparam [31:0] DELAY_WRITE = 32'd2000; // ~40 us
    localparam [31:0] DELAY_PULSE = 32'd50;   // ~1 us

    // -----------------------------------------------------------------------
    // Estados da FSM principal
    // -----------------------------------------------------------------------
    localparam [2:0]
        S_WAIT_INIT  = 3'd0,
		  S_IDLE       = 3'd1,
        S_PREPARE    = 3'd2,
        S_PULSE_E    = 3'd3,
        S_WAIT       = 3'd4,
        S_DONE       = 3'd5;

    reg [2:0]  state, next_state;
    reg [31:0] delay_cnt, next_delay_cnt;
    reg [5:0]  msg_index, next_msg_index; // até 33 caracteres
	
	 assign lcd_busy = (state != S_WAIT_INIT && state != S_IDLE); // se o lcd nao estiver em IDLE, esta ocupado
	 
    // =======================================================================
    // 1) BLOCO SEQUENCIAL: registra estado, contador e índice da mensagem
    // =======================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= S_WAIT_INIT;
            delay_cnt  <= 32'd0;
            msg_index  <= 6'd0;
        end else begin
            state      <= next_state;
            delay_cnt  <= next_delay_cnt;
            msg_index  <= next_msg_index;
        end
    end

    // =======================================================================
    // 2) BLOCO COMBINACIONAL: cálculo do próximo estado/contador/índice
    // =======================================================================
    always @(*) begin
        // valores padrão
        next_state     = state;
        next_delay_cnt = delay_cnt;
        next_msg_index = msg_index;

        case (state)
            // ---------------------------------------------------------------
            // Espera a inicialização do LCD ser concluída
            // ---------------------------------------------------------------
            S_WAIT_INIT: begin
                if (init_done) begin
                    next_state     = S_IDLE;
                end
            end
				
				S_IDLE: begin
					if(start) begin
						next_state = S_PREPARE;
						next_msg_index = 0;
					end
				end
				
            // ---------------------------------------------------------------
            // Prepara para escrever o caractere atual
            // ---------------------------------------------------------------
            S_PREPARE: begin
                // apenas configura o próximo estado e o delay para o pulso
                next_state     = S_PULSE_E;
                next_delay_cnt = DELAY_PULSE;
            end

            // ---------------------------------------------------------------
            // Gera pulso de Enable
            // ---------------------------------------------------------------
            S_PULSE_E: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    next_state     = S_WAIT;
                    next_delay_cnt = DELAY_WRITE;
                end
            end

            // ---------------------------------------------------------------
            // Espera o tempo de escrita do caractere
            // ---------------------------------------------------------------
            S_WAIT: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    if (msg_index == (MSG_LEN-1)) begin
                        next_state = S_DONE;
                    end else begin
                        next_msg_index = msg_index + 1;
                        next_state     = S_PREPARE;
                    end
                end
            end

            // ---------------------------------------------------------------
            // Mensagem completa
            // ---------------------------------------------------------------
            S_DONE: begin
                // Permanece nesse estado até reset
                next_state = S_IDLE;
            end

            default: begin
                next_state     = S_WAIT_INIT;
                //next_delay_cnt = 32'd0;
                //next_msg_index = 5'd0;
            end
        endcase
    end

    // =======================================================================
    // 3) BLOCO COMBINACIONAL: geração das saídas
    //     - start_init
    //     - sinais de escrita (wr_rs, wr_rw, wr_e, wr_data)
// =======================================================================
    reg [7:0] wr_data;
    reg       wr_rs;
    reg       wr_rw;
    reg       wr_e;

    always @(*) begin
        // -------------------------------------------------------------------
        // 3.1) Controle de quem controla os sinais do LCD
        // -------------------------------------------------------------------

        // start_init: fica em '1' enquanto estamos esperando a inicialização.
        // O módulo lcd_init só usa o nível de start para sair do IDLE.
        start_init = (state == S_WAIT_INIT) ? 1'b1 : 1'b0;

        // -------------------------------------------------------------------
        // 3.2) Sinais de escrita do controlador principal
        // -------------------------------------------------------------------
        // Default
        wr_data = 8'h00;
        wr_rs   = 1'b0;
        wr_rw   = 1'b0;
        wr_e    = 1'b0;

        case (state)
            // Durante a escrita da mensagem, usamos os caracteres da array
            S_PREPARE: begin
                wr_data = message[msg_index][7:0];
                wr_rs   = message[msg_index][8]; // se a mensagem passar de 1 linha
            end

            S_PULSE_E: begin
                wr_data = message[msg_index][7:0];
                wr_rs   = message[msg_index][8];
                wr_e    = 1'b1; // pulso de enable
            end

            S_WAIT: begin
                wr_data = message[msg_index][7:0];
                wr_rs   = message[msg_index][8];
            end
				
            default: begin
                // outros estados: controlador principal não mexe no LCD
                wr_rs = 1'b0;
                wr_rw = 1'b0;
                wr_e  = 1'b0;
                wr_data = 8'h00;
            end
        endcase
    end
endmodule
