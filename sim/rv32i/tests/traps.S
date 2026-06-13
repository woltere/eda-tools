#include "test_macros.h"

.section .text.init
.globl _start
_start:
  LOAD_IMM(t0, trap_handler)
  csrw mtvec, t0
  LOAD_IMM(t0, trap_index)
  csrw mscratch, t0

  ecall
after_ecall:
  .word 0
after_illegal:
  LOAD_IMM(t1, data_word)
  addi t1, t1, 1
  lw t2, 0(t1)
after_misaligned_load:
  LOAD_IMM(t1, data_word)
  addi t1, t1, 2
  sw t2, 0(t1)
after_misaligned_store:
  LOAD_IMM(t1, misaligned_target + 2)
  jalr zero, 0(t1)
after_bad_jalr:
  TEST_PASS

fail:
  TEST_FAIL(6)

trap_handler:
  csrr t0, mcause
  csrr t1, mepc
  csrr t2, mscratch
  lw t3, 0(t2)

  beqz t3, expect_ecall
  li t4, 1
  beq t3, t4, expect_illegal
  li t4, 2
  beq t3, t4, expect_load
  li t4, 3
  beq t3, t4, expect_store
  li t4, 4
  beq t3, t4, expect_jalr
  j fail

expect_ecall:
  li t4, 11
  bne t0, t4, fail
  LOAD_IMM(t4, after_ecall)
  bne t1, t4, fail
  li t4, 1
  sw t4, 0(t2)
  LOAD_IMM(t4, after_ecall)
  addi t4, t4, 4
  csrw mepc, t4
  mret

expect_illegal:
  li t4, 2
  bne t0, t4, fail
  LOAD_IMM(t4, after_ecall + 4)
  bne t1, t4, fail
  li t4, 2
  sw t4, 0(t2)
  LOAD_IMM(t4, after_illegal)
  csrw mepc, t4
  mret

expect_load:
  li t4, 4
  bne t0, t4, fail
  LOAD_IMM(t4, after_illegal)
  bne t1, t4, fail
  li t4, 3
  sw t4, 0(t2)
  LOAD_IMM(t4, after_misaligned_load)
  csrw mepc, t4
  mret

expect_store:
  li t4, 6
  bne t0, t4, fail
  LOAD_IMM(t4, after_misaligned_load)
  bne t1, t4, fail
  li t4, 4
  sw t4, 0(t2)
  LOAD_IMM(t4, after_misaligned_store)
  csrw mepc, t4
  mret

expect_jalr:
  li t4, 0
  bne t0, t4, fail
  LOAD_IMM(t4, after_misaligned_store)
  bne t1, t4, fail
  li t4, 5
  sw t4, 0(t2)
  LOAD_IMM(t4, after_bad_jalr)
  csrw mepc, t4
  mret

misaligned_target:
  nop

.section .data
.align 2
trap_index:
  .word 0
data_word:
  .word 0x11223344
