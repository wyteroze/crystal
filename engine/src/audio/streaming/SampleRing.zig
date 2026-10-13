// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

const SampleRing = @This();
buf: []f32,
mask: usize,
head: std.atomic.Value(usize) = .init(0),
tail: std.atomic.Value(usize) = .init(0),

pub fn init(allocator: std.mem.Allocator, capacity: usize) !SampleRing {
    std.debug.assert(std.math.isPowerOfTwo(capacity));
    return .{ .buf = try allocator.alloc(f32, capacity), .mask = capacity - 1 };
}

pub fn deinit(self: *SampleRing, allocator: std.mem.Allocator) void {
    allocator.free(self.buf);
}

// Producer

pub fn writable(self: *const SampleRing) usize {
    return self.buf.len - (self.tail.load(.monotonic) -% self.head.load(.acquire));
}

pub fn write(self: *SampleRing, src: []const f32) void {
    const tail = self.tail.load(.monotonic);
    for (src, 0..) |s, i| self.buf[(tail +% i) & self.mask] = s;
    self.tail.store(tail +% src.len, .release);
}

// Consumer

pub fn available(self: *const SampleRing) usize {
    return self.tail.load(.acquire) -% self.head.load(.monotonic);
}

pub fn read(self: *SampleRing, dst: []f32) usize {
    const head = self.head.load(.monotonic);
    const n = @min(dst.len, self.tail.load(.acquire) -% head);

    for (0..n) |i| dst[i] = self.buf[(head +% i) & self.mask];
    self.head.store(head +% n, .release);

    return n;
}