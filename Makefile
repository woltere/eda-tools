GIT_REF := $(shell git describe --tags --exact-match 2>/dev/null || git branch --show-current 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo dev)
IMAGE_REF := $(shell echo "$(GIT_REF)" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_.-]+/-/g; s/^-+//; s/-+$$//')
IMAGE_TAG ?= bookworm-$(IMAGE_REF)
IMAGE_NAME := eda-tools:$(IMAGE_TAG)
SERVICE := eda-tools
COMPOSE := EDA_TOOLS_IMAGE_TAG=$(IMAGE_TAG) docker compose
SYFT_IMAGE ?= anchore/syft:v1.45.1
SBOM_DIR ?= build/sbom
SBOM_IMAGE_REF := $(shell echo "$(IMAGE_NAME)" | sed 's/[/:]/_/g')
SBOM_FILE ?= $(SBOM_DIR)/$(SBOM_IMAGE_REF).spdx.json
SBOM_TABLE_FILE ?= $(SBOM_DIR)/$(SBOM_IMAGE_REF).txt
SBOM_FORMAT ?= spdx-json
CHECK_TOOL_UPDATES_STRICT ?= 0

.PHONY: image-name build shell sbom sbom-table check-tool-updates tool-versions yosys-version sv2v-version nextpnr-version verible-version \
	verilator-version graphviz-version netlistsvg-check \
	riscv-gcc-version

image-name:
	@echo $(IMAGE_NAME)

build:
	$(COMPOSE) build

shell:
	$(COMPOSE) run --rm $(SERVICE)

sbom:
	@mkdir -p "$(SBOM_DIR)"
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v "$(CURDIR)/$(SBOM_DIR):/sbom" \
		$(SYFT_IMAGE) "$(IMAGE_NAME)" -o "$(SBOM_FORMAT)=/sbom/$(notdir $(SBOM_FILE))"
	@echo "SBOM written to $(SBOM_FILE)"

sbom-table:
	@mkdir -p "$(SBOM_DIR)"
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v "$(CURDIR)/$(SBOM_DIR):/sbom" \
		$(SYFT_IMAGE) "$(IMAGE_NAME)" -o "table=/sbom/$(notdir $(SBOM_TABLE_FILE))"
	@echo "Human-readable SBOM written to $(SBOM_TABLE_FILE)"

check-tool-updates:
	CHECK_TOOL_UPDATES_STRICT=$(CHECK_TOOL_UPDATES_STRICT) sh scripts/check-tool-updates.sh

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
