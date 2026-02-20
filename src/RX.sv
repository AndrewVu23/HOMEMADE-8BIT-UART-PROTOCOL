module RX(
    input logic clk, reset, ready_clr, rx_en,
    input logic rx_in,
    output logic ready,
    output logic [7:0] rx_out
);
localparam sample_rate = 16;

logic [7:0] data_temp;
logic [3:0] sample_counter;
logic [3:0] index;
logic rx_sync_temp, rx_sync;

typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
state_t state;

always_ff @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        rx_out <= 0;
        ready <= 0;
        rx_sync_temp <= 1'b1;
        rx_sync <= 1'b1;
    end
    else begin
        rx_sync_temp <= rx_in;
        rx_sync <= rx_sync_temp;
        if (ready_clr) ready <= 1'b0;
        case(state)
            IDLE: begin
                index <= 0;
                sample_counter <= 0;
                if (!rx_sync) state <= START;
            end
            START: begin
                if (rx_en) begin           
                    if (sample_counter == sample_rate/2 - 1) begin
                        if (rx_sync) state <= IDLE;
                        else sample_counter <= sample_counter + 1;
                    end
                    else if (sample_counter == sample_rate - 1) begin
                        index <= 0;
                        sample_counter <= 0;
                        state <= DATA;
                    end
                    else sample_counter <= sample_counter + 1;
                end
            end
            DATA: begin
                if (rx_en) begin          
                    if (sample_counter == sample_rate/2 - 1) begin 
                        data_temp[index] <= rx_sync;
                        sample_counter <= sample_counter + 1;
                    end
                    else if (sample_counter == sample_rate - 1) begin 
                        sample_counter <= 0;
                        if (index == 7) state <= STOP;
                        else index <= index + 1;
                    end
                    else sample_counter <= sample_counter + 1;
                end
            end
            STOP: begin
                if (rx_en) begin
                    if (sample_counter == sample_rate/2 - 1) begin
                        if (rx_sync) begin
                            ready <= 1'b1;
                            rx_out <= data_temp;
                            sample_counter <= sample_counter + 1;
                        end
                        else sample_counter <= sample_counter + 1;
                    end
                    else if (sample_counter == sample_rate - 1) begin
                        sample_counter <= 0;
                        state <= IDLE;
                    end
                    else sample_counter <= sample_counter + 1;
                end
            end
            default: state <= IDLE;
        endcase
    end
end
endmodule