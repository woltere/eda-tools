#include "Vrv32i_system.h"
#include "verilated.h"
#include "verilated_fst_c.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>

static vluint64_t main_time = 0;

double sc_time_stamp() {
    return static_cast<double>(main_time);
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    std::string trace_path;
    uint64_t max_cycles = 20000;

    for (int i = 1; i < argc; ++i) {
        if (std::strncmp(argv[i], "+trace=", 7) == 0) {
            trace_path = argv[i] + 7;
        } else if (std::strncmp(argv[i], "+cycles=", 8) == 0) {
            max_cycles = std::strtoull(argv[i] + 8, nullptr, 10);
        }
    }

    auto top = std::make_unique<Vrv32i_system>();
    std::unique_ptr<VerilatedFstC> trace;

    if (!trace_path.empty()) {
        trace = std::make_unique<VerilatedFstC>();
        top->trace(trace.get(), 99);
        trace->open(trace_path.c_str());
    }

    top->clk = 0;
    top->rst_n = 0;
    top->eval();

    for (int i = 0; i < 5; ++i) {
        top->clk = !top->clk;
        top->eval();
        if (trace) {
            trace->dump(main_time);
        }
        ++main_time;
    }

    top->rst_n = 1;

    for (uint64_t cycle = 0; cycle < max_cycles; ++cycle) {
        top->clk = 0;
        top->eval();
        if (trace) {
            trace->dump(main_time);
        }
        ++main_time;

        top->clk = 1;
        top->eval();
        if (trace) {
            trace->dump(main_time);
        }
        ++main_time;

        if (top->pass) {
            std::printf("PASS after %llu cycles\n", static_cast<unsigned long long>(cycle + 1));
            if (trace) {
                trace->close();
            }
            return 0;
        }
        if (top->fail) {
            std::fprintf(stderr, "FAIL code 0x%08x after %llu cycles\n",
                         top->fail_code,
                         static_cast<unsigned long long>(cycle + 1));
            if (trace) {
                trace->close();
            }
            return 1;
        }
        if (top->trap) {
            std::fprintf(stderr, "Core entered fatal trap state after %llu cycles\n",
                         static_cast<unsigned long long>(cycle + 1));
            if (trace) {
                trace->close();
            }
            return 1;
        }
        if (Verilated::gotFinish()) {
            break;
        }
    }

    std::fprintf(stderr, "Simulation timed out after %llu cycles\n",
                 static_cast<unsigned long long>(max_cycles));
    if (trace) {
        trace->close();
    }
    return 1;
}
