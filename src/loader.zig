const uefi = @import("std").os.uefi;
const console = @import("./console.zig");

pub fn load_kernel_image(
    boot_services: *uefi.tables.BootServices,
    file_system: *uefi.protocols.FileProtocol,
    file_path: [*:0]const u16
) uefi.Status {
    var kernel_img_file: *uefi.protocols.FileProtocol = undefined;
    var result = file_system.open(&kernel_img_file, file_path, uefi.protocols.FileProtocol.efi_file_mode_read, uefi.protocols.FileProtocol.efi_file_read_only);
    if (result != uefi.Status.Success) { return result; }

    console.puts("  -> file found\r\n");

    // var printf_buf: [100]u8 = undefined;
    // printf(printf_buf[0..], "  -> kernel file size {}\r\n", .{kernel_img_file.file_size});
    var elf_identity_buffer: [*]align(8) u8 = undefined;
    result = read_and_allocate(boot_services, kernel_img_file, 0, 16, &elf_identity_buffer);
    if (result != uefi.Status.Success) { return result; }

    // check magic header is an elf file
    // EI_CLASS == 4
    if((elf_identity_buffer[0] != 0x7F) or
        (elf_identity_buffer[1] != 0x45) or
        (elf_identity_buffer[2] != 0x4C) or
        (elf_identity_buffer[3] != 0x46)) {
        return uefi.Status.InvalidParameter;
    }

    return uefi.Status.Success;
}

fn read_file(file: *uefi.protocols.FileProtocol, position: u64, size: usize, buffer: *[*]align(8) u8) uefi.Status {
    console.puts("  -> positioning file\r\n");
    var result = file.setPosition(position);
    if (result != uefi.Status.Success) { return result; }

    console.puts("  -> copying into memory\r\n");

    return file.read(&@ptrCast(usize, size), buffer.*);
}

fn read_and_allocate(boot_services: *uefi.tables.BootServices, file: *uefi.protocols.FileProtocol, position: u64, size: usize, buffer: *[*]align(8) u8) uefi.Status {
    var result = boot_services.allocatePool(uefi.tables.MemoryType.LoaderData, size, buffer);
    if (result != uefi.Status.Success) { return result; }

    console.puts("  -> allocating memory\r\n");

    return read_file(file, position, size, buffer);
}
