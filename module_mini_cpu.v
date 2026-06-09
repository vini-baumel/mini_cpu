module module_mini_cpu(
    input wire clk,
    input wire btn_ligar,
    input wire btn_enviar,
    input wire [17:0] switches,

    output reg [7:0] lcd_data,
    output reg lcd_rs,
    output reg lcd_rw,
    output reg lcd_en
);
    // Estados
    parameter DESLIGADO = 3'd0;
    parameter INICIALIZANDO = 3'd1;
    parameter ESPERANDO = 3'd2;
    parameter PROCESSANDO = 3'd3;
    parameter DESCARREGANDO = 3'd4;

    reg[2:0] state = DESLIGADO;

    // Detectores de negedge 
    reg btn_ligar_reg, btn_enviar_reg; // guarda o estado anterior

    // detectam quando o botao estava apertado e foi solto
    wire ligar_solto = (~btn_ligar & btn_ligar_reg); // 
    wire enviar_solto = (~btn_enviar & btn_enviar_reg);

    always @(posedge clk) begin
        btn_ligar_reg <= btn_ligar;
        btn_enviar_reg <= btn_enviar;
    end

    // CPU -> Memoria
    reg rst_mem, we_mem;
    reg[3:0] addr_r1, addr_r2, addr_w;
    reg [15:0] data_in;
    wire [15:0] data_out1, data_out2;

    memory memoria (
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

    // CPU -> ULA
    reg [2:0] alu_opcode;
    reg [15:0] alu_num1;
    reg [15:0] alu_num2;
    wire [15:0] alu_result;

    module_alu ula(
        .opcode(alu_opcode),
        .num1(alu_num1),
        .num2(alu_num2),
        .resultado(alu_result)
    );

    // mapeamento de switches

    wire [2:0] opcode     = switches[17:15];
    wire [3:0] addr1      = switches[14:11];
    wire [3:0] addr2      = switches[10:7];
    wire [3:0] addr3      = switches[6:3];

    wire sinal1           = switches[6];
    wire [5:0] immediato1 = switches[5:0];
    // wire sinal2           = switches[14];
    // wire [5:0] immediato2 = switches[13:8];

    always @(posedge clk) begin

        // valores padrãO
        rst_mem <= 0;
        we_mem  <= 0;
        lcd_en  <= 0;

        case(state)
            DESLIGADO:begin
                if (ligar_solto) begin  
                    state <= INICIALIZANDO;
                    rst_mem <= 1; // zerar a memoria antes da inicialização
                end
            end

            INICIALIZANDO: begin
                //LCD: INICAR 
                state <= ESPERANDO;
            end

            ESPERANDO: begin
                if (ligar_solto) begin
                    state <= DESLIGADO;
                    
                end else if (enviar_solto) begin
                    state <= PROCESSANDO;
                end
            end

            PROCESSANDO: begin
                case(opcode)
                    3'b001, 3'b011: begin//ADD SUB
                        alu_opcode <= opcode;
                        addr_w  <= addr1;

                        addr_r1 <= addr2;
                        alu_num1 <= data_out1;

                        addr_r2 <= addr3;
                        alu_num2 <= data_out2;

                        we_mem <= 1;
                        data_in <= alu_result;
                    end

                    3'b010, 3'b100, 3'b101: begin// ADDI SUBI MUL
                         alu_opcode <= opcode;
                         addr_w <= addr1;

                         addr_r1 <= addr2;
                         alu_num1 <= data_out1;

                         alu_num2 <= {{10{sinal1}}, immediato1}; // cria um numero de 16 bits 

                         we_mem <= 1;
                         data_in <= alu_result;
                    end

                    3'b000: begin//LOAD
                        alu_opcode <= opcode;
                        addr_w <= addr1;

                        alu_num1 <= {{10{sinal1}}, immediato1}; // cria um numero de 16 bits 

                        we_mem <= 1;
                        data_in <= alu_result;
                    end

                    3'b110: begin//CLEAR
                        rst_mem <= 1; // LCD só vai mostrar a operação
                    end

                    3'b111: begin//DISPLAY
                        // o lcd vai ler addr_w e data_in. deixamos we_memm = 0 para atualiza-los sem mexer na memoria 
                        addr_w <= addr1;
                        addr_r1 <= addr1;
                        data_in <= data_out1;
                    end

                endcase

                state <= DESCARREGANDO;
            end

            DESCARREGANDO: begin
                //ligar o led aqui, garantir pelo menos 1ms para o LCD pegar 
                lcd_en <= 1;
                state <= ESPERANDO;
            end

        endcase

    end

endmodule
