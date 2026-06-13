ENTRY(_start)

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
    *(.text)
    *(.text.*)
    *(.rodata)
    *(.rodata.*)
  } > RAM

  .data : {
    *(.data)
    *(.data.*)
    *(.sdata)
    *(.sdata.*)
  } > RAM

  .bss (NOLOAD) : ALIGN(4) {
    *(.bss)
    *(.bss.*)
    *(.sbss)
    *(.sbss.*)
    *(COMMON)
  } > RAM

  /DISCARD/ : {
    *(.comment)
    *(.eh_frame)
  }
}
