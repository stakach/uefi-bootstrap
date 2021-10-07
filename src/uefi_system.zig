// https://uefi.org/sites/default/files/resources/UEFI%20Spec%202_6.pdf

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


// -------------
// CONSOLE INPUT
// -------------

const EfiInputKey = extern struct {
    scan_code: u16,
    unicode_char: u16,
};

const EfiSimpleTextInputProtocol = extern struct {
    reset: fn (self: *EfiSimpleTextInputProtocol, extended_verification: bool) callconv(.C) u64,
    read_key_stroke: fn (self: *EfiSimpleTextInputProtocol, key: *EfiInputKey) callconv(.C) u64,
    wait_for_key: fn () callconv(.C) ?*c_void,
};


// --------------
// CONSOLE OUTPUT
// --------------

const EfiSimpleTextOutputMode = extern struct {
    max_mode: i32,
    mode: i32,
    attribute: i32,
    cursor_column: i32,
    cursor_row: i32,
    cursor_visible: bool,
};


const EfiSimpleTextOutputProtocol = extern struct {
    _reset: fn (self: *EfiSimpleTextOutputProtocol, extended_verification: bool) callconv(.C) u64,
    _output_string: fn (self: *EfiSimpleTextOutputProtocol, string: [*:0]const u16) callconv(.C) u64,
    test_string: fn (self: *EfiSimpleTextOutputProtocol, string: [*:0]const u16) callconv(.C) u64,
    query_mode: fn (
        self: *EfiSimpleTextOutputProtocol,
        mode_number: u64,
        columns: [*:0]const u64,
        rows: [*:0]const u64
    ) callconv(.C) u64,
    set_mode: fn (self: *EfiSimpleTextOutputProtocol, mode_number: u64) callconv(.C) u64,
    set_attribute: fn (self: *EfiSimpleTextOutputProtocol, attribute: u64) callconv(.C) u64,
    _clear_screen: fn (self: *EfiSimpleTextOutputProtocol) callconv(.C) u64,
    _set_cursor_position: fn (
        self: *EfiSimpleTextOutputProtocol,
        column: u64,
        row: u64
    ) callconv(.C) u64,
    _enable_cursor: fn (self: *EfiSimpleTextOutputProtocol, visible: bool) callconv(.C) u64,
    mode: *EfiSimpleTextOutputMode,

    fn reset(self: *EfiSimpleTextOutputProtocol, extended_verification: bool) u64 {
        return self._reset(self, extended_verification);
    }

    fn output_string(self: *EfiSimpleTextOutputProtocol, string: [*:0]const u16) u64 {
        return self._output_string(self, string);
    }

    fn clear_screen(self: *EfiSimpleTextOutputProtocol) u64 {
        return self._clear_screen(self);
    }

    fn enable_cursor(self: *EfiSimpleTextOutputProtocol, visible: bool) u64 {
        return self._enable_cursor(self, visible);
    }

    fn set_cursor_position(self: *EfiSimpleTextOutputProtocol, column: u64, row: u64) u64 {
        return self._set_cursor_position(self, column, row);
    }
};


// ----------------
// Runtime Services
// ----------------

const EfiMemoryDescriptor = extern struct {
    type: u32,
    physical_start: u64,
    virtual_start: u64,
    number_of_pages: u64,
    attribute: u64,
};

const EfiResetType = enum(c_int) { cold, warm, shutdown, platform_specific, n };

const EfiCapsuleHeader = extern struct {
    capsule_guid: EfiGUID,
    header_size: u32,
    flags: u32,
    capsule_image_size: u32,
};

const EfiRuntimeServices = extern struct {
    header: EfiTableHeader,
    get_time: fn (time: *EfiTime, capabilities: *EfiTimeCapabilities) callconv(.C) u64,
    set_time: fn (time: *EfiTime) callconv(.C) u64,
    get_wakeup_time: fn (enabled: *bool, pending: *bool, time: *EfiTime) callconv(.C) u64,
    set_wakeup_time: fn (enabled: *bool, time: *EfiTime) callconv(.C) u64,
    set_virtual_address_map: fn (
        memory_map_size: u64,
        descriptor_size: u64,
        descriptor_version: u32,
        virtual_map: *EfiMemoryDescriptor
    ) callconv(.C) u64,
    convert_pointer: fn (debug_disposition: u64, address: *?*c_void) callconv(.C) u64,
    // note:: expects utf16 characters
    get_variable: fn (
        variable_name: [*:0]const u8,
        vendor_guid: *EfiGUID,
        attributes: *u32,
        data_size: *u64,
        data: ?*c_void
    ) callconv(.C) u64,
    get_next_variable_name: fn (
        variable_name_size: *u64,
        variable_name: *u16,
        vendor_guid: *EfiGUID
    ) callconv(.C) u64,
    set_variable: fn (
        // utf16 characters
        variable_name: [*:0]const u8,
        vendor_guid: *EfiGUID,
        attributes: u32,
        data_size: u64,
        data: ?*c_void
    ) callconv(.C) u64,
    get_next_high_mono_count: fn (high_count: *u32) callconv(.C) u64,
    reset_system: fn (
        reset_type: EfiResetType,
        reset_status: u64,
        data_size: u64,
        reset_data: ?*c_void
    ) callconv(.C) void,
    update_capsule: fn (
        capsule_header_array: **EfiCapsuleHeader,
        capsule_count: u64,
        scatter_gather_list: u64
    ) callconv(.C) u64,
    query_capsule_capabilities: fn (
        capsule_header_array: **EfiCapsuleHeader,
        capsule_count: u64,
        maximum_capsule_size: *u64,
        reset_type: *EfiResetType
    ) callconv(.C) u64,
    query_variable_info: fn (
        attributes: u32,
        maximum_variable_storage_size: *u64,
        remaining_variable_storage_size: *u64,
        maximum_variable_size: *u64
    ) callconv(.C) u64,
};


// -------------
// Boot Services
// -------------

const EfiAllocateType = enum(c_int) { any_pages, max_address, address, type_n };
const EfiMemoryType = enum(c_int) {
    reserved_memory,
    loader_code,
    loader_data,
    boot_services_code,
    boot_services_data,
    runtime_services_code,
    runtime_services_data,
    conventional_memory,
    unusable_memory,
    acpi_reclaim_memory,
    acpi_memory_nvs,
    memory_mapped_io,
    memory_mapped_io_port_space,
    pal_code,
    persistent_memory,
    memory_type_n
};
const EfiTimerDelay = enum(c_int) { cancel, periodic, relative };
const EfiInterfaceType = enum(c_int) { native_interface };
const EfiLocateSearchType = enum(c_int) { all_handles, by_register_notify, by_protocol };

const EfiDevicePathProtocol = extern struct {
    type: u8,
    subtype: u8,
    // account for little endianness
    length_low: u8,
    length_high: u8
};

const EfiDevicePathNull = EfiDevicePathProtocol{ .x = 0x7f, .y = 0xff, .length_low = 4, .length_high = 0 };

const EfiBootServices = extern struct {
    header: EfiTableHeader,
    raise_tpl: fn (new_tpl: u64) callconv(.C) u64,
    restore_tpl: fn (old_tpl: u64) callconv(.C) void,
    allocate_pages: fn (
        type: EfiAllocateType,
        memory_type: EfiMemoryType,
        pages: u64,
        memory: *u64
    ) callconv(.C) u64,
    free_pages: fn (memory: u64, pages: u64) callconv(.C) u64,
    get_memory_map: fn (
        memory_map_size: *u64,
        memory_map: *EfiMemoryDescriptor,
        map_key: *u64,
        descriptor_size: *u64,
        descriptor_version: *u32
    ) callconv(.C) u64,
    allocate_pool: fn (
        pool_type: EfiMemoryType,
        size: u64,
        buffer: *?*c_void
    ) callconv(.C) u64,
    free_pool: fn (buffer: ?*c_void) callconv(.C) u64,
    create_event: fn (
        type: u32,
        notify_tpl: u64,
        notify_function: *fn (event: ?*c_void, context: ?*c_void) callconv(.C) void,
        notify_context: ?*c_void,
        event: ?*c_void
    ) callconv(.C) u64,
    set_timer: fn (
        event: ?*c_void,
        type: EfiTimerDelay,
        trigger_time: u64
    ) callconv(.C) u64,
    wait_for_event: fn (
        number_of_events: u64,
        event: ?*c_void,
        index: *u64
    ) callconv(.C) u64,
    signal_event: fn (event: ?*c_void) callconv(.C) u64,
    close_event: fn (event: ?*c_void) callconv(.C) u64,
    check_event: fn (event: ?*c_void) callconv(.C) u64,
    install_protocol_interface: fn (
        handle: ?*c_void,
        protocol: *EfiGUID,
        interface_type: EfiInterfaceType,
        interface: ?*c_void
    ) callconv(.C) u64,
    reinstall_protocol_interface: fn (
        handle: ?*c_void,
        protocol: *EfiGUID,
        old_interface: ?*c_void,
        new_interface: ?*c_void
    ) callconv(.C) u64,
    uninstall_protocol_interface: fn (
        handle: ?*c_void,
        protocol: *EfiGUID,
        interface: ?*c_void
    ) callconv(.C) u64,
    handle_protocol: fn (
        handle: ?*c_void,
        protocol: *EfiGUID,
        interface: *?*c_void
    ) callconv(.C) u64,
    reserved: ?*c_void,
    register_protocol_notify: fn (
        protocol: *EfiGUID,
        event: ?*c_void,
        registration: *?*c_void
    ) callconv(.C) u64,
    locate_handle: fn (
        search_type: EfiLocateSearchType,
        protocol: *EfiGUID,
        search_key: ?*c_void,
        buffer_size: *u64,
        buffer: ?*c_void
    ) callconv(.C) u64,
    locate_device_path: fn (
        protocol: *EfiGUID,
        device_path: **EfiDevicePathProtocol,
        device: ?*c_void
    ) callconv(.C) u64,
};


// --------------
// Configuration Tables
// --------------
// The system table contains an array of auxiliary tables, indexed by their
// GUID, called configuration tables. Each table uses the generic
// EfiConfigurationTable structure as header.

const EfiGUID = extern struct {
    guid: u128 align(64),
};

const EfiConfigurationTable = extern struct {
    vendor_guid: EfiGUID,
    // pointer to a buffer
    vendor_table: ?*c_void
};


// --------------
// Primary system
// --------------

const EfiSystemTable = extern struct {
    header: EfiTableHeader,
    firmware_vendor: [*:0]const u8,
    firmware_revision: u32,
    standard_in_handle: u64,
    standard_in: *EfiSimpleTextInputProtocol,
    standard_out_handle: u64,
    standard_out: *EfiSimpleTextOutputProtocol,
    standard_error_handle: u64,
    standard_error: *EfiSimpleTextOutputProtocol,

    runtime_services: *EfiRuntimeServices,
    boot_services: *EfiBootServices,
    number_of_table_entries: i64,
    configuration_table: *EfiConfigurationTable,
};

export fn efi_main(handle: u64, system_table: EfiSystemTable) callconv(.C) u64 {
    const console_in = system_table.standard_in;
    const console_out = system_table.standard_out;
    const boot_services = system_table.boot_services;
    var index: u64 = 0;
    // console_out.output_string(system_table.standard_out, "H\x00e\x00l\x00l\x00o\x00 \x00W\x00o\x00r\x00l\x00d\x00!\x00\n\x00\x00\x00");

    // Clear screen. reset() returns usize(0) on success, like most
    // EFI functions. reset() can also return something else in case a
    // device error occurs, but we're going to ignore this possibility now.
    _ = console_out.clear_screen();

    // EFI uses UCS-2 encoded null-terminated strings. UCS-2 encodes
    // code points in exactly 16 bit. Unlike UTF-16, it does not support all
    // Unicode code points.
    _ = console_out.output_string(&[_:0]u16{ 'H', 'e', 'l', 'l', 'o', ',', ' ' });
    _ = console_out.output_string(&[_:0]u16{ 'w', 'o', 'r', 'l', 'd', '\r', '\n' });

    _ = boot_services.wait_for_event(1, &console_in.wait_for_key, &index);

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
