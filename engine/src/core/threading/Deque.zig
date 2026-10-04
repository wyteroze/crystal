// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub fn Deque(comptime T: type) type {
    return struct {
        const Self = @This();

        buffer: []T,
        mask: usize,
        top: std.atomic.Value(i64) = .init(0),
        bottom: std.atomic.Value(i64) = .init(0),

        pub fn init(allocator: std.mem.Allocator, size: usize) !Self {
            std.debug.assert(std.math.isPowerOfTwo(size));

            return .{
                .buffer = try allocator.alloc(T, size),
                .mask = size-1,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.buffer);
        }

        /// Should only be called on the owner thread
        pub fn pushToBottom(self: *Self, item: T) void {
            const b = self.bottom.load(.monotonic);
            self.buffer[@intCast(b & @as(i64, @intCast(self.mask)))] = item;
            self.bottom.store(b+1, .release);
        }

        /// Should only be called on the owner thread        
        pub fn popFromBottom(self: *Self) ?T {
            const b = self.bottom.load(.monotonic)-1;
            self.bottom.store(b, .monotonic);
            
            const t = self.top.load(.monotonic);
            if (t > b) { // empty
                self.bottom.store(b+1, .monotonic);
                return null;
            }

            const item = self.buffer[@intCast(b & @as(i64, @intCast(self.mask)))];
            if (t == b) { // last item, contention against stealer. only time CAS is needed
                if (self.top.cmpxchgStrong(t, t+1, .acq_rel, .monotonic) == null) {
                    self.bottom.store(b+1, .monotonic);
                    return item;
                }

                self.bottom.store(b+1, .monotonic);
                return null; // stealer won the race
            }

            return item;
        }

        /// Can be called on any thread
        pub fn steal(self: *Self) ?T {
            const t = self.top.load(.acquire);
            const b = self.bottom.load(.acquire);
            if (t >= b) return null;

            const item = self.buffer[@intCast(t & @as(i64, @intCast(self.mask)))];
            if (self.top.cmpxchgStrong(t, t + 1, .acq_rel, .monotonic) != null) {
                return null; // lost the race to another stealer
            }

            return item;
        }
    };
}