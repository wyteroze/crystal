// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const SizeFormatter = @This();
bytes: usize,

pub fn format(self: SizeFormatter, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    const units = [_][]const u8{ "B", "KB", "MB", "GB", "TB" };
    var value: f64 = @floatFromInt(self.bytes);
    var unit_index: usize = 0;
    while (value >= 1024.0 and unit_index < units.len - 1) {
        value /= 1024.0;
        unit_index += 1;
    }
    if (unit_index == 0) {
        try writer.print("{d}{s}", .{ self.bytes, units[unit_index] });
    } else {
        try writer.print("{d:.2}{s}", .{ value, units[unit_index] });
    }
}

pub fn fmtSize(bytes: usize) SizeFormatter {
    return .{ .bytes = bytes };
}