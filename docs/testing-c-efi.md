# OS DEV

Easiest to test on Windows. Compile on Win Linux layer, macOS or Linux

## Building an EFI bootable executable

EFI expects the bootable file to be in COFF/PE32+ format

* See https://dvdhrm.github.io/2019/01/31/goodbye-gnuefi/
* Example https://github.com/c-util/c-efi

### Building c-efi on OSX

1. follow the build instructions on https://github.com/c-util/c-efi
2. in the generated `build.ninja` file remove references to `,-undefined,error`
3. run the `ninja` step again
4. rename `example-hello-world` to `BOOTX64.efi`


## Create a disk image for booting

Very simple to do this on Windows

* Disk Management
  * Action -> Create VHD
  * Initialize disk (GPT GUID Partition Table)
  * Format as FAT32
* create the following folder:
  * `/efi/boot`
  * add bootstrap file as `BOOTX64.efi`

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

Starting the VM will now boot the BOOTX64.efi file
