// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.
//! This is what other sources (like `CwdSource` and `PersistSource`) implement.
//! `asset://` URIs use either the `FileSource` (`file://`) or the `PackSource` (`pack://`)
//! based on whether or not the loaded project has development mode enabled (`project.dev = true` in the .toml)

const AssetSource = @This();
ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    read: *const fn (ptr: *anyopaque, path: []const u8) anyerror![]u8,
    write: *const fn (ptr: *anyopaque, path: []const u8, bytes: []u8) anyerror!void,
};

pub fn read(self: AssetSource, path: []const u8) ![]u8 {
    return self.vtable.read(self.ptr, path);
}

pub fn write(self: AssetSource, path: []const u8, bytes: []u8) !void {
    self.vtable.write(self.ptr, path, bytes);
}