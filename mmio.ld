OUTPUT_ARCH( "riscv" )
ENTRY( _start)

SECTIONS
{
  . = 0x80000000;
  .text.init : { *(.text.init) }
  . = ALIGN(0x100);
  .text : { *(.text) }
  . = ALIGN(0x100);
  .data : { *(.data) }
  .bss : { *(.bss) }
 _end = .;
}