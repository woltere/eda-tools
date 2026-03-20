# EDA Tools Container

This workspace provides a small Docker-based FPGA tool environment built on `debian:bookworm-slim`.

Included tools:

- `verilator`
- `yosys`
- `graphviz`
- `netlistsvg`
- `nextpnr-himbaechel`
- `gowin_pack`
- `openFPGALoader`

## Files

- `Dockerfile` builds the tool image
- `docker-compose.yml` gives you an interactive shell with the current directory mounted at `/workspace`
- `Makefile` wraps the common commands

## Build

Using plain Docker:

```sh
docker build -t eda-tools:bookworm .
```

Using Docker Compose:

```sh
docker compose build
```

## Run

Open a shell in the container:

```sh
docker compose run --rm eda-tools
```

Or with plain Docker:

```sh
docker run --rm -it -v "$PWD:/workspace" -w /workspace eda-tools:bookworm
```

## Quick Checks

Check the installed tool versions:

```sh
docker compose run --rm eda-tools yosys -V
docker compose run --rm eda-tools verilator --version
docker compose run --rm eda-tools dot -V
docker compose run --rm eda-tools sh -lc 'command -v netlistsvg'
docker compose run --rm eda-tools sh -lc 'command -v nextpnr-himbaechel'
docker compose run --rm eda-tools sh -lc 'command -v gowin_pack'
docker compose run --rm eda-tools sh -lc 'command -v openFPGALoader'
```

Or use the included Make targets:

```sh
make build
make shell
make yosys-version
make verilator-version
make graphviz-version
make netlistsvg-check
```

## Example Project

A deployable Tang Primer 20K Dock example is included at:

- `examples/primer20k-dock-uart`

It sends a repeating UART message over the Dock board's onboard USB serial connection, which makes it easy to verify on real hardware without extra peripherals.

The example also includes a netlist rendering helper that generates Graphviz `.dot` output and a `netlistsvg` schematic.

The image now also includes the open-source Gowin flow needed by the example:

- `nextpnr-himbaechel`
- `gowin_pack`
- `openFPGALoader`

## Waveforms On macOS

This Docker image is intentionally headless. For waveform viewing, it is usually better to run the viewer on macOS and open trace files generated in this workspace.

Common trace formats you can view:

- `.vcd`
- `.fst`

### GTKWave

GTKWave is still the most common FPGA waveform viewer, but its upstream macOS page notes that the older SourceForge macOS build is not compatible with current macOS releases.

Homebrew commands:

```sh
brew install --cask gtkwave
brew install surfer
```

Notes:

- Homebrew currently lists `gtkwave` as a disabled cask, so `brew install --cask gtkwave` may stop working depending on your local Homebrew state.
- `surfer` is currently available as a normal Homebrew formula and is the smoother option on modern macOS.
- If you specifically want GTKWave and the Homebrew cask refuses to install, the practical fallback is building GTKWave from source using the upstream macOS instructions.

Once installed on macOS, open a waveform file from this repository with:

```sh
gtkwave path/to/dump.vcd
```

or:

```sh
open -a GTKWave path/to/dump.vcd
```

### Alternative: Surfer

If you want a modern alternative, [Surfer](https://surfer-project.org/) supports macOS, including Apple Silicon, and also has a web version for quick inspection.

Open a waveform with:

```sh
surfer path/to/dump.vcd
```

### Typical Workflow

1. Run simulation in Docker and write a `.vcd` or `.fst` file into the mounted workspace.
2. Open that file directly on macOS with GTKWave or Surfer.
3. Keep the viewer on the host OS, while synthesis, linting, and other CLI tooling stay in Docker.

## Programming On macOS

Build the bitstream in Docker, then program the FPGA from macOS with `openFPGALoader`.

Install it with Homebrew:

```sh
brew install openfpgaloader
```

Program SRAM for a temporary load:

```sh
openFPGALoader -b tangprimer20k /Users/woltere/Documents/sources/eda-tools/examples/primer20k-dock-uart/build/primer20k-dock-uart.fs
```

Program flash for power-on boot:

```sh
openFPGALoader -b tangprimer20k -f /Users/woltere/Documents/sources/eda-tools/examples/primer20k-dock-uart/build/primer20k-dock-uart.fs
```

Useful checks:

```sh
openFPGALoader --list-boards
openFPGALoader --list-cables
```

This host-side path is recommended on macOS because Docker Desktop does not offer simple direct USB passthrough. This part of the workflow is documented but not yet hardware-verified in this workspace, since your Primer 20K has not arrived yet.

## Notes

This image is now set up for simulation, synthesis, Gowin place-and-route, bitstream packing, and host-side waveform viewing.
