// https://uefi.org/sites/default/files/resources/UEFI%20Spec%202_6.pdf
// https://github.com/ziglang/zig/blob/master/lib/std/os/uefi/
// https://github.com/nrdmn/uefi-examples/
// https://www.programmersought.com/article/77814539630/
// https://github.com/ajxs/uefi-elf-bootloader

const uefi = @import("std").os.uefi;
const fmt = @import("std").fmt;
const console = @import("./console.zig");
const load_kernel_image = @import("./loader.zig").load_kernel_image;

pub var boot_services: *uefi.tables.BootServices = undefined;

export fn efi_main(handle: u64, system_table: uefi.tables.SystemTable) callconv(.C) uefi.Status {
    console.out = system_table.con_out.?;
    boot_services = system_table.boot_services.?;

    console.puts("bootloader started\r\n");

    // Clear screen. reset() returns usize(0) on success
    var result = console.out.clearScreen();
    if (uefi.Status.Success != result) { return result; }

    console.puts("configuring graphics mode...\r\n");

    // Graphics output?
    var graphics_output_protocol: ?*uefi.protocols.GraphicsOutputProtocol = undefined;
    if (boot_services.locateProtocol(&uefi.protocols.GraphicsOutputProtocol.guid, null, @ptrCast(*?*c_void, &graphics_output_protocol)) == uefi.Status.Success) {
        // Check supported resolutions:
        var i: u32 = 0;
        while (i < graphics_output_protocol.?.mode.max_mode) : (i += 1) {
            var info: *uefi.protocols.GraphicsOutputModeInformation = undefined;
            var info_size: usize = undefined;
            _ = graphics_output_protocol.?.queryMode(i, &info_size, &info);
            console.printf("    mode {} = {}x{} format: {}\r\n", .{ i, info.horizontal_resolution, info.vertical_resolution, info.pixel_format });
        }

        console.printf("    current mode = {}\r\n", .{graphics_output_protocol.?.mode.mode});

        // TODO:: search for compatible mode and set 1024x768? or make triangles resolution independent
        //_ = graphics_output_protocol.?.setMode(2);
    } else {
        console.puts("[error] unable to configure graphics mode\r\n");
    }

    // obtain access to the file system
    console.puts("initialising File System service...");
    var simple_file_system: ?*uefi.protocols.SimpleFileSystemProtocol = undefined;
    result = boot_services.locateProtocol(&uefi.protocols.SimpleFileSystemProtocol.guid, null, @ptrCast(*?*c_void, &simple_file_system));
    if (result != uefi.Status.Success) {
        console.puts(" [failed]\r\n");
        console.printf("ERROR {}: initialising file system\r\n", .{result});
        return result;
    }

    // Grab a handle to the FS volume
    var root_file_system: *uefi.protocols.FileProtocol = undefined;
    result = simple_file_system.?.openVolume(&root_file_system);
    if (result != uefi.Status.Success) {
        console.puts(" [failed]\r\n");
        console.printf("ERROR {}: opening file system volume\r\n", .{result});
        return result;
    }
    console.puts(" [done]\r\n");

    // Start moving the kernel image into memory (\kernel.elf)
    console.puts("loading kernel...\r\n");
    var entry_point: u64 = 0;
    result = load_kernel_image(
        root_file_system,
        &[_:0]u16{ '\\', 'k', 'e', 'r', 'n', 'e', 'l', '.', 'e', 'l', 'f' },
        &entry_point
    );
    if (result != uefi.Status.Success) {
        console.puts(" [failed]\r\n");
        console.printf("ERROR {}: loading kernel\r\n", .{result});
        return result;
    }
    console.puts("loading kernel... [done]\r\n");

    // prevent system reboot if we don't check-in
    console.puts("disabling watchdog timer...");
    result = boot_services.setWatchdogTimer(0, 0, 0, null);
    if (result != uefi.Status.Success) {
        console.puts(" [failed]\r\n");
        console.printf("ERROR {}: disabling watchdog timer\r\n", .{result});
        return result;
    }
    console.puts(" [done]\r\n");
    console.printf("graphics buffer@{}\r\n", .{graphics_output_protocol.?.mode.frame_buffer_base});
    console.printf("jumping to kernel... @{}\r\n", .{entry_point});

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
        result = boot_services.exitBootServices(uefi.handle, memory_map_key);
    }

    // Set kernel boot info.
    var boot_info = BootInfo{
        .video_buff = graphics_output_protocol.?.mode,
        .memory_map = memory_map,
        .memory_map_size = memory_map_size,
        .memory_map_descriptor_size = descriptor_size,
    };

    // This shows that the boot info is working (accessing video buffer after exitBootServices)
    console.draw_triangle(boot_info.video_buff.frame_buffer_base, 1024 / 2, 768 / 3 - 25, 100, 0x00119911);

    // Put the boot information in a pre-determined location
    var boot_info_ptr: *u64 = @intToPtr(*u64, 0x100000);

    // Cast pointer to kernel entry.
    // Jump to kernel entry.
    boot_info_ptr.* = @ptrToInt(&boot_info);
    @intToPtr(fn() callconv(.C) void, entry_point)();

    // Should never make it here
    return uefi.Status.LoadError;
}

const BootInfo = extern struct {
    video_buff: *uefi.protocols.GraphicsOutputProtocolMode,
    memory_map: [*]uefi.tables.MemoryDescriptor,
    memory_map_size: u64,
    memory_map_descriptor_size: u64,
};
