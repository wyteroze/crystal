// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const linker = @import("../scripting/linker/linker.zig");

const ComponentId = @This();
value: u32,

pub const invalid: ComponentId = .{ .value = std.math.maxInt(u32) };

pub fn eql(a: ComponentId, b: ComponentId) bool {
    return a.value == b.value;
}

pub const FieldType = struct {
    size: u32,
    alignment: u32,
    read: *const fn (allocator: std.mem.Allocator, lua: *zlua.Lua, idx: i32, out: []u8) anyerror!void,
    write: *const fn (lua: *zlua.Lua, bytes: []const u8) void,
    free: ?*const fn (allocator: std.mem.Allocator, bytes: []u8) void = null,

    pub fn ofType(comptime T: type) FieldType {
        return if (comptime needsAlloc(T)) ofTypeAlloc(T) else ofTypePlain(T);
    }

    fn ofTypePlain(comptime T: type) FieldType {
        return .{
            .size = @sizeOf(T),
            .alignment = @alignOf(T),
            .read = struct {
                pub fn c(allocator: std.mem.Allocator, lua: *zlua.Lua, idx: i32, out: []u8) anyerror!void {
                    _ = allocator;
                    const v = try linker.util.parseVal(lua, T, idx);
                    @memcpy(out[0..@sizeOf(T)], std.mem.asBytes(&v));
                }
            }.c,
            .write = struct {
                pub fn c(l: *zlua.Lua, bytes: []const u8) void {
                    const v: T = std.mem.bytesToValue(T, bytes[0..@sizeOf(T)]);
                    linker.util.pushVal(l, T, v);
                }
            }.c
        };
    }

    fn ofTypeAlloc(comptime T: type) FieldType {
        return .{
            .size = @sizeOf(T),
            .alignment = @alignOf(T),
            .read = struct {
                fn c(allocator: std.mem.Allocator, lua: *zlua.Lua, idx: i32, out: []u8) anyerror!void {
                    const parsed = try linker.util.parseValAlloc(lua, T, idx);
                    defer if (parsed.arena) |a| { a.deinit(); lua.allocator().destroy(a); };

                    const owned = try deepDupe(allocator, T, parsed.value);
                    @memcpy(out[0..@sizeOf(T)], std.mem.asBytes(&owned));
                }
            }.c,
            .write = struct {
                fn c(lua: *zlua.Lua, bytes: []const u8) void {
                    const v: T = std.mem.bytesToValue(T, bytes[0..@sizeOf(T)]);
                    lua.pushAny(v) catch unreachable;
                }
            }.c,
            .free = struct {
                fn c(allocator: std.mem.Allocator, bytes: []u8) void {
                    const v: T = std.mem.bytesToValue(T, bytes[0..@sizeOf(T)]);
                    deepFree(allocator, T, v);
                }
            }.c
        };
    }

    fn needsAlloc(comptime T: type) bool {
        return switch (@typeInfo(T)) {
            .pointer => |info| info.size == .slice or info.size == .many or !info.is_const,
            .optional => |info| needsAlloc(info.child),
            .@"struct" => |info| blk: {
                if (@hasDecl(T, "__opaque") and T.__opaque) break :blk false;
                inline for (info.fields) |f| {
                    if (needsAlloc(f.type)) break :blk true;
                }
                break :blk false;
            },
            else => false
        };
    }

    fn deepDupe(allocator: std.mem.Allocator, comptime T: type, v: T) !T {
        return switch (@typeInfo(T)) {
            .pointer => |info| blk: {
                if (info.size == .slice) {
                    std.debug.print("dupe slice: ptr={*} len={} elem={s}\n", .{ v.ptr, v.len, @typeName(info.child) });
                    break :blk try allocator.dupe(info.child, v);
                }
                break :blk v;
            },
            .optional => |info| if (v) |inner| try deepDupe(allocator, info.child, inner) else null,
            .@"struct" => |info| blk: {
                var out: T = v;
                inline for (info.fields) |f| {
                    @field(out, f.name) = try deepDupe(allocator, f.type, @field(v, f.name));
                }
                break :blk out;
            },
            else => v
        };
    }

    fn deepFree(allocator: std.mem.Allocator, comptime T: type, v: T) void {
        switch (@typeInfo(T)) {
            .pointer => |info| if (info.size == .slice) allocator.free(v),
            .optional => |info| if (v) |inner| deepFree(allocator, info.child, inner),
            .@"struct" => |info| inline for (info.fields) |f| deepFree(allocator, f.type, @field(v, f.name)),
            else => {}
        }
    }
};

pub const FieldDesc = struct {
    name: []const u8,
    type: FieldType,
    offset: u32 = 0,

    pub fn totalSize(self: FieldDesc) u32 {
        return self.type.size;
    }

    pub fn elemAlign(self: FieldDesc) u32 {
        return self.type.alignment;
    }
};
