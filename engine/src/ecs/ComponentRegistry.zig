// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const ComponentId = @import("ComponentId.zig");

const ComponentRegistry = @This();

allocator: std.mem.Allocator,
infos: std.ArrayList(ComponentInfo),
ids: std.StringHashMap(ComponentId),

pub const ComponentInfo = struct {
    name: []const u8,
    size: u32,
    alignment: u32,
    fields: []ComponentId.FieldDesc,
    dtor: ?*const fn (bytes: []u8) void = null
};

pub fn init(allocator: std.mem.Allocator) ComponentRegistry {
    return .{
        .allocator = allocator,
        .infos = .empty,
        .ids = .init(allocator)
    };
}

pub fn deinit(self: *ComponentRegistry) void {
    for (self.infos.items) |i| self.allocator.free(i.fields);
    self.infos.deinit(self.allocator);
    self.ids.deinit();
}

pub fn registerNative(self: *ComponentRegistry, comptime T: type, name: []const u8) !ComponentId {
    return self.registerNativeImpl(T, name, &.{});
}

pub fn registerNativeShaped(self: *ComponentRegistry, comptime T: type, name: []const u8) !ComponentId {
    const field = try self.allocator.dupe(ComponentId.FieldDesc, &.{
        .{ .name = "value", .type = .ofType(T), .offset = 0 }
    });

    return self.registerNativeImpl(T, name, field);
}

fn registerNativeImpl(self: *ComponentRegistry, comptime T: type, name: []const u8, fields: []ComponentId.FieldDesc) !ComponentId {
    if (self.ids.get(name)) |e| return e;

    const c_id: ComponentId = .{ .value = @intCast(self.infos.items.len) };
    try self.infos.append(self.allocator, .{
        .name = name,
        .size = @sizeOf(T),
        .alignment = @alignOf(T),
        .fields = fields
    });

    try self.ids.put(name, c_id);
    return c_id;
}

pub fn registerLayout(self: *ComponentRegistry, name: []const u8, fields: []ComponentId.FieldDesc) !ComponentId {
    if (self.ids.get(name)) |e| return e;

    var offset: u32 = 0;
    var max_align: u32 = 0;
    for (fields) |*f| {
        const f_align = f.elemAlign();
        max_align = @max(max_align, f_align);

        offset = std.mem.alignForward(u32, offset, f_align);
        f.offset = offset;

        offset += f.totalSize();
    }

    const size = std.mem.alignForward(u32, offset, max_align);
    const fields_owned = try self.allocator.dupe(ComponentId.FieldDesc, fields);

    const c_id: ComponentId = .{ .value = @intCast(self.infos.items.len) };
    try self.infos.append(self.allocator, .{
        .name = name,
        .size = size,
        .alignment = max_align,
        .fields = fields_owned
    });

    try self.ids.put(name, c_id);
    return c_id;
}

pub fn id(self: *ComponentRegistry, name: []const u8) ?ComponentId {
    return self.ids.get(name);
}

pub fn info(self: *ComponentRegistry, c_id: ComponentId) ComponentInfo {
    return self.infos.items[c_id.value];
}

pub fn infoFromName(self: *ComponentRegistry, name: []const u8) ?ComponentInfo {
    return self.info(self.id(name) orelse return null);
}

pub fn fieldOffset(self: *ComponentRegistry, c_id: ComponentId, field_name: []const u8) ?u32 {
    const fields = self.infos.items[c_id.value].fields;
    for (fields) |f| {
        if (std.mem.eql(u8, f.name, field_name)) return f.offset;
    }

    return null;
}
