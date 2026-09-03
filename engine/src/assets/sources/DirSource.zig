// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Source = @import("Source.zig");

const DirSource = @This();
allocator: std.mem.Allocator,
io: std.Io,
base_dir: std.Io.Dir,

pub fn init(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !DirSource {
    return .{ 
        .allocator = allocator, 
        .io = io, 
        .base_dir = try .createDirPathOpen(.cwd(), io, path, .{ })
    };
}

pub fn deinit(self: DirSource) void {
    self.base_dir.close(self.io);
}

pub fn source(self: *DirSource) Source {
    return .{
        .ptr = self,
        .vtable = &.{
            .read = struct {
                fn c(ptr: *anyopaque, path: []const u8) ![]u8 {
                    const s: *DirSource = @ptrCast(@alignCast(ptr));
                    return s.base_dir.readFileAlloc(s.io, path, s.allocator, .unlimited) catch |e| {
                        if (e == error.FileNotFound) {
                            var buf: [std.fs.max_path_bytes]u8 = undefined;
                            const len = try s.base_dir.realPath(s.io, &buf);
                            
                            std.log.err("file not found: '{s}{s}{s}'", .{ buf[0..len], std.Io.Dir.path.sep_str, path });
                        }

                        return e;
                    };
                }
            }.c,

            .write = struct {
                fn c(ptr: *anyopaque, path: []const u8, bytes: []const u8) !void {
                    const s: *DirSource = @ptrCast(@alignCast(ptr));
                    try s.base_dir.writeFile(s.io, .{ .sub_path = path, .data = bytes });
                }
            }.c
        }
    };
}   