// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const DarwinBackend = @import("backends/darwin/DarwinBackend.zig");
const WindowsBackend = @import("backends/windows/WindowsBackend.zig");
const LinuxBackend = @import("backends/linux/LinuxBackend.zig");

pub const Backend = union(enum) {
    darwin: DarwinBackend,
    windows: WindowsBackend,
    linux: LinuxBackend,

    pub fn initDarwin(proc_init: std.process.Init, pkg_id: []const u8) Backend {
        return .{ .darwin = .init(proc_init, pkg_id) };
    }
    pub fn initWindows(proc_init: std.process.Init, pkg_id: []const u8) Backend {
        return .{ .windows = .init(proc_init, pkg_id) };
    }
    pub fn initLinux(proc_init: std.process.Init, pkg_id: []const u8) Backend {
        return .{ .linux = .init(proc_init, pkg_id) };
    }
};