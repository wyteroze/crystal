// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const linker = @import("../scripting/linker/linker.zig");
const Lua = zlua.Lua;

pub const Note = struct {
    buf: [96:0]u8 = @splat(0),

    pub fn set(self: *Note, s: []const u8) void {
        const n = @min(s.len, self.buf.len);
        @memcpy(self.buf[0..n], s[0..n]);
        self.buf[n] = 0;
    }

    pub fn get(self: *const Note) [:0]const u8 {
        return std.mem.sliceTo(&self.buf, 0);
    }
};

/// Filled in when a read fails, so the error message can have its name.
pub threadlocal var bad_field: Note = .{};
pub threadlocal var bad_component: Note = .{};

const Codec = @This();
size: u32,
alignment: u32,
read: *const fn (std.mem.Allocator, *Lua, i32, []u8) anyerror!void,
write: *const fn (*Lua, []const u8) void,
free: ?*const fn (std.mem.Allocator, []u8) void,
// Only set for types that declare `pub const __proxy = true;`
fields: []const FieldDesc = &.{},

pub fn of(comptime T: type) Codec {
    return .{
        .size = @sizeOf(T),
        .alignment = @alignOf(T),
        .read = struct {
            fn f(a: std.mem.Allocator, lua: *Lua, idx: i32, out: []u8) anyerror!void {
                const v = try readType(T, a, lua, idx);
                @memcpy(out[0..@sizeOf(T)], std.mem.asBytes(&v));
            }
        }.f,
        .write = struct {
            fn f(lua: *Lua, bytes: []const u8) void {
                pushType(T, lua, std.mem.bytesToValue(T, bytes[0..@sizeOf(T)]));
            }
        }.f,
        .free = if (comptime hasDeinit(T) or needsAlloc(T)) struct {
            fn f(a: std.mem.Allocator, bytes: []u8) void {
                destroy(T, a, @ptrCast(@alignCast(bytes.ptr)));
            }
        }.f else null,
        .fields = if (comptime isProxy(T)) blk: {
            const fs = comptime fieldsOf(T);
            break :blk &fs;
        } else &.{},
    };
}

pub const FieldDesc = struct {
    name: []const u8,
    codec: Codec,
    offset: u32 = 0,
};

fn fieldsOf(comptime T: type) [@typeInfo(T).@"struct".field_names.len]FieldDesc {
    const info = @typeInfo(T).@"struct";

    var out: [info.field_names.len]FieldDesc = undefined;
    for (info.field_names, 0..) |nm, i| out[i] = .{
        .name = &linker.util.pascalCase(nm),
        .codec = Codec.of(info.field_types[i]),
        .offset = @offsetOf(T, nm),
    };

    return out;
}

fn isProxy(comptime T: type) bool {
    if (@typeInfo(T) != .@"struct" or !@hasDecl(T, "__proxy")) return false;
    if (!isTable(T)) @compileError(@typeName(T) ++ ": __proxy needs a struct of table-readable fields");
    return true;
}

fn isTable(comptime T: type) bool {
    const s = switch (@typeInfo(T)) {
        .@"struct" => |s| s,
        else => return false,
    };

    if (s.is_tuple or s.field_names.len == 0 or @hasDecl(T, "__opaque")) return false;
    inline for (s.field_types) |FT| if (!isTableTypeOk(FT)) return false;
    return true;
}

fn isTableTypeOk(comptime F: type) bool {
    return switch (@typeInfo(F)) {
        .int, .float, .bool, .@"enum", .@"union" => true,
        .optional => |o| isTableTypeOk(o.child),
        .pointer => |p| p.size == .slice and p.child == u8,
        .@"struct" => isTable(F) or linker.util.isBoundType(F),
        else => false,
    };
}

fn isPlain(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => |s| !s.is_tuple and !@hasDecl(T, "__lua") and !@hasDecl(T, "__opaque"),
        else => false,
    };
}

fn readType(comptime T: type, a: std.mem.Allocator, lua: *Lua, idx: i32) anyerror!T {
    if (comptime @typeInfo(T) == .optional) {
        if (lua.isNoneOrNil(idx)) return null;
        return try readType(@typeInfo(T).optional.child, a, lua, idx);
    }

    if (comptime isTable(T)) {
        if (lua.typeOf(idx) == .table) return readTable(T, a, lua, lua.absIndex(idx));
    }

    if (comptime needsAlloc(T)) {
        const parsed = try linker.util.parseValAlloc(lua, T, idx);
        defer if (parsed.arena) |ar| {
            ar.deinit();
            lua.allocator().destroy(ar);
        };

        return deepDupe(a, T, parsed.value);
    }

    return linker.util.parseVal(lua, T, idx);
}

fn readTable(comptime T: type, a: std.mem.Allocator, lua: *Lua, idx: i32) anyerror!T {
    const info = @typeInfo(T).@"struct";

    lua.pushNil();
    while (lua.next(idx)) {
        defer lua.pop(1);
        if (lua.typeOf(-2) != .string) return error.NonStringKey;
        const key = try lua.toString(-2);

        var known = false;
        inline for (info.field_names) |f| {
            if (std.mem.eql(u8, key, &linker.util.pascalCase(f))) known = true;
        }

        if (!known) {
            bad_field.set(key);
            return error.UnknownField;
        }
    }

    var out: T = undefined;
    var n: usize = 0;
    errdefer inline for (info.field_names, 0..) |nm, i| {
        if (i < n) deepFree(a, info.field_types[i], @field(out, nm));
    };

    inline for (info.field_names, 0..) |nm, i| {
        _ = lua.pushString(&linker.util.pascalCase(nm));
        _ = lua.getTable(idx);
        defer lua.pop(1);

        if (lua.isNil(-1)) {
            if (info.field_attrs[i].defaultValue(info.field_types[i])) |dv| {
                @field(out, info.field_names[i]) = try deepDupe(a, info.field_types[i], dv);
            } else if (comptime @typeInfo(info.field_types[i]) == .optional) {
                @field(out, info.field_names[i]) = null;
            } else {
                bad_field.set(&linker.util.pascalCase(info.field_names[i]));
                return error.MissingField;
            }
        } else {
            @field(out, info.field_names[i]) = readType(info.field_types[i], a, lua, -1) catch |e| {
                bad_field.set(&linker.util.pascalCase(info.field_names[i]));
                return e;
            };
        }
        n += 1;
    }
    return out;
}

fn pushType(comptime T: type, lua: *Lua, v: T) void {
    switch (@typeInfo(T)) {
        .optional => |o| {
            if (v) |x| pushType(o.child, lua, x) else lua.pushNil();
            return;
        },
        .pointer => |p| if (comptime p.size == .slice and p.child == u8) {
            _ = lua.pushString(v);
            return;
        },
        else => {},
    }
    if (comptime linker.util.isBoundType(T)) return linker.util.pushVal(lua, T, v);
    
    if (comptime isTable(T)) {
        const info = @typeInfo(T).@"struct";
        lua.createTable(0, info.field_names.len);
        inline for (info.field_names, 0..) |nm, i| {
            pushType(info.field_types[i], lua, @field(v, nm));
            const key: [:0]const u8 = comptime &linker.util.pascalCase(nm) ++ "";
            lua.setField(-2, key);
        }

        return;
    }

    if (comptime needsAlloc(T)) lua.pushAny(v) catch unreachable else linker.util.pushVal(lua, T, v);
}

fn hasDeinit(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum" => @hasDecl(T, "deinit"),
        else => false,
    };
}

fn destroy(comptime T: type, a: std.mem.Allocator, p: *T) void {
    if (comptime hasDeinit(T)) {
        if (@typeInfo(@TypeOf(T.deinit)).@"fn".param_attrs.len == 1) p.deinit() else p.deinit(a);
    } else deepFree(a, T, p.*);
}

fn needsAlloc(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |info| info.size == .slice or info.size == .many or !info.attrs.@"const",
        .optional => |info| needsAlloc(info.child),
        .@"struct" => |info| blk: {
            if (@hasDecl(T, "__opaque") and T.__opaque) break :blk false;
            inline for (info.field_types) |FT| if (needsAlloc(FT)) break :blk true;
            break :blk false;
        },

        else => false,
    };
}

fn deepDupe(a: std.mem.Allocator, comptime T: type, v: T) !T {
    return switch (@typeInfo(T)) {
        .pointer => |info| if (info.size == .slice) try a.dupe(info.child, v) else v,
        .optional => |info| if (v) |inner| try deepDupe(a, info.child, inner) else null,
        .@"struct" => |info| blk: {
            var out: T = v;
            inline for (info.field_names, info.field_types) |name, FT| @field(out, name) = try deepDupe(a, FT, @field(v, name));

            break :blk out;
        },

        else => v,
    };
}

fn deepFree(a: std.mem.Allocator, comptime T: type, v: T) void {
    switch (@typeInfo(T)) {
        .pointer => |info| if (info.size == .slice) a.free(v),
        .optional => |info| if (v) |inner| deepFree(a, info.child, inner),
        .@"struct" => |info| inline for (info.field_names, info.field_types) |name, FT| deepFree(a, FT, @field(v, name)),

        else => {},
    }
}