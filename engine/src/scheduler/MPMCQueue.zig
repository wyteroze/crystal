// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub fn MPMCQueue(comptime T: type, comptime capacity: usize) type {
    comptime std.debug.assert(std.math.isPowerOfTwo(capacity));
    return struct {
        const Self = @This();

        const Slot = struct {
            seq: std.atomic.Value(usize),
            value: T
        };

        io: std.Io,
        slots: [capacity]Slot,
        enqueue_pos: std.atomic.Value(usize),
        dequeue_pos: std.atomic.Value(usize),

        pub fn init(io: std.Io) Self {
            var self: Self = .{
                .io = io,
                .slots = undefined,
                .enqueue_pos = .init(0),
                .dequeue_pos = .init(0)
            };
            for (&self.slots, 0..) |*slot, i| {
                slot.* = .{ .seq = .init(i), .value = undefined };
            }
            
            return self;
        }

        pub fn push(self: *Self, value: T) !void {
            var pos = self.enqueue_pos.load(.monotonic);
            while (true) {
                const slot = &self.slots[pos & (capacity - 1)];
                const seq = slot.seq.load(.acquire);
                const diff = @as(isize, @intCast(seq)) - @as(isize, @intCast(pos));

                if (diff == 0) {
                    if (self.enqueue_pos.cmpxchgWeak(pos, pos+1, .monotonic, .monotonic)) |a| {
                        pos = a;
                    } else {
                        slot.value = value;
                        slot.seq.store(pos+1, .release);
                        return;
                    }
                } else if (diff < 0) {
                    return error.QueueFull;
                } else {
                    pos = self.enqueue_pos.load(.monotonic);
                }
            }
        }

        pub fn pop(self: *Self) ?T {
            var pos = self.dequeue_pos.load(.monotonic);
            while (true) {
                const slot = &self.slots[pos & (capacity - 1)];
                const seq = slot.seq.load(.acquire);
                const diff = @as(isize, @intCast(seq)) - @as(isize, @intCast(pos + 1));
                if (diff == 0) {
                    if (self.dequeue_pos.cmpxchgWeak(pos, pos + 1, .monotonic, .monotonic)) |a| {
                        pos = a;
                    } else {
                        const value = slot.value;
                        slot.seq.store(pos + capacity, .release);
                        return value;
                    }
                } else if (diff < 0) {
                    return null;
                } else {
                    pos = self.dequeue_pos.load(.monotonic);
                }
            }
        }
    };
}