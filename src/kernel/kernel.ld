
/** The physical starting address of the kernel. */
KERNEL_PHYS_START = 1M;

/** The size of the kernel stack. */
KERNEL_STACK_SIZE = 0x4000;

SECTIONS
{
	. = KERNEL_PHYS_START;

	.text :
	{
    /** pointer to boot information. */
    . = . + 8;
		*(.text*)
	}

	.rodata : ALIGN (4K)
	{
		*(.rodata*)
	}

	.data : ALIGN (4K)
	{
		*(.data*)
	}

	.bss : ALIGN (4K)
	{
		*(COMMON)
		*(.bss*)

    . = ALIGN (16);
    stack_bottom = .;
    . += KERNEL_STACK_SIZE;
    stack_top = .;
	}

	kernel_end = .;
}
