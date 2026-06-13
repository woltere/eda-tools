#include "test_macros.h"

.section .text.init
.globl _start
_start:
  LOAD_IMM(t0, trap_handler)
  csrw mtvec, t0

  li t0, 5
  li t1, 7
  add t2, t0, t1
  li t3, 12
  bne t2, t3, fail

  sub t2, t2, t0
  li t3, 7
  bne t2, t3, fail

  slli t4, t1, 3
  li t5, 56
  bne t4, t5, fail

  srli t4, t4, 2
  li t5, 14
  bne t4, t5, fail

  slt t4, t0, t1
  li t5, 1
  bne t4, t5, fail

  LOAD_IMM(s0, data_words)
  sw t1, 0(s0)
  sw t2, 4(s0)
  lb s1, 0(s0)
  lh s2, 4(s0)
  lw s3, 0(s0)
  li t5, 7
  bne s1, t5, fail
  bne s2, t5, fail
  bne s3, t5, fail

  auipc s4, 0
  addi s4, s4, 12
  jal ra, branch_target
  j fail

branch_target:
  addi s5, ra, 0
  bne s5, s4, fail

  LOAD_IMM(t0, jalr_target)
  jalr zero, 0(t0)
  j fail

jalr_target:
  TEST_PASS

fail:
  TEST_FAIL(2)

trap_handler:
  TEST_FAIL(3)

.section .data
.align 2
data_words:
  .word 0
  .word 0
