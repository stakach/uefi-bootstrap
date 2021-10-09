// https://uefi.org/sites/default/files/resources/UEFI%20Spec%202_6.pdf
// https://github.com/ziglang/zig/blob/master/lib/std/os/uefi/
// https://github.com/nrdmn/uefi-examples/
// https://www.programmersought.com/article/77814539630/
// https://github.com/ajxs/uefi-elf-bootloader

const uefi = @import("std").os.uefi;
const fmt = @import("std").fmt;
const load_kernel_image = @import("./loader.zig").load_kernel_image;

var console_out: *uefi.protocols.SimpleTextOutputProtocol = undefined;

// EFI uses UCS-2 encoded null-terminated strings. UCS-2 encodes
// code points in exactly 16 bit. Unlike UTF-16, it does not support all
// Unicode code points.
// We need to print each character in an [_]u8 individually because EFI
// encodes strings as UCS-2.
fn puts(msg: []const u8) void {
    for (msg) |c| {
        const c_ = [2]u16{ c, 0 }; // work around https://github.com/ziglang/zig/issues/4372
        _ = console_out.outputString(@ptrCast(*const [1:0]u16, &c_));
    }
}

fn printf(buf: []u8, comptime format: []const u8, args: anytype) void {
    puts(fmt.bufPrint(buf, format, args) catch unreachable);
}

export fn efi_main(handle: u64, system_table: uefi.tables.SystemTable) callconv(.C) uefi.Status {
    console_out = system_table.con_out.?;
    const console_in = system_table.con_in.?;
    const boot_services = system_table.boot_services.?;

    // For use with formatting strings
    var printf_buf: [100]u8 = undefined;

    // Clear screen. reset() returns usize(0) on success
    var result = console_out.clearScreen();
    if (uefi.Status.Success != result) { return result; }

    // obtain access to the file system
    puts("initialising File System service...");
    var simple_file_system: ?*uefi.protocols.SimpleFileSystemProtocol = undefined;
    result = boot_services.locateProtocol(&uefi.protocols.SimpleFileSystemProtocol.guid, null, @ptrCast(*?*c_void, &simple_file_system));
    if (result != uefi.Status.Success) {
        puts(" [failed]\r\n");
        printf(printf_buf[0..], "ERROR {}: initialising file system\r\n", .{result});
        return result;
    }

    // Grab a handle to the FS volume
    var root_file_system: *uefi.protocols.FileProtocol = undefined;
    result = simple_file_system.?.openVolume(&root_file_system);
    if (result != uefi.Status.Success) {
        puts(" [failed]\r\n");
        printf(printf_buf[0..], "ERROR {}: opening file system volume\r\n", .{result});
        return result;
    }
    puts(" [done]\r\n");

    // Start moving the kernel image into memory
    puts("loading kernel...");
    _ = load_kernel_image();

    // prevent system reboot if we don't check-in
    puts("disabling watchdog timer...");
    result = boot_services.setWatchdogTimer(0, 0, 0, null);
    if (result != uefi.Status.Success) {
        puts(" [failed]\r\n");
        printf(printf_buf[0..], "ERROR {}: disabling watchdog timer\r\n", .{result});
        return result;
    }
    puts(" [done]\r\n");


    puts("jumping to kernel...");

    // get the current memory map
    var memory_map: [*]uefi.tables.MemoryDescriptor = undefined;
    var memory_map_size: usize = 0;
    var memory_map_key: usize = undefined;
    var descriptor_size: usize = undefined;
    var descriptor_version: u32 = undefined;

    // Attempt to exit boot services!
    result = uefi.Status.NoResponse;
    while(result != uefi.Status.Success) {
        // Get the memory map
        while (uefi.Status.BufferTooSmall == boot_services.getMemoryMap(&memory_map_size, memory_map, &memory_map_key, &descriptor_size, &descriptor_version)) {
            result = boot_services.allocatePool(uefi.tables.MemoryType.BootServicesData, memory_map_size, @ptrCast(*[*]align(8) u8, &memory_map));
            if (uefi.Status.Success != result) { return result; }
        }

        // Pass the current image's handle and the memory map key to exitBootServices
        // to gain full control over the hardware.
        //
        // exitBootServices may fail. If exitBootServices failed, only getMemoryMap and
        // exitBootservices may be called afterwards. The application may not return
        // anymore after the first call to exitBootServices, even if it was unsuccessful.
        //
        // Most protocols may not be used any more (except for runtime protocols
        // which nobody seems to implement).
        //
        // After exiting boot services, the following fields in the system table should
        // be set to null: ConsoleInHandle, ConIn, ConsoleOutHandle, ConOut,
        // StandardErrorHandle, StdErr, and BootServicesTable. Because the fields are
        // being modified, the table's CRC32 must be recomputed.
        //
        // All events of type event_signal_exit_boot_services will be signaled.
        //
        // Runtime services may be used. However, some restrictions apply. See the
        // UEFI specification for more information.
        result = boot_services.exitBootServices(uefi.handle, memory_map_key);
    }

    // TODO:: jump to kernel here!

    // Set kernel boot info.
    // boot_info.memory_map = memory_map;
    // boot_info.memory_map_size = memory_map_size;
    // boot_info.memory_map_descriptor_size = descriptor_size;

    // Cast pointer to kernel entry.
    // kernel_entry = (void (*)(Kernel_Boot_Info*))*kernel_entry_point;
    // Jump to kernel entry.
    // kernel_entry(&boot_info);

    while (true) {}
    return uefi.Status.LoadError;
}

// implement memcpy as we're not including stdlib
export fn memcpy(dest: [*:0]u8, source: [*:0]const u8, length: u64) [*:0]u8 {
    var index: u64 = 0;
    while (index < length) {
        dest[index] = source[index];
        index += 1;
    }
    return dest;
}

export fn memset (dest: [*:0]u8, value: u8, length: u64) [*:0]u8 {
    var index: u64 = 0;
    while (index < length) {
        dest[index] = value;
        index += 1;
    }
    return dest;
}
