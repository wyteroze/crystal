
const std = @import("std");

const Filesystem = @This();
proc_init: std.process.Init,
pkg_id: []const u8,

pub fn init(proc_init: std.process.Init, pkg_id: []const u8) Filesystem {
    return .{ .proc_init = proc_init, .pkg_id = pkg_id };
}

pub fn getPersistPath(self: *const Filesystem, allocator: std.mem.Allocator) ![]const u8 {
    var free = false;
    const share = self.proc_init.environ_map.get("XDG_DATA_HOME") orelse blk: {
        const home = self.proc_init.environ_map.get("HOME")
            orelse return error.HomeNotFound;
        
        free = true;
        break :blk try std.Io.Dir.path.join(allocator, &.{ home, ".local", "share" });
    };
    defer if (free) allocator.free(share);

    return try std.Io.Dir.path.join(allocator, &.{ share, self.pkg_id });
}

pub fn getCachePath(self: *const Filesystem, allocator: std.mem.Allocator) ![]const u8 {
    var free = false;
    const cache = self.proc_init.environ_map.get("XDG_CACHE_HOME") orelse blk: {
        const home = self.proc_init.environ_map.get("HOME")
            orelse return error.HomeNotFound;
        
        free = true;
        break :blk try std.Io.Dir.path.join(allocator, &.{ home, ".cache" });
    };
    defer if (free) allocator.free(cache);

    return try std.Io.Dir.path.join(allocator, &.{ cache, self.pkg_id });
}

pub fn getTempPath(self: *const Filesystem, allocator: std.mem.Allocator) ![]const u8 {
    const tmpdir = self.proc_init.environ_map.get("TMPDIR")
        orelse "/tmp";

    return try std.Io.Dir.path.join(allocator, &.{ tmpdir, self.pkg_id });
}