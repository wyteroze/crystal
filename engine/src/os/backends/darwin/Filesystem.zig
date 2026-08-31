
const std = @import("std");

const Filesystem = @This();
proc_init: std.process.Init,
pkg_id: []const u8,

pub fn init(proc_init: std.process.Init, pkg_id: []const u8) Filesystem {
    return .{ .proc_init = proc_init, .pkg_id = pkg_id };
}

pub fn getPersistPath(self: *const Filesystem, allocator: std.mem.Allocator) ![]const u8 {
    const home = self.proc_init.environ_map.get("HOME")
        orelse return error.HomeNotFound;

    return std.Io.Dir.path.join(allocator, &.{ home, "Library", "Application Support", self.pkg_id });
}

pub fn getCachePath(self: *const Filesystem, allocator: std.mem.Allocator) ![]const u8 {
    const home = self.proc_init.environ_map.get("HOME")
        orelse return error.HomeNotFound;

    return try std.Io.Dir.path.join(allocator, &.{ home, "Library", "Caches", self.pkg_id });
}

pub fn getTempPath(self: *const Filesystem, allocator: std.mem.Allocator) ![]const u8 {
    const tmpdir = self.proc_init.environ_map.get("TMPDIR")
        orelse return error.TempDirNotFound;

    return try std.Io.Dir.path.join(allocator, &.{ tmpdir, self.pkg_id });
}