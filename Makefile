IMAGE_NAME := eda-tools:bookworm
SERVICE := eda-tools

.PHONY: build shell yosys-version verilator-version graphviz-version netlistsvg-check \
	riscv-gcc-version rv32i-lint rv32i-build-basic rv32i-run-basic rv32i-test

build:
	docker compose build

shell:
	docker compose run --rm $(SERVICE)

yosys-version:
	docker compose run --rm $(SERVICE) yosys -V

verilator-version:
	docker compose run --rm $(SERVICE) verilator --version

graphviz-version:
	docker compose run --rm $(SERVICE) dot -V

netlistsvg-check:
	docker compose run --rm $(SERVICE) sh -lc 'command -v netlistsvg'

riscv-gcc-version:
	docker compose run --rm $(SERVICE) riscv64-unknown-elf-gcc --version

rv32i-lint:
	docker compose run --rm $(SERVICE) verilator --lint-only -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-CASEINCOMPLETE rtl/rv32i/rv32i_core.sv sim/rv32i/rv32i_system.sv

rv32i-build-basic:
	docker compose run --rm $(SERVICE) sh -lc 'sim/rv32i/build-program.sh sim/rv32i/tests/basic.S'

rv32i-run-basic:
	docker compose run --rm $(SERVICE) sh -lc "hex=\$$(sim/rv32i/build-program.sh sim/rv32i/tests/basic.S); sim/rv32i/run-sim.sh \"\$$hex\" sim/rv32i/build/basic.fst 20000"

rv32i-test:
	docker compose run --rm $(SERVICE) sh -lc 'sim/rv32i/run-directed-tests.sh'
