FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        binutils-riscv64-unknown-elf \
        ca-certificates \
        cmake \
        g++ \
        gcc \
        gcc-riscv64-unknown-elf \
        git \
        graphviz \
        libboost-all-dev \
        libeigen3-dev \
        make \
        nodejs \
        npm \
        openfpgaloader \
        pkg-config \
        python3 \
        python3-dev \
        python3-pip \
        verilator \
        yosys \
        zlib1g-dev \
    && npm install -g netlistsvg \
    && pip3 install --break-system-packages --no-cache-dir apycula \
    && git clone --recursive --depth 1 https://github.com/YosysHQ/nextpnr.git /tmp/nextpnr \
    && mkdir -p /tmp/nextpnr/build \
    && cd /tmp/nextpnr/build \
    && cmake .. \
        -DARCH="himbaechel" \
        -DHIMBAECHEL_UARCH="gowin" \
        -DBUILD_GUI=OFF \
        -DBUILD_PYTHON=OFF \
        -DCMAKE_BUILD_TYPE=Release \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /tmp/nextpnr \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

RUN yosys -V \
    && verilator --version \
    && dot -V \
    && riscv64-unknown-elf-gcc --version \
    && riscv64-unknown-elf-objcopy --version >/dev/null \
    && command -v netlistsvg >/dev/null \
    && command -v nextpnr-himbaechel >/dev/null \
    && command -v gowin_pack >/dev/null \
    && command -v openFPGALoader >/dev/null

CMD ["bash"]
