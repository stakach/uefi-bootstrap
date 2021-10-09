# OS DEV

Easiest to test on Windows. Compile on Win Linux layer, macOS or Linux

## Building an EFI bootable executable

EFI expects the bootable file to be in COFF/PE32+ format

1. run `make`
2. this will output `bin/bootx64.efi`
3. you can expect symbols in the object files using `nm -C bin/uefi_bootstrap.obj`
  * anything with a `U` tag, i.e. `U memcpy` means memcpy needs to be defined in your project

## Create a disk image for booting

Very simple to do this on Windows

* Disk Management
  * Action -> Create VHD
  * Initialize disk (GPT GUID Partition Table)
  * Format as FAT32
* create the following folder:
  * `/efi/boot`
  * add bootstrap file as `bootx64.efi`

unmount the disk before booting it in VirtualBox


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
