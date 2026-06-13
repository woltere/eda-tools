#define TOHOST_ADDR 0x8000fff8
#define FROMHOST_ADDR 0x8000fffc
#define PASS_CODE 1

#define LOAD_IMM(reg, value) \
  lui reg, %hi(value);       \
  addi reg, reg, %lo(value)

#define WRITE_TOHOST(value_reg) \
  LOAD_IMM(t6, TOHOST_ADDR);    \
  sw value_reg, 0(t6)

#define TEST_PASS            \
  li t0, PASS_CODE;          \
  WRITE_TOHOST(t0);          \
1: j 1b

#define TEST_FAIL(code)      \
  li t0, code;               \
  WRITE_TOHOST(t0);          \
1: j 1b
