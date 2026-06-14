GIT_REF := $(shell git describe --tags --exact-match 2>/dev/null || git branch --show-current 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo dev)
IMAGE_REF := $(shell echo "$(GIT_REF)" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_.-]+/-/g; s/^-+//; s/-+$$//')
IMAGE_TAG ?= bookworm-$(IMAGE_REF)
IMAGE_NAME := eda-tools:$(IMAGE_TAG)
SERVICE := eda-tools
COMPOSE := EDA_TOOLS_IMAGE_TAG=$(IMAGE_TAG) docker compose

.PHONY: image-name build shell tool-versions yosys-version sv2v-version nextpnr-version verible-version \
	verilator-version graphviz-version netlistsvg-check \
	riscv-gcc-version rv32i-lint rv32i-build-basic rv32i-run-basic rv32i-test

image-name:
	@echo $(IMAGE_NAME)

build:
	$(COMPOSE) build

shell:
	$(COMPOSE) run --rm $(SERVICE)

tool-versions: yosys-version sv2v-version nextpnr-version verible-version verilator-version riscv-gcc-version graphviz-version netlistsvg-check

yosys-version:
	$(COMPOSE) run --rm $(SERVICE) yosys -V

sv2v-version:
	$(COMPOSE) run --rm $(SERVICE) sv2v --numeric-version

nextpnr-version:
	$(COMPOSE) run --rm $(SERVICE) nextpnr-himbaechel --version

verible-version:
	$(COMPOSE) run --rm $(SERVICE) sh -lc 'verible-verilog-format --version && verible-verilog-lint --version'

verilator-version:
	$(COMPOSE) run --rm $(SERVICE) verilator --version

graphviz-version:
	$(COMPOSE) run --rm $(SERVICE) dot -V

netlistsvg-check:
	$(COMPOSE) run --rm $(SERVICE) sh -lc 'command -v netlistsvg'

riscv-gcc-version:
	$(COMPOSE) run --rm $(SERVICE) riscv64-unknown-elf-gcc --version

rv32i-lint:
	$(COMPOSE) run --rm $(SERVICE) verilator --lint-only -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-CASEINCOMPLETE rtl/rv32i/rv32i_core.sv sim/rv32i/rv32i_system.sv

rv32i-build-basic:
	$(COMPOSE) run --rm $(SERVICE) sh -lc 'sim/rv32i/build-program.sh sim/rv32i/tests/basic.S'

rv32i-run-basic:
	$(COMPOSE) run --rm $(SERVICE) sh -lc "hex=\$$(sim/rv32i/build-program.sh sim/rv32i/tests/basic.S); sim/rv32i/run-sim.sh \"\$$hex\" sim/rv32i/build/basic.fst 20000"

rv32i-test:
	$(COMPOSE) run --rm $(SERVICE) sh -lc 'sim/rv32i/run-directed-tests.sh'
