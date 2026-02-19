module baud_rate_gen(
    input logic clk,
    output logic tx_en, rx_en
);
localparam cnt_bits = 434;
localparam samp_rate = 16;

logic [9:0] tx_counter;
logic [5:0] rx_counter;

always_ff @(posedge clk) begin
    if (tx_counter == cnt_bits - 1) begin
        tx_counter <= 0;
        tx_en <= 1'b1;
    end
    else begin
        tx_en <= 0;
        tx_counter <= tx_counter + 1'b1;
    end
    if (rx_counter == cnt_bits/samp_rate - 1) begin
        rx_counter <= 0;
        rx_en <= 1'b1;
    end
    else begin
        rx_en <= 0;
        rx_counter <= rx_counter + 1'b1;
    end
end
endmodule
