// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Filesystem = @import("Filesystem.zig");

const LinuxBackend = @This();
proc_init: std.process.Init,
filesystem: Filesystem,

pub fn init(proc_init: std.process.Init, pkg_id: []const u8) LinuxBackend {
    return .{ .proc_init = proc_init, .filesystem = .init(proc_init, pkg_id) };
}