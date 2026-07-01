ARG BASE_IMAGE=debian:bookworm-slim

FROM ${BASE_IMAGE} AS yosys-build

ARG YOSYS_REF=v0.66
ARG MAKE_JOBS

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bison \
        build-essential \
        ca-certificates \
        flex \
        gawk \
        git \
        libffi-dev \
        libfl-dev \
        libreadline-dev \
        pkg-config \
        python3 \
        tcl-dev \
        xz-utils \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --recursive https://github.com/YosysHQ/yosys.git /tmp/yosys \
    && cd /tmp/yosys \
    && git checkout "$YOSYS_REF" \
    && git submodule update --init --recursive \
    && make config-gcc \
    && make -s -j"${MAKE_JOBS:-$(nproc)}" \
    && make install PREFIX=/opt/yosys \
    && rm -rf /tmp/yosys

FROM ${BASE_IMAGE} AS nextpnr-build

ARG NEXTPNR_REF=nextpnr-0.10
ARG APYCULA_VERSION=0.32
ARG MAKE_JOBS

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        git \
        libboost-all-dev \
        libeigen3-dev \
        python3 \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --break-system-packages --no-cache-dir "apycula==${APYCULA_VERSION}"

RUN git clone --recursive https://github.com/YosysHQ/nextpnr.git /tmp/nextpnr \
    && cd /tmp/nextpnr \
    && git checkout "$NEXTPNR_REF" \
    && git submodule update --init --recursive \
    && mkdir -p build \
    && cd build \
    && cmake .. \
        -DARCH="himbaechel" \
        -DHIMBAECHEL_UARCH="gowin" \
        -DBUILD_GUI=OFF \
        -DBUILD_PYTHON=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/nextpnr \
    && make -j"${MAKE_JOBS:-$(nproc)}" \
    && make install \
    && rm -rf /tmp/nextpnr

FROM ${BASE_IMAGE} AS sv2v-build

ARG SV2V_REF=v0.0.13

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        g++ \
        git \
        haskell-stack \
        make \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "$SV2V_REF" https://github.com/zachjs/sv2v.git /tmp/sv2v \
    && cd /tmp/sv2v \
    && make \
    && mkdir -p /opt/sv2v/bin \
    && cp bin/sv2v /opt/sv2v/bin/sv2v \
    && rm -rf /tmp/sv2v /root/.stack

FROM ${BASE_IMAGE} AS apycula-install

ARG APYCULA_VERSION=0.32

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        python3 \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --break-system-packages --no-cache-dir --prefix=/opt/apycula "apycula==${APYCULA_VERSION}"

FROM ${BASE_IMAGE} AS netlistsvg-install

ARG NETLISTSVG_VERSION=1.0.2

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        nodejs \
        npm \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g --prefix /opt/netlistsvg "netlistsvg@${NETLISTSVG_VERSION}"

FROM ${BASE_IMAGE} AS verible-install

ARG VERIBLE_REF=v0.0-4071-g8d9f2c97
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

RUN set -eu; \
    case "$TARGETARCH" in \
        amd64) verible_arch=x86_64 ;; \
        arm64) verible_arch=arm64 ;; \
        *) echo "Unsupported Verible TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    mkdir -p /opt/verible; \
    curl -fsSL "https://github.com/chipsalliance/verible/releases/download/${VERIBLE_REF}/verible-${VERIBLE_REF}-linux-static-${verible_arch}.tar.gz" \
        | tar -xz --strip-components=1 -C /opt/verible

FROM ${BASE_IMAGE}

ARG YOSYS_REF=v0.66
ARG NEXTPNR_REF=nextpnr-0.10
ARG SV2V_REF=v0.0.13
ARG APYCULA_VERSION=0.32
ARG NETLISTSVG_VERSION=1.0.2
ARG VERIBLE_REF=v0.0-4071-g8d9f2c97

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/yosys/bin:/opt/nextpnr/bin:/opt/sv2v/bin:/opt/apycula/bin:/opt/apycula/local/bin:/opt/netlistsvg/bin:/opt/verible/bin:${PATH}"
ENV PYTHONPATH="/opt/apycula/lib/python3.11/site-packages:/opt/apycula/local/lib/python3.11/dist-packages"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        binutils-riscv64-unknown-elf \
        ca-certificates \
        g++ \
        gcc-riscv64-unknown-elf \
        binutils-riscv64-unknown-elf \
        picolibc-riscv64-unknown-elf \
        git \
        graphviz \
        libboost-chrono1.74.0 \
        libboost-date-time1.74.0 \
        libboost-filesystem1.74.0 \
        libboost-iostreams1.74.0 \
        libboost-program-options1.74.0 \
        libboost-regex1.74.0 \
        libboost-serialization1.74.0 \
        libboost-system1.74.0 \
        libboost-thread1.74.0 \
        libffi8 \
        libfl2 \
        libgmp10 \
        libreadline8 \
        libtcl8.6 \
        make \
        nodejs \
        openfpgaloader \
        python3 \
        verilator \
        zlib1g-dev \
        imagemagick \ 
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=yosys-build /opt/yosys /opt/yosys
COPY --from=nextpnr-build /opt/nextpnr /opt/nextpnr
COPY --from=sv2v-build /opt/sv2v /opt/sv2v
COPY --from=apycula-install /opt/apycula /opt/apycula
COPY --from=netlistsvg-install /opt/netlistsvg /opt/netlistsvg
COPY --from=verible-install /opt/verible /opt/verible

RUN set -eu; \
    for dir in \
        /opt/yosys/bin \
        /opt/nextpnr/bin \
        /opt/sv2v/bin \
        /opt/apycula/bin \
        /opt/apycula/local/bin \
        /opt/netlistsvg/bin \
        /opt/verible/bin; \
    do \
        if [ -d "$dir" ]; then \
            for tool in "$dir"/*; do \
                [ -e "$tool" ] || continue; \
                ln -sf "$tool" "/usr/local/bin/$(basename "$tool")"; \
            done; \
        fi; \
    done

WORKDIR /workspace

RUN ldd "$(command -v yosys)" \
    && ldd "$(command -v nextpnr-himbaechel)" \
    && case "$YOSYS_REF" in v[0-9]*) yosys -V | grep -F "Yosys ${YOSYS_REF#v}" ;; *) yosys -V ;; esac \
    && verilator --version \
    && dot -V \
    && riscv64-unknown-elf-gcc --version \
    && riscv64-unknown-elf-objcopy --version >/dev/null \
    && test "$(sv2v --numeric-version)" = "${SV2V_REF#v}" \
    && nextpnr-himbaechel --version \
    && command -v netlistsvg >/dev/null \
    && verible-verilog-format --version \
    && verible-verilog-lint --version \
    && command -v gowin_pack >/dev/null \
    && command -v openFPGALoader >/dev/null

CMD ["bash"]
