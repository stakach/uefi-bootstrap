.PHONY : uefi_bootstrap
uefi_bootstrap : bin/uefi_system.obj bin/bootx64.efi

ZFLAGS = \
				-target x86_64-uefi \
				-fClang \
				-ofmt=coff \
				--subsystem efi_application \
				-fLLD

CFLAGS+= \
        -target x86_64-unknown-windows \
        -ffreestanding \
        -fshort-wchar \
        -mno-red-zone \
				-Wall

LDFLAGS+= \
        -target x86_64-unknown-windows \
        -nostdlib \
        -Wl,-entry:efi_main \
        -Wl,-subsystem:efi_application \
        -fuse-ld=lld

# src = $(wildcard src/*.zig)
# obj = $(patsubst %.zig,bin/%.obj,$(src))

bin/uefi_system.obj : src/uefi_system.zig
	zig build-obj $(ZFLAGS) -femit-bin=$@ -cflags $(CFLAGS) -- $^

bin/bootx64.efi : bin/uefi_system.obj
	clang $(CFLAGS) -o $@ $^ $(LDFLAGS)
