module TX(
    input logic clk, reset, tx_en, write_en,
    input logic [7:0] data_in,
    output logic tx_data, busy
);
logic [7:0] data_temp;
logic [3:0] index;

typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
state_t state;

always_ff @(posedge clk) begin
    if (reset) begin 
        state <= IDLE;
        tx_data <= 1'b1;
    end
    else begin
        case(state)
            IDLE: begin
                tx_data <= 1'b1;
                if (write_en) begin
                    state <= START;
                    index <= 3'b0;
                    data_temp <= data_in;
                end
            end
            START: begin
                tx_data <= 1'b0;
                if (tx_en) begin
                    state <= DATA;
                    index <= 0;
                end
            end
            DATA: begin
                tx_data <= data_temp[index];
                if (tx_en) begin
                    if (index == 7) state <= STOP;
                    else index <= index + 1'b1;
                end
            end
            STOP: begin
                tx_data <= 1'b1;
                if (tx_en) state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
end

assign busy = (state != IDLE);

endmodule