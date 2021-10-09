.PHONY : uefi_bootstrap
uefi_bootstrap : bin/uefi_bootstrap.obj bin/bootx64.efi

# we want to use clang and output a PE/COFF formatted file
# these are the zig flags
ZFLAGS = \
				-target x86_64-uefi \
				-fClang \
				-ofmt=coff \
				--subsystem efi_application \
				-fLLD

# we want a freestanding executable
CFLAGS+= \
        -target x86_64-unknown-windows \
        -ffreestanding \
        -fshort-wchar \
        -mno-red-zone \
				-Wall

# force use of LLVM Linker and output a PE/COFF formatted file
LDFLAGS+= \
        -target x86_64-unknown-windows \
        -nostdlib \
        -Wl,-entry:efi_main \
        -Wl,-subsystem:efi_application \
        -fuse-ld=lld

# src = $(wildcard src/*.zig)
# obj = $(patsubst %.zig,bin/%.obj,$(src))

bin/uefi_bootstrap.obj : src/uefi_bootstrap.zig
	zig build-obj $(ZFLAGS) -femit-bin=$@ -cflags $(CFLAGS) -- $^

bin/bootx64.efi : bin/uefi_bootstrap.obj
	clang $(CFLAGS) -o $@ $^ $(LDFLAGS)
