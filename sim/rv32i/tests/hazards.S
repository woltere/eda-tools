#include "test_macros.h"

.section .text.init
.globl _start
_start:
  LOAD_IMM(t0, trap_handler)
  csrw mtvec, t0

  li t0, 10
  li t1, 20
  add t2, t0, t1
  add t3, t2, t0
  li t4, 40
  bne t3, t4, fail

  addi t5, t3, 2
  li t6, 42
  bne t5, t6, fail

  LOAD_IMM(s0, data_word)
  sw t5, 0(s0)
  lw s1, 0(s0)
  add s2, s1, t0
  li s3, 52
  bne s2, s3, fail

  add s4, s2, s1
  li s5, 94
  bne s4, s5, fail

  TEST_PASS

fail:
  TEST_FAIL(4)

trap_handler:
  TEST_FAIL(5)

.section .data
.align 2
data_word:
  .word 0
