// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    comptime std.debug.assert(std.math.isPowerOfTwo(capacity));

    return struct {
        const Self = @This();

        buffer: [capacity]T = undefined,
        head: std.atomic.Value(usize) = .init(0),
        tail: std.atomic.Value(usize) = .init(0),

        pub fn push(self: *Self, item: T) bool {
            const t = self.tail.load(.monotonic);
            const h = self.head.load(.acquire);
            if (t -% h == capacity) return false; // Full

            self.buffer[t & (capacity - 1)] = item;
            self.tail.store(t +% 1, .release);

            return true;
        }

        pub fn pop(self: *Self) ?T {
            const h = self.head.load(.monotonic);
            const t = self.tail.load(.acquire);
            if (h == t) return null; // Empty

            const item = self.buffer[h & (capacity - 1)];
            self.head.store(h +% 1, .release);

            return item;
        }
    };
}