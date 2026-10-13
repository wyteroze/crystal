// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Audio = @import("../Audio.zig");
const StreamDecoder = @import("StreamDecoder.zig");

const poll_ns = 2 * std.time.ns_per_ms;
const frames_per_pass = 8192;

const DecoderThread = @This();
io: std.Io,
allocator: std.mem.Allocator,
mutex: std.Io.Mutex = .init,
slots: [Audio.max_voices]?*StreamDecoder = @splat(null),
running: std.atomic.Value(bool) = .init(false),
thread: ?std.Thread = null,

pub fn start(self: *DecoderThread) !void {
    self.running.store(true, .release);
    self.thread = try .spawn(.{}, run, .{ self });
}

pub fn deinit(self: *DecoderThread) void {
    self.running.store(false, .release);
    if (self.thread) |t| t.join();

    for (0..Audio.max_voices) |i| self.remove(i);
}

pub fn add(self: *DecoderThread, index: usize, d: *StreamDecoder) void {
    self.mutex.lockUncancelable(self.io);
    defer self.mutex.unlock(self.io);

    self.slots[index] = d;
}

pub fn remove(self: *DecoderThread, index: usize) void {
    self.mutex.lockUncancelable(self.io);
    const decoder = self.slots[index];
    self.slots[index] = null;
    self.mutex.unlock(self.io);

    if (decoder) |d| d.deinit(self.allocator);
}

fn run(self: *DecoderThread) void {
    while (self.running.load(.acquire)) {
        var did_work = false;
        {
            self.mutex.lockUncancelable(self.io);
            defer self.mutex.unlock(self.io);

            for (self.slots) |maybe| {
                const d = maybe orelse continue;
                if (!d.needsFill()) continue;
                d.fill(frames_per_pass);
                did_work = true;
            }
        }
        
        // This should be a futex in the future.
        if (!did_work) self.io.sleep(.fromNanoseconds(poll_ns), .awake) catch {};
    }
}