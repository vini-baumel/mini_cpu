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
    parameter PROCESSANOD = 3'd3;
    parameter DESCARREGANDO = 3'd4;

    reg[2:0] state = DESLIGADO;

    // Detectores de negedge 
    reg btn_ligar_reg, btn_enviar_reg;

    wire ligar_solto = (~btn_ligar & btn_ligar_reg);
    wire enviar_solto = (~btn_ligar & btn_enviar_reg);




endmodule