// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

pub const KeyboardDevice = @import("KeyboardDevice.zig");
pub const MouseDevice = @import("MouseDevice.zig");
pub const GamepadDevice = @import("GamepadDevice.zig");
pub const TouchDevice = @import("TouchDevice.zig");

pub fn DeviceHandle(comptime D: type, comptime map_field: []const u8) type {
    return struct {
        const std = @import("std");
        const Input = @import("../Input.zig");

        const Self = @This();
        input: *Input,
        id: usize,

        pub fn get(self: Self) ?*D {
            return @field(self.input, map_field).get(self.id);
        }
        pub fn require(self: Self) !*D {
            return self.get() orelse error.DeviceDisconnected;
        }
        pub fn isAlive(self: Self) bool {
            return self.get() != null;
        }
        pub fn eql(a: Self, b: Self) bool {
            return a.input == b.input and a.id == b.id;
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            const device = self.require() catch return writer.print("<invalid handle>", .{});
            try writer.print("{f}", .{ device });
        }
    };
}