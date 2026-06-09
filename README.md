## CPU
```mermaid
stateDiagram-v2
    [*] --> DESLIGADO

    DESLIGADO --> INICIALIZANDO : ligar_solto == 1<br/>(Seta rst_mem = 1)
    
    INICIALIZANDO --> ESPERANDO : Transição incondicional

    ESPERANDO --> DESLIGADO : ligar_solto == 1
    ESPERANDO --> PROCESSANDO : enviar_solto == 1
    
    PROCESSANDO --> DESCARREGANDO : Decodifica opcode<br/>Estende sinal<br/>Seta we_mem<br/>Roteia ULA
    
    DESCARREGANDO --> ESPERANDO : Seta lcd_en = 1
```
## MEMORIA
```mermaid
stateDiagram-v2
    [*] --> ESTADO_ATUAL

    ESTADO_ATUAL --> RESET_SINCRONO : posedge clk<br/>com rst == 1
    RESET_SINCRONO --> ESTADO_ATUAL : Todos regs = 0

    ESTADO_ATUAL --> ESCRITA_SINCRONA : posedge clk<br/>com we == 1 e rst == 0
    ESCRITA_SINCRONA --> ESTADO_ATUAL : ram[addr_w] = data_in

    note right of ESTADO_ATUAL: A leitura das saídas<br/>data_r1 e data_r2<br/>ocorre de forma<br/>combinacional.
```
## ULA

```mermaid
stateDiagram-v2
    [*] --> AGUARDANDO_MUDANCA

    AGUARDANDO_MUDANCA --> AVALIAR_OPCODE : Mudança no Opcode<br/>ou Operandos

    AVALIAR_OPCODE --> ATRIBUICAO_LOAD : 000 (LOAD)
    AVALIAR_OPCODE --> SOMA : 001 (ADD) ou 010 (ADDI)
    AVALIAR_OPCODE --> SUBTRACAO : 011 (SUB) ou 100 (SUBI)
    AVALIAR_OPCODE --> MULTIPLICACAO : 101 (MUL)

    ATRIBUICAO_LOAD --> AGUARDANDO_MUDANCA : resultado = num1
    SOMA --> AGUARDANDO_MUDANCA : resultado = num1 + num2
    SUBTRACAO --> AGUARDANDO_MUDANCA : resultado = num1 - num2
    MULTIPLICACAO --> AGUARDANDO_MUDANCA : resultado = num1 * num2
```

 ## LCD

 ```mermaid
 stateDiagram-v2
    [*] --> P_IDLE : rst = 1
    
    state P_IDLE {
        [*] --> Aguardando
        Aguardando --> Comando_Iniciado : start_print == 1
    }

    P_IDLE --> P_SET_L1 : start_print == 1 \n(is_printing <= 1)
    
    state P_SET_L1 {
        [*] --> Envia_Cmd_0x80
        Envia_Cmd_0x80 --> Espera_1ms_L1 : step == 2
        Espera_1ms_L1 --> Espera_1ms_L1 : delay_done == 0
    }
    P_SET_L1 --> P_WRITE_L1 : delay_done == 1 \n(char_count <= 0)

    state P_WRITE_L1 {
        [*] --> Envia_Char_L1
        Envia_Char_L1 --> Espera_1ms_Char1 : step == 2
        Espera_1ms_Char1 --> Espera_1ms_Char1 : delay_done == 0
    }
    P_WRITE_L1 --> P_WRITE_L1 : delay_done == 1 AND char_count < 15 \n(char_count <= char_count + 1)
    P_WRITE_L1 --> P_SET_L2 : delay_done == 1 AND char_count == 15

    state P_SET_L2 {
        [*] --> Envia_Cmd_0xC0
        Envia_Cmd_0xC0 --> Espera_1ms_L2 : step == 2
        Espera_1ms_L2 --> Espera_1ms_L2 : delay_done == 0
    }
    P_SET_L2 --> P_WRITE_L2 : delay_done == 1 \n(char_count <= 0)

    state P_WRITE_L2 {
        [*] --> Envia_Char_L2
        Envia_Char_L2 --> Espera_1ms_Char2 : step == 2
        Espera_1ms_Char2 --> Espera_1ms_Char2 : delay_done == 0
    }
    P_WRITE_L2 --> P_WRITE_L2 : delay_done == 1 AND char_count < 15 \n(char_count <= char_count + 1)
    P_WRITE_L2 --> P_DONE : delay_done == 1 AND char_count == 15

    state P_DONE {
        [*] --> Sinaliza_Fim : print_done <= 1
    }
    P_DONE --> P_IDLE : start_print == 0
 ```
