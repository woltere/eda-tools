#include <cstdlib>
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
        if (Verilated::gotFinish()) {
            break;
        }
    }

    top.final();
    trace.close();

    std::cout << "Generated waveform: " << output_path << "\n";
    std::cout << "Simulated cycles: " << cycles << "\n";
    return 0;
}
