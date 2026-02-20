module UART(
    input  logic clk, reset, write_en, ready_clr, rx_in,              
    input  logic [7:0] tx_in,
    output logic tx_out, ready, busy, 
    output logic [7:0] rx_out       
);
    logic tx_en; 
    logic rx_en;

    baud_rate_gen baud_rate_gen_module(
        .clk(clk),
        .tx_en(tx_en), 
        .rx_en(rx_en)  
    );

    RX RX_module(
        .clk(clk),
        .reset(reset),
        .rx_en(rx_en), 
        .rx_in(rx_in),        
        .ready_clr(ready_clr),    
        .ready(ready),        
        .rx_out(rx_out)         
    );

    TX TX_module(
        .clk(clk),
        .reset(reset),
        .tx_en(tx_en), 
        .write_en(write_en),
        .tx_in(tx_in),
        .tx_out(tx_out),
        .busy(busy)   
    );
endmodule