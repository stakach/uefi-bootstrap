const uefi = @import("std").os.uefi;
const elf = @import("std").elf;
const console = @import("./console.zig");
const bootstrap = @import("./uefi_bootstrap.zig");

// Docs: https://github.com/ziglang/zig/blob/master/lib/std/elf.zig
// https://github.com/ziglang/zig/blob/master/lib/std/os/uefi/protocols/file_protocol.zig

pub fn load_kernel_image(
    file_system: *uefi.protocols.FileProtocol,
    file_path: [*:0]const u16,
    base_physical_address: u64,
    kernel_entry_point: *u64,
    kernel_start_address: *u64,
) uefi.Status {
    var kernel_img_file: *uefi.protocols.FileProtocol = undefined;
    var result = file_system.open(&kernel_img_file, file_path, uefi.protocols.FileProtocol.efi_file_mode_read, uefi.protocols.FileProtocol.efi_file_read_only);
    if (result != uefi.Status.Success) { return result; }

    console.puts("  -> file found, validating identity...");

    // load enough bytes to idenitfy the file (EI_NIDENT)
    var header_buffer: [*]align(8) u8 = undefined;
    result = read_and_allocate(kernel_img_file, 0, elf.EI_NIDENT, &header_buffer);
    if (result != uefi.Status.Success) { return result; }

    // check magic header is an elf file
    if((header_buffer[0] != 0x7F) or
        (header_buffer[1] != 0x45) or
        (header_buffer[2] != 0x4C) or
        (header_buffer[3] != 0x46)) {
        return uefi.Status.InvalidParameter;
    }

    // check we're loading a 64 bit little-endian binary
    if(header_buffer[elf.EI_CLASS] != elf.ELFCLASS64) { return uefi.Status.Unsupported; }
    if(header_buffer[elf.EI_DATA] != elf.ELFDATA2LSB) { return uefi.Status.IncompatibleVersion; }

    // free the identity buffer
    result = bootstrap.boot_services.freePool(header_buffer);
    if (result != uefi.Status.Success) { return result; }
    console.puts(" [done]\r\n");

    // Load the elf header
    console.puts("  -> loading elf header...");
    result = read_and_allocate(kernel_img_file, 0, @sizeOf(elf.Elf64_Ehdr), &header_buffer);
    if (result != uefi.Status.Success) { return result; }
    var header = elf.Header.parse(header_buffer[0..64]) catch |err| {
        switch(err) {
            error.InvalidElfMagic => {
                return uefi.Status.InvalidParameter;
            },
            error.InvalidElfVersion => {
                return uefi.Status.IncompatibleVersion;
            },
            error.InvalidElfEndian => {
                return uefi.Status.IncompatibleVersion;
            },
            error.InvalidElfClass => {
                return uefi.Status.Unsupported;
            }
        }
    };
    console.puts(" [done]\r\n");
    console.printf("  -> found entry point @{}\r\n", .{header.entry});
    kernel_entry_point.* = header.entry;

    // load the program headers
    console.puts("  -> loading program headers...");
    var program_headers_buffer: [*]align(8) u8 = undefined;
    result = read_and_allocate(kernel_img_file, header.phoff, header.phentsize * header.phnum, &program_headers_buffer);
    if (result != uefi.Status.Success) { return result; }

    const program_headers = @ptrCast([*]const elf.Elf64_Phdr, program_headers_buffer);
    console.puts(" [done]\r\n");

    result = load_program_segments(kernel_img_file, &header, program_headers, base_physical_address, kernel_start_address);
    if (result != uefi.Status.Success) { return result; }

    // free temporary buffers
    _ = kernel_img_file.close();
    _ = bootstrap.boot_services.freePool(header_buffer);
    _ = bootstrap.boot_services.freePool(program_headers_buffer);

    return uefi.Status.Success;
}

fn read_file(file: *uefi.protocols.FileProtocol, position: u64, size: usize, buffer: *[*]align(8) u8) uefi.Status {
    var result = file.setPosition(position);
    if (result != uefi.Status.Success) { return result; }

    return file.read(&@ptrCast(usize, size), buffer.*);
}

fn read_and_allocate(file: *uefi.protocols.FileProtocol, position: u64, size: usize, buffer: *[*]align(8) u8) uefi.Status {
    var result = bootstrap.boot_services.allocatePool(uefi.tables.MemoryType.LoaderData, size, buffer);
    if (result != uefi.Status.Success) { return result; }

    return read_file(file, position, size, buffer);
}

fn load_program_segments(
    file: *uefi.protocols.FileProtocol,
    header: *elf.Header,
    program_headers: [*]const elf.Elf64_Phdr,
    base_physical_address: u64,
    kernel_start_address: *u64,
) uefi.Status {
    const length = header.phnum;

    if (length == 0) {
        console.puts("  -> no program segments found!");
        return uefi.Status.InvalidParameter;
    }

    console.printf("  -> loading {} program segments: ", .{length});
    var result = uefi.Status.Success;
    var loaded: u64 = 0;
    var index: u64 = 0;
    var set_start_address: bool = true;
    var base_address_difference: u64 = 0;

    while (index < length) {
        if (program_headers[index].p_type == elf.PT_LOAD) {
            console.printf("[{}", .{index});

            if (set_start_address) {
                set_start_address = false;
                kernel_start_address.* = program_headers[index].p_vaddr;
                // calculate the difference between virtual and physical addresses
                // we'll enable virtual addressing before jumping to the kernel
                base_address_difference = program_headers[index].p_vaddr - base_physical_address;
            }

            result = load_segment(
                file,
                program_headers[index].p_offset,
                program_headers[index].p_filesz,
                program_headers[index].p_memsz,
                program_headers[index].p_vaddr - base_address_difference,
            );
            if (result != uefi.Status.Success) { return result; }
            console.puts("].");

            loaded += 1;
        }
        index += 1;
    }

    if (loaded == 0) { return uefi.Status.NotFound; }
    console.puts("[done]\r\n");
    return result;
}

fn load_segment(
    file: *uefi.protocols.FileProtocol,
    file_offset: elf.Elf64_Off,
    file_size: elf.Elf64_Xword,
    memory_size: elf.Elf64_Xword,
    virtual_address: elf.Elf64_Addr
) uefi.Status {
    var num_pages = size_to_pages(memory_size);
    console.printf("p({})", .{num_pages});
    var seg_buffer: [*]align(4096) u8 = @intToPtr([*]align(4096) u8, virtual_address);
    var result = bootstrap.boot_services.allocatePages(uefi.tables.AllocateType.AllocateAddress, uefi.tables.MemoryType.LoaderData, num_pages, &seg_buffer);
    if (result != uefi.Status.Success) { return result; }

    console.printf("a({})", .{virtual_address});

    if(file_size > 0) {
        // load directly into correct position in memory
        console.printf("c({})", .{file_size});
        result = read_file(file, file_offset, file_size, &seg_buffer);
        if (result != uefi.Status.Success) { return result; }
    }

    // As per ELF Standard, if the size in memory is larger than the file size
    // the segment is mandated to be zero filled.
    // For more information on Refer to ELF standard page 34.
    var zero_fill_start = virtual_address + file_size;
    var zero_fill_count = memory_size - file_size;

    if(zero_fill_count > 0) {
        console.printf("0({})", .{zero_fill_count});
        bootstrap.boot_services.setMem(@intToPtr([*]u8, zero_fill_start), zero_fill_count, 0);
    }

    return uefi.Status.Success;
}

fn size_to_pages(bytes: u64) u64 {
    if ((bytes & 0xFFF) > 0) {
        return (bytes >> 12) + 1;
    } else {
        return bytes >> 12;
    }
}
