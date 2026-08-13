// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");

const ComponentId = @This();
value: u32,

pub const invalid: ComponentId = .{ .value = std.math.maxInt(u32) };

pub fn eql(a: ComponentId, b: ComponentId) bool {
    return a.value == b.value;
}

pub const FieldType = enum {
    bool,
    i32,
    i64,
    f32,
    f64,
    str
};

pub const FieldDesc = struct {
    name: []const u8,
    type: FieldType,
    len: u32 = 1,
    offset: u32 = 0,

    pub fn elemSize(self: FieldDesc) u32 {
        return switch (self.type) {
            .bool, .str => 1,
            .i32, .f32 => 4,
            .i64, .f64 => 8,
        };
    }

    pub fn elemAlign(self: FieldDesc) u32 {
        return switch (self.kind) {
            .bool, .str => 1,
            .i32, .f32 => 4,
            .i64, .f64 => 8
        };
    }

    pub fn totalSize(self: FieldDesc) u32 {
        return self.elemSize() * self.len;
    }
};
