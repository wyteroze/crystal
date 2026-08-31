// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const asset_sources = @import("sources/sources.zig").sources;
const AssetSource = @import("sources/AssetSource.zig");
const DirSource = @import("sources/DirSource.zig");
const AssetUri = @import("AssetUri.zig");
const AssetHandle = @import("AssetHandle.zig");
const Cache = @import("Cache.zig");
const Os = @import("../os/Os.zig");

const AssetRegistry = @This();
allocator: std.mem.Allocator,
io: std.Io,
cache: Cache,
sources: std.StringHashMap(AssetSource),
assets_path: ?[]const u8,

pub fn init(allocator: std.mem.Allocator, io: std.Io, os: Os, proj_path: ?[]const u8) !AssetRegistry {
    const assets_path = if (proj_path) |p| try std.Io.Dir.path.join(allocator, &.{ p, "assets" }) else null;
    var sources: std.StringHashMap(AssetSource) = .init(allocator);
    
    inline for (asset_sources) |s| {
        const src_ptr = try allocator.create(DirSource);
        src_ptr.* = try s.init(allocator, io, os, assets_path);

        try sources.put(s.scheme, src_ptr.source());
    }

    return .{ 
        .allocator = allocator, 
        .io = io, 
        .cache = .init(allocator, io), 
        .sources = sources, 
        .assets_path = assets_path
    };
}

pub fn deinit(self: *AssetRegistry) void {
    var iter = self.sources.iterator();
    while (iter.next()) |s| self.allocator.destroy(@as(*DirSource, @alignCast(@ptrCast(s.value_ptr.ptr))));
    if (self.assets_path) |p| self.allocator.free(p);

    self.sources.deinit();
    self.cache.deinit();
}

pub fn registerSource(self: *AssetRegistry, scheme: []const u8, source: AssetSource) !void {
    try self.sources.put(scheme, source);
}

pub fn load(self: *AssetRegistry, uri_str: []const u8) !AssetHandle {
    const uri: AssetUri = try .parse(self.allocator, uri_str);
    defer uri.deinit(self.allocator);

    const source = self.sources.get(uri.scheme) orelse return error.UnknownScheme;
    const id = try self.cache.load(source, uri_str, uri.path);
    return .acquire(&self.cache, id);
}

pub const registerLua = struct {
    const zlua = @import("zlua");
    const linker = @import("../scripting/linker/linker.zig");

    pub fn registerLua(l: *zlua.Lua) void {
        linker.reference(l, AssetHandle, .{
            .name = .auto,
            .scope = .{ .module = "assets.types" }
        });

        linker.reference(l, AssetRegistry, .{
            .name = .{ .named = "assets" },
            .scope = .top_level_module,
            .methods = &.{
                .named("load", AssetRegistry.load)
            }
        });
    }
}.registerLua;