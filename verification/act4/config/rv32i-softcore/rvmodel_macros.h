#ifndef RVMODEL_MACROS_H
#define RVMODEL_MACROS_H

#define RVMODEL_DATA_SECTION                                  \
  .pushsection .tohost, "aw", @progbits;                      \
  .align 2;                                                   \
  .global tohost;                                             \
tohost:                                                       \
  .word 0;                                                    \
  .global fromhost;                                           \
fromhost:                                                     \
  .word 0;                                                    \
  .popsection;

#define RVMODEL_HALT                                          \
1:                                                            \
  j 1b

#define RVMODEL_HALT_PASS                                     \
  li t0, 0x8000fff8;                                          \
  li t1, 1;                                                   \
  sw t1, 0(t0);                                               \
  RVMODEL_HALT

#define RVMODEL_HALT_FAIL                                     \
  li t0, 0x8000fff8;                                          \
  sw gp, 0(t0);                                               \
  RVMODEL_HALT

#define RVMODEL_IO_INIT(_R1, _R2, _R3)
#define RVMODEL_IO_WRITE_STR(_R1, _R2, _R3, _STR)
#define RVMODEL_BOOT
#define RVMODEL_DATA_BEGIN
#define RVMODEL_DATA_END
#define RVMODEL_SET_MSW_INT(_R1, _R2)
#define RVMODEL_CLR_MSW_INT(_R1, _R2)
#define RVMODEL_SET_MEXT_INT(_R1, _R2)
#define RVMODEL_CLR_MEXT_INT(_R1, _R2)
#define RVMODEL_SET_SEXT_INT(_R1, _R2)
#define RVMODEL_CLR_SEXT_INT(_R1, _R2)
#define RVMODEL_SET_SSW_INT(_R1, _R2)
#define RVMODEL_CLR_SSW_INT(_R1, _R2)
#define RVMODEL_INTERRUPT_LATENCY 0

#endif
