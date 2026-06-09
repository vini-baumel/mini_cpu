module module_lcd_controller (
    input wire clk,
    input wire rst,               // Ativo em 1 (Quando a CPU está em DESLIGADO)
    input wire start_init,        // Pulso disparado pela CPU para inicializar a tela
    input wire start_print,       // Pulso disparado pela CPU para escrever a instrução
    input wire [2:0] opcode,      // Opcode da instrução atual
    input wire [3:0] addr_w,      // Registrador de destino (4 bits)
    input wire [15:0] data_val,   // Valor de 16 bits assinalado do registrador

    output reg init_done,         // Sinaliza à CPU que a tela foi inicializada
    output reg print_done,        // Sinaliza à CPU que a escrita terminou

    // Pinos físicos externos conectados ao LCD da placa DE2-115
    output reg [7:0] lcd_data,
    output reg lcd_rs,
    output reg lcd_rw,
    output reg lcd_en
);

    // =========================================================================
    // CONVERSÕES FORMATADAS: BINÁRIO -> ASCII & VALOR SINALIZADO -> DECIMAL
    // =========================================================================
    
    // Converte o registrador de destino de 4 bits para caracteres binários na tela
    wire [7:0] b3 = addr_w[3] ? 8'h31 : 8'h30;
    wire [7:0] b2 = addr_w[2] ? 8'h31 : 8'h30;
    wire [7:0] b1 = addr_w[1] ? 8'h31 : 8'h30;
    wire [7:0] b0 = addr_w[0] ? 8'h31 : 8'h30;

    // Isola o valor absoluto e define o caractere do sinal ('+' ou '-')
    wire [15:0] abs_val   = data_val[15] ? (~data_val + 1'b1) : data_val;
    wire [7:0]  sign_char = data_val[15] ? 8'h2D : 8'h2B; 

    // Extração matemática de 5 dígitos decimais
    wire [3:0] d5 = (abs_val / 14'd10000) % 4'd10;
    wire [3:0] d4 = (abs_val / 11'd1000) % 4'd10;
    wire [3:0] d3 = (abs_val / 7'd100) % 4'd10;
    wire [3:0] d2 = (abs_val / 4'd10) % 4'd10;
    wire [3:0] d1 = abs_val % 4'd10;

    // Conversão direta dos dígitos isolados para a tabela ASCII
    wire [7:0] c5 = 8'h30 + d5;
    wire [7:0] c4 = 8'h30 + d4;
    wire [7:0] c3 = 8'h30 + d3;
    wire [7:0] c2 = 8'h30 + d2;
    wire [7:0] c1 = 8'h30 + d1;

    // Matrizes de buffers para as duas linhas (16 colunas cada)
    reg [7:0] row1 [0:15];
    reg [7:0] row2 [0:15];
    integer k;

    always @(*) begin
        // Inicializa as duas linhas com caracteres de espaço em branco (ASCII 0x20)
        for (k = 0; k < 16; k = k + 1) begin
            row1[k] = 8'h20;
            row2[k] = 8'h20;
        end

        case (opcode)
            3'b000: begin // LOAD
                row1[0]="L"; row1[1]="O"; row1[2]="A"; row1[3]="D";
                row1[10]="["; row1[11]=b3; row1[12]=b2; row1[13]=b1; row1[14]=b0; row1[15]="]";
                row2[10]=sign_char; row2[11]=c5; row2[12]=c4; row2[13]=c3; row2[14]=c2; row2[15]=c1;
            end
            3'b001: begin // ADD
                row1[0]="A"; row1[1]="D"; row1[2]="D";
                row1[10]="["; row1[11]=b3; row1[12]=b2; row1[13]=b1; row1[14]=b0; row1[15]="]";
                row2[10]=sign_char; row2[11]=c5; row2[12]=c4; row2[13]=c3; row2[14]=c2; row2[15]=c1;
            end
            3'b010: begin // ADDI
                row1[0]="A"; row1[1]="D"; row1[2]="D"; row1[3]="I";
                row1[10]="["; row1[11]=b3; row1[12]=b2; row1[13]=b1; row1[14]=b0; row1[15]="]";
                row2[10]=sign_char; row2[11]=c5; row2[12]=c4; row2[13]=c3; row2[14]=c2; row2[15]=c1;
            end
            3'b011: begin // SUB
                row1[0]="S"; row1[1]="U"; row1[2]="B";
                row1[10]="["; row1[11]=b3; row1[12]=b2; row1[13]=b1; row1[14]=b0; row1[15]="]";
                row2[10]=sign_char; row2[11]=c5; row2[12]=c4; row2[13]=c3; row2[14]=c2; row2[15]=c1;
            end
            3'b100: begin // SUBI
                row1[0]="S"; row1[1]="U"; row1[2]="B"; row1[3]="I";
                row1[10]="["; row1[11]=b3; row1[12]=b2; row1[13]=b1; row1[14]=b0; row1[15]="]";
                row2[10]=sign_char; row2[11]=c5; row2[12]=c4; row2[13]=c3; row2[14]=c2; row2[15]=c1;
            end
            3'b101: begin // MUL
                row1[0]="M"; row1[1]="U"; row1[2]="L";
                row1[10]="["; row1[11]=b3; row1[12]=b2; row1[13]=b1; row1[14]=b0; row1[15]="]";
                row2[10]=sign_char; row2[11]=c5; row2[12]=c4; row2[13]=c3; row2[14]=c2; row2[15]=c1;
            end
            3'b110: begin // CLEAR
                row1[0]="C"; row1[1]="L"; row1[2]="E"; row1[3]="A"; row1[4]="R";
            end
            3'b111: begin // DISPLAY (Exibe a mnemônica DPL de acordo com o PDF)
                row1[0]="D"; row1[1]="P"; row1[2]="L";
                row1[10]="["; row1[11]=b3; row1[12]=b2; row1[13]=b1; row1[14]=b0; row1[15]="]";
                row2[10]=sign_char; row2[11]=c5; row2[12]=c4; row2[13]=c3; row2[14]=c2; row2[15]=c1;
            end
        endcase
    end

    // =========================================================================
    // INSTANCIAÇÃO DO BLOCO DE INICIALIZAÇÃO TÉCNICA FORNECIDO
    // =========================================================================
    wire       init_block_done;
    wire [7:0] init_lcd_data;
    wire       init_lcd_rs;
    wire       init_lcd_rw;
    wire       init_lcd_e;

    lcd_init_hd44780 technical_init (
        .clk(clk),
        .rst(rst),
        .start(start_init),
        .done(init_block_done),
        .lcd_data(init_lcd_data),
        .lcd_rs(init_lcd_rs),
        .lcd_rw(init_lcd_rw),
        .lcd_e(init_lcd_e)
    );

    always @(*) begin
        init_done = init_block_done;
    end

    // =========================================================================
    // MÁQUINA DE ESTADOS (FSM) DE ESCRITA DE STRING DO CONTRALADOR
    // =========================================================================
    reg [2:0] print_state;
    parameter P_IDLE     = 3'd0;
    parameter P_SET_L1   = 3'd1;
    parameter P_WRITE_L1 = 3'd2;
    parameter P_SET_L2   = 3'd3;
    parameter P_WRITE_L2 = 3'd4;
    parameter P_DONE     = 3'd5;

    reg [3:0] char_count;
    reg [1:0] step;
    reg       delay_start;
    
    // Temporizador rigoroso de 1 ms (50.000 ciclos a 50 MHz)
    reg [16:0] delay_counter;
    wire       delay_done = (delay_counter >= 17'd50000);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            delay_counter <= 17'd0;
        end else if (delay_start) begin
            if (delay_done)
                delay_counter <= delay_counter;
            else
                delay_counter <= delay_counter + 1'b1;
        end else begin
            delay_counter <= 17'd0;
        end
    end

    reg [7:0] print_lcd_data;
    reg       print_lcd_rs;
    reg       print_lcd_en;
    reg       is_printing;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            print_state    <= P_IDLE;
            char_count     <= 4'd0;
            step           <= 2'd0;
            delay_start    <= 1'b0;
            print_lcd_en   <= 1'b0;
            print_lcd_data <= 8'h00;
            print_lcd_rs   <= 1'b0;
            print_done     <= 1'b0;
            is_printing    <= 1'b0;
        end else begin
            case (print_state)
                P_IDLE: begin
                    print_done   <= 1'b0;
                    print_lcd_en <= 1'b0;
                    step         <= 2'd0;
                    delay_start  <= 1'b0;
                    if (start_print) begin
                        is_printing <= 1'b1;
                        print_state <= P_SET_L1;
                    end else begin
                        is_printing <= 1'b0;
                    end
                end

                P_SET_L1: begin // Força posicionamento no endereço inicial da Linha 1 (0x80)
                    case (step)
                        2'd0: begin print_lcd_rs <= 1'b0; print_lcd_data <= 8'h80; print_lcd_en <= 1'b0; step <= 2'd1; end
                        2'd1: begin print_lcd_en <= 1'b1; step <= 2'd2; end
                        2'd2: begin
                            print_lcd_en <= 1'b0; // Borda de descida ativa captura
                            delay_start  <= 1'b1;
                            if (delay_done) begin
                                delay_start <= 1'b0; step <= 2'd0; char_count <= 4'd0; print_state <= P_WRITE_L1;
                            end
                        end
                    endcase
                end

                P_WRITE_L1: begin // Descarrega caractere por caractere da Linha 1
                    case (step)
                        2'd0: begin print_lcd_rs <= 1'b1; print_lcd_data <= row1[char_count]; print_lcd_en <= 1'b0; step <= 2'd1; end
                        2'd1: begin print_lcd_en <= 1'b1; step <= 2'd2; end
                        2'd2: begin
                            print_lcd_en <= 1'b0;
                            delay_start  <= 1'b1;
                            if (delay_done) begin
                                delay_start <= 1'b0; step <= 2'd0;
                                if (char_count == 4'd15) print_state <= P_SET_L2;
                                else char_count <= char_count + 1'b1;
                            end
                        end
                    endcase
                end

                P_SET_L2: begin // Força posicionamento no endereço inicial da Linha 2 (0xC0)
                    case (step)
                        2'd0: begin print_lcd_rs <= 1'b0; print_lcd_data <= 8'hC0; print_lcd_en <= 1'b0; step <= 2'd1; end
                        2'd1: begin print_lcd_en <= 1'b1; step <= 2'd2; end
                        2'd2: begin
                            print_lcd_en <= 1'b0;
                            delay_start  <= 1'b1;
                            if (delay_done) begin
                                delay_start <= 1'b0; step <= 2'd0; char_count <= 4'd0; print_state <= P_WRITE_L2;
                            end
                        end
                    endcase
                end

                P_WRITE_L2: begin // Descarrega caractere por caractere da Linha 2
                    case (step)
                        2'd0: begin print_lcd_rs <= 1'b1; print_lcd_data <= row2[char_count]; print_lcd_en <= 1'b0; step <= 2'd1; end
                        2'd1: begin print_lcd_en <= 1'b1; step <= 2'd2; end
                        2'd2: begin
                            print_lcd_en <= 1'b0;
                            delay_start  <= 1'b1;
                            if (delay_done) begin
                                delay_start <= 1'b0; step <= 2'd0;
                                if (char_count == 4'd15) print_state <= P_DONE;
                                else char_count <= char_count + 1'b1;
                            end
                        end
                    endcase
                end

                P_DONE: begin
                    print_done <= 1'b1;
                    if (!start_print) begin
                        print_state <= P_IDLE;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // MULTIPLEXADOR DE CONTROLE DO BARRAMENTO FÍSICO DO LCD
    // =========================================================================
    always @(*) begin
        if (rst) begin
            lcd_data = 8'h00;
            lcd_rs   = 1'b0;
            lcd_rw   = 1'b0;
            lcd_en   = 1'b0;
        end else if (is_printing) begin
            // Barramento controlado pela FSM de strings do controlador
            lcd_data = print_lcd_data;
            lcd_rs   = print_lcd_rs;
            lcd_rw   = 1'b0;
            lcd_en   = print_lcd_en;
        end else begin
            // Barramento passa para o bloco de inicialização técnica hd44780
            lcd_data = init_lcd_data;
            lcd_rs   = init_lcd_rs;
            lcd_rw   = init_lcd_rw;
            lcd_en   = init_lcd_e;
        end
    end

endmodule