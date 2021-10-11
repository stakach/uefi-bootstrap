const uefi = @import("std").os.uefi;
const fmt = @import("std").fmt;

// https://github.com/ziglang/zig/blob/master/lib/std/os/uefi/protocols/simple_text_output_protocol.zig

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

// For use with formatting strings
var printf_buf: [100]u8 = undefined;

pub fn printf(comptime format: []const u8, args: anytype) void {
    buf_printf(printf_buf[0..], format, args);
}

pub fn buf_printf(buf: []u8, comptime format: []const u8, args: anytype) void {
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

// This is here for testing video buffer memory after calling exitBootServices
// https://forum.osdev.org/viewtopic.php?f=1&t=26796
pub fn draw_triangle(arg_lfb_base_addr: u64, arg_center_x: u64, arg_center_y: u64, arg_width: u64, arg_color: u32) void {
    var lfb_base_addr = arg_lfb_base_addr;
    var center_x = arg_center_x;
    var center_y = arg_center_y;
    var width = arg_width;
    var color = arg_color;
    var at: [*c]u32 = @intToPtr([*c]u32, lfb_base_addr);
    var row: u64 = undefined;
    var col: u64 = undefined;
    at += (1024 *% (center_y -% width / 2) +% center_x -% width / 2);
    {
        row = 0;
        while (row < (width / 2)) : (row +%= 1) {
            {
                col = 0;
                while (col < (width -% (row *% 2))) : (col +%= 1) {
                    (blk: {
                        const ref = &at;
                        const tmp = ref.*;
                        ref.* += 1;
                        break :blk tmp;
                    }).?.* = color;
                }
            }
            at += 1024 -% col;
            {
                col = 0;
                while (col < (width -% (row *% 2))) : (col +%= 1) {
                    (blk: {
                        const ref = &at;
                        const tmp = ref.*;
                        ref.* += 1;
                        break :blk tmp;
                    }).?.* = color;
                }
            }
            at += (1024 -% col) +% 1;
        }
    }
}
