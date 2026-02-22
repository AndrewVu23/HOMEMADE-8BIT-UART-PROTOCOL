# HOMEMADE 8-BIT UART PROTOCOL

A 8-bit Universal Asynchronous Receiver-Transmitter (UART) implementation in SystemVerilog, intended for serial communication between FPGA/ASIC and peripherals (e.g., PCs, microcontrollers, sensors). It is designed for a 50 MHz clock and 115,200 baud, with no parity. The RX path uses a 2-stage flip-flop synchronizer for metastability-safe reception.

## How UART Works

UART (Universal Asynchronous Receiver-Transmitter) is a serial protocol that sends data one bit at a time over a pair of lines (TX and RX). It is asynchronous. Both sides agree on a baud rate in advance and use start/stop bits to frame each byte, so each frame can be decoded without a clock line.

Pros: simple, few wires (2 for full duplex), widely supported, easy to implement. Cons: slower than clocked serial buses, point-to-point only, both sides must use the same baud rate.

### How the Bits Work

UART sends data one bit at a time. The line is idle high. A frame begins with a start bit (high → low). Then 8 data bits are sent least significant bit (LSB) first. Finally, a stop bit pulls the line high again, returning it to idle.

1. Start bit — Line goes from high to low. This marks the beginning of a frame.
2. Data bits — Each bit is held for one bit period. D0 (LSB) is sent first, then D1 … D7.
3. Stop bit — Line is pulled high, signaling end of frame and returning to idle.


| Bit | Name  | Value  | Description                  |
| --- | ----- | ------ | ---------------------------- |
| 0   | START | 0      | Start of frame, high → low   |
| 1–8 | DATA  | D[0:7] | 8 data bits, LSB first       |
| 9   | STOP  | 1      | End of frame, line goes high |

## Baud Rate, Oversampling, and Clock Configuration

### What is Baud Rate?

Baud rate is the number of symbol changes (bits) per second on the serial line. In this case, 115,200 baud means 115,200 bits are transmitted per second.

### Why 115,200 Baud and 50 MHz?

115,200 is a standard rate supported by most terminals, debuggers, and USB-to-serial adapters, making it easy to interface with common tools. 50 MHz is a typical FPGA/system clock.

To achieve 115,200 baud, the design needs one bit period every 434 cycles.

```
Cycles Per Bit = Clock Frequency / Baud Rate 
               = 50,000,000 / 115,200 
               = 434 Cycles
```

### Oversampling

The receiver does not sample once per bit. Instead, it oversamples by taking 16 samples per bit period and uses the sample nearest the center of each bit for the actual data, improving reliability. I chose 16× since it is a common UART choice (8× is riskier, 32× adds more hardware with little gain).

Doing the calculations, we can find that:

- Each bit period has 16 RX samples.
- The RX uses sample index 8 (the middle) for START validation, DATA capture, and STOP validation.

```
Numbers of Sample = Cycles Per Bit / Oversampling Rate 
                  = 434 / 16 
                  = 27 cycles
```

```
Sample that Reads the Data (Center Sample) = Oversampling Rate / 2
                                           = 16 / 2
                                           = 8th Sample
```

## Module Overview


| Module          | File                   | Purpose             |
| --------------- | ---------------------- | ------------------- |
| `UART`          | `src/UART.sv`          | Top-level wrapper   |
| `baud_rate_gen` | `src/baud_rate_gen.sv` | Baud-rate generator |
| `TX`            | `src/TX.sv`            | Transmitter         |
| `RX`            | `src/RX.sv`            | Receiver            |

## Module Descriptions

### `baud_rate_gen` — Baud Rate & Sample Clock Generator

Generates timing enable signals for TX and RX.


| Parameter     | Default | Description            |
| ------------- | ------- | ---------------------- |
| `BIT_CYCLE`   | 434     | Clocks per bit period  |
| `SAMPLE_RATE` | 16      | RX oversampling factor |


Inputs: `clk`, `reset`
Outputs: `tx_en`, `rx_en`

- `tx_en` — Pulses once every `BIT_CYCLE` clocks (bit-rate clock for TX)
- `rx_en` — Pulses every `BIT_CYCLE / SAMPLE_RATE` clocks (16× oversampling for RX)

### `TX` — Transmitter

<img width="700" height="1100" src="https://github.com/user-attachments/assets/12a63e69-462d-40ea-8ad3-6e379cdba9ef" />

| Input        | Description                                                                          |
| ------------ | ------------------------------------------------------------------------------------ |
| `clk`        | System clock                                                                         |
| `reset`      | Synchronous reset                                                                    |
| `tx_en`      | Enable signal from baud generator. Think of it like a separate clock for TX signals. |
| `write_en`   | Assert to load and transmit `tx_in`                                                  |
| `tx_in[7:0]` | 8-bit data to send                                                                   |



| Output   | Description                                                                 |
| -------- | --------------------------------------------------------------------------- |
| `tx_out` | Serial output line                                                          |
| `busy`   | High while a transmission is in progress, preventing new data from entering |


Design notes:

- Idle line is held high
- Data is sampled at the start of the transaction and transmitted LSB first
- `busy` is high whenever the state machine is not in IDLE

### `RX` — Receiver

Receives serial UART frames and reconstructs 8-bit data. Uses a 2-stage flip-flop synchronizer on the incoming serial line for metastability-safe operation.

#### 2-Stage Flip-Flop Synchronizer

The `rx_in` signal is asynchronous to the system clock, so a single flip-flop could enter metastability. The RX uses two consecutive flip-flops:

<img width="300" height="400" alt="image" src="https://github.com/user-attachments/assets/bb0d3d1e-5847-450c-8877-b53dd257d37f" />

- First FF: Captures the asynchronous input; may become metastable
- Second FF: Resamples the output of the first FF, greatly reducing the chance that a metastable value propagates into the RX logic

All RX state-machine logic uses `rx_sync`, never `rx_in` directly, so the design is safe against metastability.

<img width="700" height="1100" src="https://github.com/user-attachments/assets/19c2a58a-a541-41f3-b0fb-80c18dd67845" />

| Input       | Description                                                                          |
| ----------- | ------------------------------------------------------------------------------------ |
| `clk`       | System clock                                                                         |
| `reset`     | Synchronous reset                                                                    |
| `rx_en`     | Enable signal from baud generator. Think of it like a separate clock for RX signals. |
| `rx_in`     | Asynchronous serial input (synchronized internally)                                  |
| `ready_clr` | Assert to acknowledge received data                                                  |



| Output        | Description                              |
| ------------- | ---------------------------------------- |
| `ready`       | High when a valid byte has been received |
| `rx_out[7:0]` | Received 8-bit data                      |


Design notes:

- Think of `ready` like a notification on your phone, but you have not read it. 

- `ready_clr` is like a read receipt that acknowledges that you have viewed the notification.` 

### `UART` — Top-Level

Connects the baud generator, TX, and RX into a single interface.

## How to Run the Simulation

### 1. Install Icarus Verilog

macOS (Homebrew):

```bash
brew install icarus-verilog
```

Linux (Debian/Ubuntu):

```bash
sudo apt install iverilog
```

Linux (Fedora):

```bash
sudo dnf install iverilog
```

Windows: Download the installer from [bleyer.org/icarus](https://bleyer.org/icarus/). Run it and add the install directory (e.g. `C:\iverilog\bin`) to your PATH. Recent installers include GTKWave.

### 2. Install GTKWave

macOS (Homebrew):

```bash
brew install gtkwave
```

Linux (Debian/Ubuntu):

```bash
sudo apt install gtkwave
```

Linux (Fedora):

```bash
sudo dnf install gtkwave
```

Windows: If GTKWave was not included with Icarus Verilog, download it from [gtkwave.sourceforge.net](https://gtkwave.sourceforge.net/) or use the MSYS2 package: `pacman -S mingw-w64-x86_64-gtkwave`. Add the `gtkwave.exe` directory to your PATH.

### 3. Add VCD Dumping (if not already in your testbench)

To generate simulation for GTKWave, add these two lines at the very start of the `initial begin` block in `tb/UART_tb.sv`:

```verilog
$dumpfile("your_file_name.vcd");
$dumpvars(0, UART_tb);
```

`$dumpfile("your_file_name.vcd")` tells the simulator to write the waveform to `your_file_name.vcd`. `$dumpvars(0, UART_tb)` dumps all signals in the `UART_tb` module (the `0` means current scope only). The block should look like:

```systemverilog
    initial begin
        $dumpfile("your_file_name.vcd");
        $dumpvars(0, UART_tb);
       
        ...
        $finish;
    end
```

### 4. Compile and Run

From the project root:

```bash
iverilog -o your_file_name.vvp -g2012 tb/UART_tb.sv src/UART.sv src/baud_rate_gen.sv src/RX.sv src/TX.sv
vvp your_file_name.vvp
```
or
```bash
iverilog -o your_file_name.vvp -g2012 tb/UART_tb.sv src/UART.sv src/*.sv 
vvp your_file_name.vvp
```
folder/*.sv grabs all the files with .sv extensions in your folder

### 5. View the Waveform

```bash
gtkwave your_file_name.vcd
```
