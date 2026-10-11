// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const ComponentId = @import("ComponentId.zig");
const ComponentInfo = @import("ComponentInfo.zig");
const Codec = @import("Codec.zig");

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

    if (self.ids.get(name)) |existing| {
        if (self.info(existing).size != @sizeOf(T)) return error.ComponentTypeMismatch;
        return existing;
    }

    return self.add(.{ .name = "", .size = @sizeOf(T), .alignment = @alignOf(T), .codec = .of(T) }, name);
}

pub fn registerLayout(self: *ComponentRegistry, name: []const u8, fields: []const Codec.FieldDesc) !ComponentId {
    if (self.ids.get(name)) |e| return e;
    if (fields.len == 0) return error.NoFields;

    const a = self.arena.allocator();
    const owned = try a.dupe(Codec.FieldDesc, fields);
    var offset: u32 = 0;
    var max_align: u32 = 1;
    for (owned) |*f| {
        f.name = try a.dupe(u8, f.name);
        offset = std.mem.alignForward(u32, offset, f.codec.alignment);
        f.offset = offset;
        offset += f.codec.size;
        max_align = @max(max_align, f.codec.alignment);
    }

    const size = std.mem.alignForward(u32, offset, max_align);
    if (size > max_component_size or max_align > max_alignment) return error.ComponentTooLarge;

    return self.add(.{ .name = "", .size = size, .alignment = max_align, .codec = null, .fields = owned }, name);
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

pub fn id(self: *ComponentRegistry, name: []const u8) ?ComponentId {
    return self.ids.get(name);
}

pub fn info(self: *ComponentRegistry, c_id: ComponentId) *const ComponentInfo {
    return self.infos.items[c_id.value];
}
