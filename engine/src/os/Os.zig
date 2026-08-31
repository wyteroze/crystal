// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Backend = @import("Backend.zig").Backend;

const Os = @This();
backend: Backend,
package_id: []const u8,

pub fn init(proc_init: std.process.Init, comptime os_tag: std.Target.Os.Tag, pkg_id: []const u8) !Os {
    const backend: Backend = switch (os_tag) {
        .windows => .initWindows(proc_init, pkg_id),
        .macos, .ios, .tvos, .watchos, .visionos, .maccatalyst => .initDarwin(proc_init, pkg_id),
        .linux => .initLinux(proc_init, pkg_id),

        else => @compileError("This platform is not supported by any existing backends.")
    };

    return .{ .backend = backend, .package_id = pkg_id };
}

pub fn filesystem(self: *const Os) Filesystem {
    return .{ .os = self };
}

pub const Filesystem = struct {
    os: *const Os,

    pub fn getPersistPath(self: Filesystem, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self.os.backend) {
            .darwin => |b| b.filesystem.getPersistPath(allocator),
            .linux => |b| b.filesystem.getPersistPath(allocator),
            .windows => |b| b.filesystem.getPersistPath(allocator)
        };
    }

    pub fn getTempPath(self: Filesystem, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self.os.backend) {
            .darwin => |b| b.filesystem.getTempPath(allocator),
            .linux => |b| b.filesystem.getTempPath(allocator),
            .windows => |b| b.filesystem.getTempPath(allocator)
        };
    }

    pub fn getCachePath(self: Filesystem, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self.os.backend) {
            .darwin => |b| b.filesystem.getCachePath(allocator),
            .linux => |b| b.filesystem.getCachePath(allocator),
            .windows => |b| b.filesystem.getCachePath(allocator)
        };
    }
};