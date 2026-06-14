# EDA Tools Container

This workspace provides a small Docker-based FPGA tool environment built on `debian:bookworm-slim`.
The image uses multi-stage builds so source build dependencies stay out of the final runtime image.

Included tools:

- `verilator`
- `yosys` built from source
- `sv2v` built from source
- `verible`
- `riscv64-unknown-elf-gcc`
- `riscv64-unknown-elf-objcopy`
- `graphviz`
- `netlistsvg`
- `nextpnr-himbaechel` built from source
- `gowin_pack`
- `openFPGALoader`

## Files

- `Dockerfile` builds the tool image
- `docker-compose.yml` gives you an interactive shell with the current directory mounted at `/workspace`
- `Makefile` wraps the common commands

## Build

Using plain Docker:

```sh
IMAGE_TAG=bookworm-$(git branch --show-current | tr '[:upper:]' '[:lower:]' | tr '/' '-')
docker build -t "eda-tools:${IMAGE_TAG}" .
```

Using Docker Compose:

```sh
make build
```

`make build` tags the image as `eda-tools:bookworm-<current-git-tag-or-branch>`.
For the current branch, that becomes `eda-tools:bookworm-update-versions-and-improvements`.
Git refs are lowercased and made Docker-tag-safe.

You can override the tag manually:

```sh
IMAGE_TAG=bookworm-experiment make build
```

If you use Docker Compose directly, pass the same tag variable yourself:

```sh
EDA_TOOLS_IMAGE_TAG=bookworm-$(git branch --show-current | tr '[:upper:]' '[:lower:]' | tr '/' '-') docker compose build
```

The source-built and package-installed tool versions can be overridden with build args:

```sh
YOSYS_REF=v0.66 \
NEXTPNR_REF=nextpnr-0.10 \
SV2V_REF=v0.0.13 \
APYCULA_VERSION=0.32 \
NETLISTSVG_VERSION=1.0.2 \
VERIBLE_REF=v0.0-4071-g8d9f2c97 \
MAKE_JOBS=8 \
make build
```

The default build args are:

- `BASE_IMAGE=debian:bookworm-slim`
- `YOSYS_REF=v0.66`
- `NEXTPNR_REF=nextpnr-0.10`
- `SV2V_REF=v0.0.13`
- `APYCULA_VERSION=0.32`
- `NETLISTSVG_VERSION=1.0.2`
- `VERIBLE_REF=v0.0-4071-g8d9f2c97`
- `MAKE_JOBS`, unset by default, which falls back to `nproc`

## Run

Open a shell in the container:

```sh
make shell
```

Or with plain Docker:

```sh
docker run --rm -it -v "$PWD:/workspace" -w /workspace "$(make image-name)"
```

## Quick Checks

Check the installed tool versions:

```sh
make tool-versions
make yosys-version
make sv2v-version
make nextpnr-version
make verible-version
make verilator-version
make riscv-gcc-version
make graphviz-version
make netlistsvg-check
```

Or use the included Make targets:

```sh
make build
make image-name
make shell
make tool-versions
make yosys-version
make sv2v-version
make nextpnr-version
make verible-version
make verilator-version
make riscv-gcc-version
make graphviz-version
make netlistsvg-check
```

## Example Projects

A deployable Tang Primer 20K Dock example is included at:

- `examples/primer20k-dock-uart`

It sends a repeating UART message over the Dock board's onboard USB serial connection, which makes it easy to verify on real hardware without extra peripherals.

The example also includes a netlist rendering helper that generates Graphviz `.dot` output and a `netlistsvg` schematic.

The image now also includes the open-source Gowin flow needed by the example:

- `nextpnr-himbaechel`
- `gowin_pack`
- `openFPGALoader`

An RV32I softcore workspace is included at:

- `rtl/rv32i`
- `sim/rv32i`
- `verification/act4`

## RV32I Softcore Workspace

The new RISC-V workspace is simulation-first. It uses a 5-stage in-order SystemVerilog core with:

- reset PC `0x80000000`
- unified 64 KiB RAM at `0x80000000`
- `tohost` at `0x8000fff8`
- `fromhost` at `0x8000fffc`
- machine-mode traps and the minimum CSR set needed for bring-up

Main files:

- `rtl/rv32i/rv32i_core.sv`
- `sim/rv32i/rv32i_system.sv`
- `sim/rv32i/tb_top.cpp`
- `sim/rv32i/build-program.sh`
- `sim/rv32i/run-sim.sh`
- `sim/rv32i/run-directed-tests.sh`

The directed test sources are under:

- `sim/rv32i/tests`

Typical flow in the container:

```sh
docker compose run --rm eda-tools sh -lc 'sim/rv32i/build-program.sh sim/rv32i/tests/basic.S'
docker compose run --rm eda-tools sh -lc 'sim/rv32i/run-directed-tests.sh'
```

Helpful Make targets:

```sh
make rv32i-lint
make rv32i-build-basic
make rv32i-run-basic
make rv32i-test
```

The simulation contract is:

- programs are built as ELF files and converted into flat little-endian `.hex` images
- the Verilator harness loads that image before reset release
- `tohost == 1` means pass
- any other nonzero `tohost` value means fail

### Core Architecture

The current RV32I core is still an early monolithic implementation, but the intended structure is a refactor into a top-level pipeline shell plus separate stage modules.

- the top-level core will own the PC, pipeline registers, stall/flush behavior, bypassing, hazards, and extension arbitration
- stage modules will handle mostly stage-local combinational logic
- extensions will be compile-time selectable and synthesize away cleanly when disabled
- the first extension seam is being designed around `M`, with later support for `Zicsr`, `Zifencei`, and other RISC-V extensions

The public contracts stay stable through that refactor:

- the unified memory bus remains the external core interface
- stage-to-stage communication is intended to move toward typed records from shared package files
- feature selection is intended to be centralized in one compile-time config type
- extension plug-ins are intended to use decode and execute response records rather than directly mutating global pipeline state

## ACT4 / Official Certification Path

The repo now also includes a starter ACT4 layout under:

- `verification/act4`

That directory contains:

- DUT-side config files
- helper scripts to clone the `act4` branch of `riscv-arch-test`
- a script to generate self-checking ELFs
- a script to convert generated ELFs into `.hex` files and run them through the Verilator harness

Important current constraint:

- day-to-day RTL work stays Docker-based in this repo
- the upstream ACT4 flow currently depends on `riscv-unified-db`, which upstream documents as requiring `podman`

So the intended split is:

1. use Docker for editing, linting, compiling, and directed simulation
2. use a Podman-capable Linux machine for the official ACT4 flow

Starter commands:

```sh
verification/act4/clone-act4.sh
verification/act4/generate-elfs.sh
verification/act4/run-verilator-suite.sh verification/act4/work/act4-out/rv32i-softcore/elfs
```

The ACT4 scaffold is checked in, but it was not validated end to end here because Podman is not installed in this environment.

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
