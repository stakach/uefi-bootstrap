const uefi = @import("std").os.uefi;
const fmt = @import("std").fmt;

pub var out: *uefi.protocols.SimpleTextOutputProtocol = undefined;


// EFI uses UCS-2 encoded null-terminated strings. UCS-2 encodes
// code points in exactly 16 bit. Unlike UTF-16, it does not support all
// Unicode code points.
// We need to print each character in an [_]u8 individually because EFI
// encodes strings as UCS-2.
pub fn puts(msg: []const u8) void {
    for (msg) |c| {
        const c_ = [2]u16{ c, 0 }; // work around https://github.com/ziglang/zig/issues/4372
        _ = out.outputString(@ptrCast(*const [1:0]u16, &c_));
    }
}

pub fn printf(buf: []u8, comptime format: []const u8, args: anytype) void {
    puts(fmt.bufPrint(buf, format, args) catch unreachable);
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
