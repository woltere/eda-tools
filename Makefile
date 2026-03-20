IMAGE_NAME := eda-tools:bookworm
SERVICE := eda-tools

.PHONY: build shell yosys-version verilator-version graphviz-version netlistsvg-check

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
