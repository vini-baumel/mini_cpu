module module_mini_cpu(
    input wire clk,
    input wire btn_ligar,
    input wire btn_enviar,
    input wire [17:0] switches,

    output wire [7:0] lcd_data,
    output wire lcd_rs,
    output wire lcd_rw,
    output wire lcd_en
);
    // Estados
    parameter DESLIGADO     = 3'd0;
    parameter INICIALIZANDO = 3'd1;
    parameter ESPERANDO     = 3'd2;
    parameter PROCESSANDO   = 3'd3;
    parameter DESCARREGANDO = 3'd4;

    reg [2:0] state = DESLIGADO;

    // Detectores de negedge 
    reg btn_ligar_reg, btn_enviar_reg; // guarda o estado anterior

    // detectam quando o botao estava apertado e foi solto
    wire ligar_solto  = (~btn_ligar & btn_ligar_reg); // 
    wire enviar_solto = (~btn_enviar & btn_enviar_reg);

    always @(posedge clk) begin
        btn_ligar_reg  <= btn_ligar;
        btn_enviar_reg <= btn_enviar;
    end

    // CPU -> Memoria
    reg rst_mem, we_mem;
    reg [3:0] addr_r1, addr_r2, addr_w;
    reg [15:0] data_in;
    wire [15:0] data_out1, data_out2;
    reg [2:0] alu_opcode;
    reg [15:0] alu_num1, alu_num2;
    wire [15:0] alu_result;

    // Mapeamento dos switches
    wire [2:0] opcode      = switches[17:15];
    wire [3:0] addr1       = switches[14:11];
    wire [3:0] addr2       = switches[10:7];
    wire       sinal1      = switches[6];
    wire [5:0] immediato1  = switches[5:0];

    // Instanciação da Memória
    memory data_memory (
        .clk(clk),
        .rst(rst_mem),
        .we(we_mem),
        .addr_r1(addr_r1),
        .addr_r2(addr_r2),
        .addr_w(addr_w),
        .data_in(data_in),
        .data_out1(data_out1),
        .data_out2(data_out2)
    );

    // Instanciação da ULA
    module_alu alu_unit (
        .opcode(alu_opcode),
        .num1(alu_num1),
        .num2(alu_num2),
        .resultado(alu_result)
    );

    // Sinais de controle do LCD
    reg lcd_start_init;
    reg lcd_start_print;
    wire lcd_init_done;
    wire lcd_print_done;

    // módulo dedicado para o LCD
    module_lcd_controller lcd_display_manager (
        .clk(clk),
        .rst(state == DESLIGADO),
        .start_init(lcd_start_init),
        .start_print(lcd_start_print),
        .opcode(opcode),
        .addr_w(addr_w),
        .data_val(data_in),
        .init_done(lcd_init_done),
        .print_done(lcd_print_done),
        .lcd_data(lcd_data),
        .lcd_rs(lcd_rs),
        .lcd_rw(lcd_rw),
        .lcd_en(lcd_en)
    );


	 //maquina de estados
    always @(posedge clk) begin
        case (state)
            DESLIGADO: begin
                rst_mem         <= 1'b1;
                we_mem          <= 1'b0;
                lcd_start_init  <= 1'b0;
                lcd_start_print <= 1'b0;
                if (ligar_solto) begin
                    state          <= INICIALIZANDO;
                    lcd_start_init <= 1'b1; // Envia comando de gatilho para o LCD iniciar
                end
            end

            INICIALIZANDO: begin
                rst_mem        <= 1'b0;
                lcd_start_init <= 1'b0;
                if (lcd_init_done) begin
                    state <= ESPERANDO;
                end
            end

            ESPERANDO: begin
                we_mem          <= 1'b0;
                rst_mem         <= 1'b0;
                lcd_start_print <= 1'b0;
                if (ligar_solto) begin
                    state <= DESLIGADO; // Desliga e limpa registradores caso pressionado de novo
                end else if (enviar_solto) begin
                    state <= PROCESSANDO;
                end
            end

            PROCESSANDO: begin
                case (opcode)
                    3'b001, 3'b011, 3'b101: begin // ADD, SUB, MUL (Reg x Reg)
                        alu_opcode <= opcode;
                        addr_w     <= addr1;
                        addr_r1    <= addr2;
                        addr_r2    <= addr1;
                        alu_num1   <= data_out1;
                        alu_num2   <= data_out2;
                        we_mem     <= 1'b1;
                        data_in    <= alu_result;
                    end

                    3'b010, 3'b100: begin // ADDI, SUBI (Reg x Imediato)
                        alu_opcode <= opcode;
                        addr_w     <= addr1;
                        addr_r1    <= addr2;
                        alu_num1   <= data_out1;
                        alu_num2   <= {{10{sinal1}}, immediato1}; // cria um numero de 16 bits 
                        we_mem     <= 1'b1;
                        data_in    <= alu_result;
                    end

                    3'b000: begin // LOAD
                        alu_opcode <= opcode;
                        addr_w     <= addr1;
                        alu_num1   <= {{10{sinal1}}, immediato1}; // cria um numero de 16 bits 
                        we_mem     <= 1'b1;
                        data_in    <= alu_result;
                    end

                    3'b110: begin // CLEAR
                        rst_mem <= 1'b1; // LCD só vai mostrar a operação
                        data_in <= 16'b0;
                    end

                    3'b111: begin // DISPLAY
                        // o lcd vai ler addr_w e data_in. deixamos we_memm = 0 para atualiza-los sem mexer na memoria 
                        addr_w  <= addr1;
                        addr_r1 <= addr1;
                        data_in <= data_out1;
                    end
                endcase
                state           <= DESCARREGANDO;
                lcd_start_print <= 1'b1; // Dispara o gatilho de impressão da instrução atual
            end

            DESCARREGANDO: begin
                //ligar o led aqui, garantir pelo menos 1ms para o LCD pegar 
                we_mem          <= 1'b0;
                rst_mem         <= 1'b0;
                lcd_start_print <= 1'b0; // Reseta pulso de início
                if (lcd_print_done) begin
                    state <= ESPERANDO; // Libera a CPU para aguardar um novo comando dos switches
                end
            end
            
            default: state <= DESLIGADO;
        endcase
    end

endmodule