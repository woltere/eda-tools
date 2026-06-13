# ACT4 Starter Flow

This directory is the repo-owned starting point for the official RISC-V certification flow around the `act4` branch of `riscv-arch-test`.

What is here:

- `config/rv32i-softcore`: DUT configuration files that match the simulation harness memory map and CSR behavior
- `clone-act4.sh`: clones the upstream `act4` branch into a local work area
- `generate-elfs.sh`: asks ACT4 to generate and compile self-checking ELFs
- `run-verilator-suite.sh`: converts ACT4 ELFs to hex and runs them through the Verilator harness

Current expectation:

- use Podman on a Linux machine for the ACT4 side
- use the Docker image in the repo for everyday RTL work
- keep the DUT memory map aligned with `sim/rv32i/link.ld`

Important note:

The `riscv-arch-test` project currently states that ACT4 depends on `riscv-unified-db`, and that flow currently depends on Podman. I could not validate that end to end in this environment because Podman is not installed here, so treat this directory as a checked-in starting scaffold that should be verified on your Podman-capable machine.

Typical flow on a Podman-capable Linux host:

```sh
verification/act4/clone-act4.sh
verification/act4/generate-elfs.sh
verification/act4/run-verilator-suite.sh verification/act4/work/act4-out/rv32i-softcore/elfs
```
