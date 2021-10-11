# OS DEV

This should be a very simple jumping off point to modern kernel development.

The idea behind this project is to provide an easy to understand, minimalist bootstrap that lowers the barrier to entry for any new comers.

Code should work for both

* x86_64
* AArch64 (need to change targets in makefile)


## Getting started

Very easy to test and run on Windows with [VirtualBox](https://www.virtualbox.org/)

* Compile on Win Linux layer, macOS or Linux
* Clang + LLVM toolchain
* requires [Zig lang](https://ziglang.org/download/)


## Building an EFI bootable executable

EFI expects the bootable file to be in COFF/PE32+ format

1. run `make`
2. this will output
  * `bin/efi/boot/bootx64.efi`
  * `bin/kernel.elf`
3. you can expect symbols in the object files using `nm -C bin/uefi_bootstrap.obj` (or `kernel.elf`)
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
