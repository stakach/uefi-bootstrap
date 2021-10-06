
const EfiTime = extern struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,
    pad1: u8,
    nanosecond: u32,
    timezone: i16,
    daylight: u8,
    pad2: u8,
};

const EfiTimeCapabilities = extern struct {
    resolution: u32,
    accuracy: u32,
    sets_to_zero: bool,
};

const EfiTableHeader = extern struct {
    signature: u64,
    revision: u32,
    header_size: u32,
    crc32: u32,
    reserved: u32,
};

// ------
// CONSOLE INPUT
// ------
const EfiInputKey = extern struct {
    scan_code: u16,
    unicode_char: u16,
};

const EfiSimpleTextInputProtocol = extern struct {
    reset: fn (self: *EfiSimpleTextInputProtocol, extended_verification: bool) callconv(.C) u64,
    read_key_stroke: fn (self: *EfiSimpleTextInputProtocol, key: *EfiInputKey) callconv(.C) u64,
    wait_for_key: fn () callconv(.C) u64, // technically returns a *void
};

// ------
// CONSOLE OUTPUT
// ------
const EfiSimpleTextOutputMode = extern struct {
    max_mode: i32,
    mode: i32,
    attribute: i32,
    cursor_column: i32,
    cursor_row: i32,
    cursor_visible: bool,
};


const EfiSimpleTextOutputProtocol = extern struct {
    reset: fn (self: *EfiSimpleTextOutputProtocol, extended_verification: bool) callconv(.C) u64,
    output_string: fn (self: *EfiSimpleTextOutputProtocol, string: [*:0]const u8) callconv(.C) u64,

    test_string: fn (self: *EfiSimpleTextOutputProtocol, string: [*:0]const u8) callconv(.C) u64,
    query_mode: fn (self: *EfiSimpleTextOutputProtocol, string: [*:0]const u8) callconv(.C) u64,
    set_mode: fn (self: *EfiSimpleTextOutputProtocol, string: [*:0]const u8) callconv(.C) u64,
    set_attribute: fn (self: *EfiSimpleTextOutputProtocol, string: [*:0]const u8) callconv(.C) u64,
    clear_screen: fn (self: *EfiSimpleTextOutputProtocol, string: [*:0]const u8) callconv(.C) u64,
    set_cursor_position: fn (self: *EfiSimpleTextOutputProtocol, string: [*:0]const u8) callconv(.C) u64,
    enable_cursor: fn (self: *EfiSimpleTextOutputProtocol, string: [*:0]const u8) callconv(.C) u64,
    mode: *EfiSimpleTextOutputMode,
};

const EfiSystemTable = extern struct {
    hdr: EfiTableHeader,
    firmware_vendor: [*:0]const u8,
    firmware_revision: u32,
    standard_in_handle: u64,
    standard_in: *EfiSimpleTextInputProtocol,
    standard_out_handle: u64,
    standard_out: *EfiSimpleTextOutputProtocol,
    standard_error_handle: u64,
    standard_error: *EfiSimpleTextOutputProtocol,

    //runtime_services:
};

export fn efi_main(handle: u64, system_table: EfiSystemTable) callconv(.C) u64 {
    _ = system_table.standard_out.output_string(system_table.standard_out, "H\x00e\x00l\x00l\x00o\x00 \x00W\x00o\x00r\x00l\x00d\x00!\x00\n\x00\x00\x00");
    while(true){
        asm volatile("nop");
    }
    return 0;
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
