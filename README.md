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
- `scripts/check-tool-updates.sh` checks pinned tool versions against upstream

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
make sbom
make sbom-table
make check-tool-updates
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

## Security Checks

Generate an SPDX JSON SBOM for the built image:

```sh
make build
make sbom
```

The SBOM is written under `build/sbom/`.
Generate a human-readable table as well:

```sh
make sbom-table
```

The target uses a pinned Syft scanner image by default:

```sh
SYFT_IMAGE=anchore/syft:v1.45.1 make sbom
```

Check whether newer pinned tool versions are available upstream:

```sh
make check-tool-updates
```

This checks the Dockerfile defaults for `YOSYS_REF`, `NEXTPNR_REF`, `SV2V_REF`, `APYCULA_VERSION`, `NETLISTSVG_VERSION`, and `VERIBLE_REF`.
Debian-packaged runtime tools are updated by rebuilding from the current base image repositories.
Use `CHECK_TOOL_UPDATES_STRICT=1 make check-tool-updates` when you want the command to fail if an update is available.

## Example Projects

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
openFPGALoader -b tangprimer20k examples/primer20k-dock-uart/build/primer20k-dock-uart.fs
```

Program flash for power-on boot:

```sh
openFPGALoader -b tangprimer20k -f examples/primer20k-dock-uart/build/primer20k-dock-uart.fs
```

Useful checks:

```sh
openFPGALoader --list-boards
openFPGALoader --list-cables
```

This host-side path is recommended on macOS because Docker Desktop does not offer simple direct USB passthrough.

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE).

Third-party tools installed in the Docker image are distributed under their own licenses. Use the generated SBOM for dependency and license visibility.

## Notes

This image is now set up for simulation, synthesis, Gowin place-and-route, bitstream packing, and host-side waveform viewing.
