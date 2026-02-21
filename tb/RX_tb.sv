`timescale 1ns / 1ps

module RX_tb;
    localparam N = 8;
    localparam BIT_PERIOD = 8680;

    logic clk, reset, write_en, ready_clr, rx_in, tx_out, ready, busy;
    logic [7:0] tx_in, rx_out;

    UART #(.N(N)) dut (
        .clk(clk),
        .reset(reset),
        .write_en(write_en),
        .ready_clr(ready_clr),
        .rx_in(rx_in),
        .tx_out(tx_out),
        .ready(ready),
        .busy(busy),
        .tx_in(tx_in),
        .rx_out(rx_out)
    );
    integer i;

    initial clk = 0;
    always #10 clk = ~clk;

    task send_byte(input logic [7:0] data);
        begin
            $display("Time: %t | Sending Valid Byte: %b", $time, data);
            rx_in = 0; #BIT_PERIOD;
            for (i = 0; i < 8; i = i + 1) begin
                rx_in = data[i]; #BIT_PERIOD;
            end
            rx_in = 1; #BIT_PERIOD;
        end
    endtask

    task handshake();
        begin
            @(posedge clk);
            ready_clr = 1;
            @(posedge clk);
            ready_clr = 0;
            $display("Time: %t | ready: %d ", $time, ready);
        end
    endtask

    task test_glitch_start();
        begin
            $display("Time: %t | Testing Glitch: Start Bit Too Short", $time);
            rx_in = 0; #(BIT_PERIOD / 4);
            rx_in = 1; 
            #(BIT_PERIOD * 2);
            if (ready) $display("[FAILED]: FSM Triggered on Glitch");
            else $display("[PASSED]: Glitch Ignored");
        end
    endtask

    task test_framing_error();
        begin
            $display("Time: %t | Testing Framing Error: Stop bit = 0", $time);
            rx_in = 0; #BIT_PERIOD; 
            for (i = 0; i < 8; i = i + 1) begin
                rx_in = 1; #BIT_PERIOD; 
            end
            rx_in = 0; #BIT_PERIOD;
            #(BIT_PERIOD);
            if (ready) $display("[FAILED]: Accepted Data when Stop Bit = 0");
            else $display("[PASSED]");
            rx_in = 1;
            #100;
        end
    endtask

    initial begin
        $dumpfile("sim.vcd");
        $dumpvars(0, RX_tb);
        reset = 1; rx_in = 1; ready_clr = 0; write_en = 0; tx_in = 0;  #100
        reset = 0; #100

        send_byte(8'b10101010); #10
        $display("Time: %t | Received: %b", $time, rx_out); #BIT_PERIOD
        send_byte(8'b11111111); #10
        $display("Time: %t | Received: %b", $time, rx_out); #BIT_PERIOD
        send_byte(8'b11011010); #10
        $display("Time: %t | Received: %b", $time, rx_out); #BIT_PERIOD 
        send_byte(8'b00000000); #10 
        $display("Time: %t | Received: %b", $time, rx_out); #BIT_PERIOD

        wait(ready == 1'b1);

        handshake();
        test_glitch_start();
        test_framing_error();

        #1000;
        $display("Simulation Complete");
        $finish;
    end

endmodule