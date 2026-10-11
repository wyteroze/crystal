// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub fn pascal(comptime s: []const u8) [:0]const u8 { comptime {
    var out: [s.len:0]u8 = undefined;

    var n: usize = 0;
    var up = true;
    for (s) |c| {
        if (c == '_') { up = true; continue; }
        out[n] = if (up) std.ascii.toUpper(c) else c;
        up = false;
        n += 1;
    }

    out[n] = 0;
    const final = out;
    return final[0..n :0];
} }

pub fn shortTypeName(comptime T: type) [:0]const u8 {
    const full = @typeName(T);
    const start = if (std.mem.lastIndexOfScalar(u8, full, '.')) |i| i + 1 else 0;

    return full[start..];
}
