// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const log = @import("../log.zig").lua;
const Lua = zlua.Lua;

pub fn setObjectMetatable(l: *Lua) void {
    l.setMetatableRegistry("Object");
}

// Dumps the stack to the terminal
pub fn dumpStack(l: *Lua) void {
    const top = l.getTop();

    log.info("----- Lua stack ({d}) -----", .{ top });

    var i: i32 = top;
    while (i >= 1) : (i -= 1) {
        const t = l.typeOf(i);
        const rel_idx = i - (top + 1);
        const type_name = l.typeNameIndex(i);

        switch (t) {
            .string => log.info("[{d} / {d}] {s} '{s}'", .{ i, rel_idx, type_name, l.toString(i) catch "" }),
            .boolean => log.info("[{d} / {d}] {s} {}", .{ i, rel_idx, type_name, l.toBoolean(i) }),
            .number => log.info("[{d} / {d}] {s} {d}", .{ i, rel_idx, type_name, l.toNumber(i) catch 0 }),
            .table => log.info("[{d} / {d}] {s} table: {*}", .{ i, rel_idx, type_name, l.toPointer(i) }),
            .userdata => log.info("[{d} / {d}] {s} userdata({*})", .{ i, rel_idx, type_name, l.toPointer(i) }),
            else => log.info("[{d} / {d}] {s} {s}", .{ i, rel_idx, type_name, l.typeName(t) }),
        }
    }

    log.info("-----------------------------", .{});
}
