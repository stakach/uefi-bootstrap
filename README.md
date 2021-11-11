# OS DEV

This should be a very simple jumping off point to modern kernel development.

The idea behind this project is to provide an easy to understand, minimalist bootstrap that lowers the barrier to entry for any new comers.

Code works for both

* x86_64
* AArch64

run `./build.sh` and you can boot the resulting example kernel on both x86_64 and AArch64


### Crystal Kernel

This bootstrap is being used to load this hobby OS
https://github.com/stakach/crystal-kernel


## Getting started

Very easy to test and run on Windows with [VirtualBox](https://www.virtualbox.org/) see [Crystal Kernel](https://github.com/stakach/crystal-kernel#development-on-macos) for details on how to test and even step through debug your kernel on macOS.

* Compile on Win Linux layer, macOS or Linux
* Clang + LLVM toolchain
* requires [Zig lang](https://ziglang.org/download/)


## Building an EFI bootable executable

EFI expects the bootable file to be in COFF/PE32+ format

* run `./build.sh` to clean and build for all architectures

you can also do this manually

1. run `make -f makefile_x86_64`
2. this will output
  * `bin/efi/boot/bootx64.efi`
  * `bin/kernelx64.elf`
3. you can expect symbols in the object files using `nm -C bin/uefi_bootstrap.obj` (or `kernelx64.elf`)
  * anything with a `U` tag, i.e. `U memcpy` means memcpy needs to be defined in your project


## Create a disk image for booting

Very simple to do this on Windows

* Disk Management (`diskmgmt.msc`)
  * Action -> Create VHD
  * Initialize disk (GPT GUID Partition Table)
  * Format as FAT32
* create the following folder:
  * `/efi/boot`
  * add bootstrap file as `bootx64.efi`
* OR just copy the `bin` folder contents to the VHD

unmount the disk before booting it in VirtualBox
<img src="https://user-images.githubusercontent.com/368013/136745462-d5793f29-e85a-4642-9854-98ea047e3bf9.png" alt="unmount" width="300"/>


## Create a VM

* Install VirtualBox
* Create new VM
  * Type: Other
  * Version: Other/Unknown (64bit)
  * Don't add a HD
* Edit Settings
  * System -> Check "Enable EFI"
  * Storage -> Add default IDE + select VHD image from above

Starting the VM will now boot the bootx64.efi file

<img src="https://user-images.githubusercontent.com/368013/136746021-11f16641-0666-4cdc-bd5a-5d9975eba328.png" alt="unmount" width="700"/>


## Diving into the code

The process of booting should be fairly simple to follow along looking at `uefi_bootstrap.zig`
The real trick with UEFI code is that

* it needs to be in PE/COFF format (think Windows .exe files)
* conform to a particular entrypoint format (`-Wl,-entry:efi_main` in the make file)

The bootstrap code likewise expects a few things of the kernel.elf file:

* Segments need to be 4kb aligned - for paging support
* the entry point takes no params and returns void
* the boot_info structure is going to be stored at address 1MB
  * (no matter where the elf segments request to be loaded)

Take a look at `kernel.ld` to see how this is laid out.
For instance I currently have the `boot_info` label in the `text` section. But I could probably swap around the text and data sections if I wanted boot_info as part of data or bss

### Accessing the full address space

https://eli.thegreenplace.net/2012/01/03/understanding-the-x64-code-models

* this flag is set in the makefile
