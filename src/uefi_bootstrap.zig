// https://uefi.org/sites/default/files/resources/UEFI%20Spec%202_6.pdf
// https://github.com/ziglang/zig/blob/master/lib/std/os/uefi/
// https://github.com/nrdmn/uefi-examples/
// https://www.programmersought.com/article/77814539630/
// https://github.com/ajxs/uefi-elf-bootloader

const uefi = @import("std").os.uefi;
const fmt = @import("std").fmt;
const console = @import("./console.zig");
const load_kernel_image = @import("./loader.zig").load_kernel_image;

export fn efi_main(handle: u64, system_table: uefi.tables.SystemTable) callconv(.C) uefi.Status {
    console.out = system_table.con_out.?;
    const console_in = system_table.con_in.?;
    const boot_services = system_table.boot_services.?;

    // For use with formatting strings
    var printf_buf: [100]u8 = undefined;

    // Clear screen. reset() returns usize(0) on success
    var result = console.out.clearScreen();
    if (uefi.Status.Success != result) { return result; }

    // obtain access to the file system
    console.puts("initialising File System service...");
    var simple_file_system: ?*uefi.protocols.SimpleFileSystemProtocol = undefined;
    result = boot_services.locateProtocol(&uefi.protocols.SimpleFileSystemProtocol.guid, null, @ptrCast(*?*c_void, &simple_file_system));
    if (result != uefi.Status.Success) {
        console.puts(" [failed]\r\n");
        console.printf(printf_buf[0..], "ERROR {}: initialising file system\r\n", .{result});
        return result;
    }

    // Grab a handle to the FS volume
    var root_file_system: *uefi.protocols.FileProtocol = undefined;
    result = simple_file_system.?.openVolume(&root_file_system);
    if (result != uefi.Status.Success) {
        console.puts(" [failed]\r\n");
        console.printf(printf_buf[0..], "ERROR {}: opening file system volume\r\n", .{result});
        return result;
    }
    console.puts(" [done]\r\n");

    // Start moving the kernel image into memory (\kernel.elf)
    console.puts("loading kernel...\r\n");
    result = load_kernel_image(boot_services, root_file_system, &[_:0]u16{ '\\', 'k', 'e', 'r', 'n', 'e', 'l', '.', 'e', 'l', 'f' });
    if (result != uefi.Status.Success) {
        console.puts(" [failed]\r\n");
        console.printf(printf_buf[0..], "ERROR {}: loading kernel\r\n", .{result});
        return result;
    }
    console.puts("loading kernel... [done]\r\n");

    // prevent system reboot if we don't check-in
    console.puts("disabling watchdog timer...");
    result = boot_services.setWatchdogTimer(0, 0, 0, null);
    if (result != uefi.Status.Success) {
        console.puts(" [failed]\r\n");
        console.printf(printf_buf[0..], "ERROR {}: disabling watchdog timer\r\n", .{result});
        return result;
    }
    console.puts(" [done]\r\n");


    console.puts("jumping to kernel...");

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
