// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const ComponentId = @import("ComponentId.zig");
const ComponentInfo = @import("ComponentInfo.zig");

pub const max_component_size = 256;
pub const max_alignment = 16;

const ComponentRegistry = @This();
allocator: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
infos: std.ArrayList(*const ComponentInfo),
ids: std.StringHashMap(ComponentId),

pub fn init(allocator: std.mem.Allocator) ComponentRegistry {
    return .{ 
        .allocator = allocator, 
        .arena = .init(allocator), 
        .infos = .empty, 
        .ids = .init(allocator)
    };
}

pub fn deinit(self: *ComponentRegistry) void {
    self.infos.deinit(self.allocator);
    self.ids.deinit();
    self.arena.deinit();
}

pub fn register(self: *ComponentRegistry, comptime T: type, name: []const u8) !ComponentId {
    comptime {
        if (@sizeOf(T) > max_component_size) @compileError(@typeName(T) ++ " exceeds max_component_size! Increase it in ComponentRegistry or reduce the size of your type.");
        if (@alignOf(T) > max_alignment) @compileError(@typeName(T) ++ " exceeds max_alignment! Increase it in ComponentRegistry or reduce the alignment of your type.");
    }

    return self.registerRaw(name, @typeName(T), @sizeOf(T), @alignOf(T), getDtor(T));
}

pub fn registerRaw(
    self: *ComponentRegistry, 
    name: []const u8, 
    type_name: []const u8, 
    size: u32, 
    alignment: u32, 
    free_fn: ?ComponentInfo.FreeFn
) !ComponentId {
    if (size > max_component_size or alignment > max_alignment) return error.ComponentTooLarge;

    if (self.ids.get(name)) |existing| {
        if (!std.mem.eql(u8, self.info(existing).type_name, type_name)) return error.ComponentTypeMismatch;
        return existing;
    }

    return self.add(.{ .name = "", .type_name = type_name, .size = size, .alignment = alignment, .free_fn = free_fn }, name);
}

fn add(self: *ComponentRegistry, template: ComponentInfo, name: []const u8) !ComponentId {
    const a = self.arena.allocator();
    const stored = try a.create(ComponentInfo);
    stored.* = template;
    stored.name = try a.dupe(u8, name);

    const c_id: ComponentId = .{ .value = @intCast(self.infos.items.len) };
    try self.infos.append(self.allocator, stored);
    try self.ids.put(stored.name, c_id);
    return c_id;
}

fn hasDtor(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => @hasDecl(T, "deinit"),
        else => false,
    };
}

fn getDtor(comptime T: type) ?ComponentInfo.FreeFn {
    if (comptime !hasDtor(T)) return null;

    return struct {
        fn c(allocator: std.mem.Allocator, bytes: []u8) void {
            const self: *T = @ptrCast(@alignCast(bytes.ptr));
            switch (@typeInfo(@TypeOf(T.deinit)).@"fn".param_types.len) {
                1 => self.deinit(),
                2 => self.deinit(allocator),
                else => @compileError(@typeName(T) ++ ".deinit must take (*T) or (*T, Allocator)!"),
            }
        }
    }.c;
}

pub fn id(self: *ComponentRegistry, name: []const u8) ?ComponentId {
    return self.ids.get(name);
}

pub fn info(self: *ComponentRegistry, c_id: ComponentId) *const ComponentInfo {
    return self.infos.items[c_id.value];
}
