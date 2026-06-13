#include <cstdlib>
#include <cstdint>
#include <iostream>
#include <string>

#include "Vtop.h"
#include "verilated.h"

#if VM_TRACE_FST
#include "verilated_fst_c.h"
#elif VM_TRACE_VCD
#include "verilated_vcd_c.h"
#else
#error "A Verilator trace backend must be enabled."
#endif

namespace {

vluint64_t main_time = 0;
constexpr int kClksPerBit = 234;
const std::string kExpectedMessage = "Hello from Primer 20K!\r\n";

#if VM_TRACE_FST
using TraceT = VerilatedFstC;
#else
using TraceT = VerilatedVcdC;
#endif

double sc_time_stamp() {
    return static_cast<double>(main_time);
}

void tick(Vtop& top, TraceT& trace) {
    top.clk_27mhz = 0;
    top.eval();
    trace.dump(main_time++);

    top.clk_27mhz = 1;
    top.eval();
    trace.dump(main_time++);
}

struct UartDecoder {
    bool prev_tx = true;
    bool receiving = false;
    int clocks_until_sample = 0;
    int bit_index = 0;
    std::uint8_t current_byte = 0;
    std::string decoded;

    void observe(bool tx_level) {
        if (!receiving) begin_observation(tx_level);
        else sample(tx_level);
        prev_tx = tx_level;
    }

    void begin_observation(bool tx_level) {
        if (prev_tx && !tx_level) {
            receiving = true;
            clocks_until_sample = kClksPerBit + (kClksPerBit / 2);
            bit_index = 0;
            current_byte = 0;
        }
    }

    void sample(bool tx_level) {
        if (clocks_until_sample > 0) {
            --clocks_until_sample;
            return;
        }

        if (bit_index < 8) {
            if (tx_level) {
                current_byte |= static_cast<std::uint8_t>(1u << bit_index);
            }
            ++bit_index;
            clocks_until_sample = kClksPerBit - 1;
            return;
        }

        if (!tx_level) {
            std::cerr << "UART stop bit was low\n";
            std::exit(1);
        }

        decoded.push_back(static_cast<char>(current_byte));
        receiving = false;
    }
};

}  // namespace

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    std::string output_path = "build/sim/top.fst";
    vluint64_t cycles = 70000;

    if (argc >= 2) {
        output_path = argv[1];
    }
    if (argc >= 3) {
        cycles = static_cast<vluint64_t>(std::strtoull(argv[2], nullptr, 10));
    }

    Vtop top;
    TraceT trace;
    UartDecoder decoder;

    Verilated::traceEverOn(true);
    top.trace(&trace, 99);
    trace.open(output_path.c_str());

    top.reset_n = 0;
    top.clk_27mhz = 0;
    top.eval();

    for (int i = 0; i < 10; ++i) {
        tick(top, trace);
    }

    top.reset_n = 1;

    for (vluint64_t i = 0; i < cycles; ++i) {
        tick(top, trace);
        decoder.observe(top.uart_tx);
        if (Verilated::gotFinish()) {
            break;
        }
    }

    top.final();
    trace.close();

    const bool should_check_message = cycles >= 60000;
    if (should_check_message) {
        if (decoder.decoded.find(kExpectedMessage) == std::string::npos) {
            std::cerr << "Decoded UART stream did not contain expected message.\n";
            std::cerr << "Expected: " << kExpectedMessage << "\n";
            std::cerr << "Decoded:  " << decoder.decoded << "\n";
            return 1;
        }
    }

    std::cout << "Generated waveform: " << output_path << "\n";
    std::cout << "Simulated cycles: " << cycles << "\n";
    if (!decoder.decoded.empty()) {
        std::cout << "Decoded UART: " << decoder.decoded << "\n";
    }
    return 0;
}
