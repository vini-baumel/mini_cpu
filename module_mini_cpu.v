module module_mini_cpu(
    input wire clk_50mhz,
    input wire btn_ligar,
    input wire btn_enviar,
    input wire [17:0] switches,

    output reg [7:0] lcd_data,
    output reg lcd_rs,
    output reg lcd_en
);
    // ESTADOS
    parameter OFF      = 3'd0;
    parameter INIT     = 3'd1;
    parameter WAIT_CMD = 3'd2;
    parameter FETCH    = 3'd3;
    parameter DECODE   = 3'd4;
    parameter EXECUTE  = 3'd5;
    parameter STORE    = 3'd6;
endmodule