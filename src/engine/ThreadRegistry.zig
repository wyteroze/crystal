// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const log = @import("../log.zig").threading;

pub const ThreadInfo = struct {
    name: []const u8 = "thread"
};

pub const ThreadRegistry = struct {
    pub const MAX_THREADS = 16;

    io: std.Io,
    mutex: std.Io.Mutex = .init,
    infos: [MAX_THREADS]ThreadInfo = undefined,
    count: usize = 0,

    pub fn init(io: std.Io) ThreadRegistry {
        return .{
            .io = io
        };
    }

    pub fn register(self: *ThreadRegistry, thread_name: []const u8) !usize {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);

        const id = self.count;
        self.infos[id] = .{ .name = thread_name };
        self.count += 1;

        return id;
    }

    pub fn name(self: *ThreadRegistry, id: usize) []const u8 {
        return self.infos[id].name;
    }

    pub fn threadCount(self: *ThreadRegistry) usize {
        self.mutex.lock(self.io) catch |e| {
            log.err("failed to get thread count: '{s}'", .{ @errorName(e) });
            return 0;
        };
        defer self.mutex.unlock(self.io);

        return self.count;
    }

    pub fn deinit(self: *ThreadRegistry) void {
        self.count = 0;
    }
};
