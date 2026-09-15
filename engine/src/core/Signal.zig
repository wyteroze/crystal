// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub fn SignalConnection(comptime SignalType: type) type {
    return struct {
        const Self = @This();

        signal: *SignalType,
        id: usize,

        pub fn disconnect(self: Self) void {
            self.signal.disconnect(self.id) catch |e| {
                std.log.err("Failed to disconnect callback: {s}", .{@errorName(e)});
            };
        }

        pub const __lua = .val;
    };
}


pub fn Signal(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Callback = *const fn (T) void;

        allocator: std.mem.Allocator,
        callbacks: std.AutoHashMap(usize, Callback),
        next_id: usize = 0,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .callbacks = .init(allocator)
            };
        }

        pub fn deinit(self: *Self) void {
            self.callbacks.deinit();
        }

        pub fn fire(self: *Self, value: T) void {
            var iter = self.callbacks.valueIterator();
            while (iter.next()) |cb| cb.*(value);
        }

        pub fn connect(self: *Self, callback: Callback) !SignalConnection(Self) {
            const id = self.next_id;
            self.next_id += 1;

            try self.callbacks.put(id, callback);
            return .{ .signal = self, .id = id };
        }

        pub fn disconnect(self: *Self, id: usize) !void {
            if (!self.callbacks.remove(id)) return error.NoSuchCallback;
        }

        pub const __lua = .val;
    };
}
