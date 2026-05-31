# Game of Life

A simplified version of John Conway's [Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life), implemented in assembly language for the EPFL CS-200 lab. The game runs on the Gecko5 board with a multicycle RISC-V processor.

## How to Play

The game follows standard Game of Life rules:
- Underpopulation: A living cell dies if it has fewer than two live neighbors.
- Overpopulation: A living cell dies if it has more than three live neighbors.
- Reproduction: A dead cell becomes alive if it has exactly three live neighbors.
- Stasis: A living cell remains alive if it has two or three live neighbors.

#### Game Controls

| Button  | Action |
|---------|--------|
| **jc**  | Cycle through predefined seeds |
| **jr**  | Start the game |
| **b0-b2** | Set game step count (Hex format) |
| **jt**  | Generate a new random seed |
| **jb**  | Reset the game |

You can also find a tag for each button in `docs/buttons.jpeg`.


## How to Run

The simulation uses Verilator, an open-source SystemVerilog simulator.
To install it, run:

```sh
sudo apt install verilator  # For Ubuntu/Linux
brew install verilator      # For macOS
```

Once Verilator is installed, compile the Verilog code with the following command:

```
verilator --binary --trace -Wno-fatal --top-module tb_controller -o Vtb_controller testbench/tb_controller.v verilog/controller.v
````

This should generate the Vtb_controller binary.
