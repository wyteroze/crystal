
const std = @import("std");

const Filesystem = @This();
proc_init: std.process.Init,
pkg_id: []const u8,

pub fn init(proc_init: std.process.Init, pkg_id: []const u8) Filesystem {
    return .{ .proc_init = proc_init, .pkg_id = pkg_id };
}

pub fn getPersistPath(self: *const Filesystem, allocator: std.mem.Allocator) ![]const u8 {
    const appdata = self.proc_init.environ_map.get("APPDATA")
        orelse return error.AppdataNotFound;
    
    return try std.Io.Dir.path.join(allocator, &.{ appdata, self.pkg_id });
}

pub fn getCachePath(self: *const Filesystem, allocator: std.mem.Allocator) ![]const u8 {
    const lappdata = self.proc_init.environ_map.get("LOCALAPPDATA")
        orelse return error.LocalAppdataNotFound;
    
    return try std.Io.Dir.path.join(allocator, &.{ lappdata, self.pkg_id, "Cache" });
}

pub fn getTempPath(self: *const Filesystem, allocator: std.mem.Allocator) ![]const u8 {
    const lappdata = self.proc_init.environ_map.get("LOCALAPPDATA")
        orelse return error.LocalAppdataNotFound;
            
    return try std.Io.Dir.path.join(allocator, &.{ lappdata, "Temp", self.pkg_id });
}