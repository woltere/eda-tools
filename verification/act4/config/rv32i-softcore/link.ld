ENTRY(rvtest_entry_point)

MEMORY
{
  RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 64K
}

SECTIONS
{
  . = ORIGIN(RAM);

  .text.init : {
    *(.text.init)
  } > RAM

  .text : {
    *(.text.rvtest)
    *(.text)
    *(.text.*)
    *(.rodata)
    *(.rodata.*)
  } > RAM

  .bss (NOLOAD) : {
    *(.bss)
    *(.bss.*)
    *(COMMON)
  } > RAM

  .data : {
    *(.data)
    *(.data.*)
    *(.tohost)
  } > RAM
}
