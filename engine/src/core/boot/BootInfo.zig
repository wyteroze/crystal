// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Boot = @This();
package_id: []u8,
payload_offset: u64,
payload_len: usize,

const boot_magic: u32 = std.mem.readInt(u32, "CRYB", .big);

pub fn resolveBootInfo(io: std.Io, allocator: std.mem.Allocator) !?Boot {
    const exe_path = try std.process.executablePathAlloc(io, allocator);
    defer allocator.free(exe_path);

    if (readBootInfo(io, exe_path) catch null) |info| return info;

    const dir = std.Io.Dir.path.dirname(exe_path) orelse ".";
    const pack_path = try std.Io.Dir.path.join(allocator, &.{ dir, "game.crypak" });
    defer allocator.free(pack_path);

    if (readBootInfo(io, pack_path) catch null) |info| return info;
    return null;
}

fn readBootInfo(io: std.Io, exe_path: []const u8) !?Boot {
    var file = try std.Io.Dir.openFileAbsolute(io, exe_path, .{});
    defer file.close(io);

    const stat = try file.stat(io);

    const file_size = stat.size;
    const footer_size = 256 + 8 + 4;
    if (file_size < footer_size) return null;

    var buf: [footer_size]u8 = undefined;
    _ = try file.readPositionalAll(io, &buf, file_size-footer_size);

    const magic = std.mem.readInt(u32, buf[264..268], .little);
    if (magic != boot_magic) return null;

    const payload_len = std.mem.readInt(u64, buf[256..264], .little);
    const pkg_slice = std.mem.sliceTo(buf[0..256], 0);

    var boot: Boot = undefined;
    @memcpy(boot.package_id[0..pkg_slice.len], pkg_slice);
    boot.payload_len = payload_len;
    boot.payload_offset = file_size - footer_size - payload_len;

    return boot;
}