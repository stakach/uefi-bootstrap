.PHONY : uefi_kernel
uefi_kernel : kernel.elf

# we want to use clang and output a PE/COFF formatted file
# these are the zig flags
CC = clang

# we want a freestanding executable
CFLAGS+= \
        -target x86_64-unknown-linux-elf \
        -ffreestanding \
				-O2                   \
				-Wall                 \
				-Wextra

# force use of LLVM Linker and output a PE/COFF formatted file
LDFLAGS+= \
        -target x86_64-unknown-linux-elf \
        -nostdlib \
				-static \
				-ffreestanding    \
				-O2               \
				-T kernel.ld \
				-z max-page-size=0x1000 \
        -Wl,-ekernel_main \
        -fuse-ld=lld

# src = $(wildcard src/*.zig)
# obj = $(patsubst %.zig,bin/%.obj,$(src))

kernel.elf : kernel.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)
