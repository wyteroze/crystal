// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const shared = @import("shared.zig");
const types = @import("../types.zig");
const Mesh = @import("../Mesh.zig").Mesh;
const Sprite = @import("../Sprite.zig").Sprite;
const Lua = zlua.Lua;
var allocator: std.mem.Allocator = undefined;
var io: std.Io = undefined;

const mesh_path = "src/assets/models/";
const image_path = "src/assets/images/";

const assets_lib = [_]zlua.FnReg {
    .{ .name = "loadMesh", .func = zlua.wrap(loadMesh) },
    .{ .name = "loadImage", .func = zlua.wrap(loadImage) }
};

pub fn loadMesh(l: *Lua) i32 {
    const path = l.checkString(1);
    const mesh = l.newUserdata(Mesh, 0);
    const full_path = std.mem.concat(allocator, u8, &.{ mesh_path, path }) catch |e| {
        l.raiseErrorStr("failed to form full path from '%s': '%s'", .{ path.ptr, @errorName(e).ptr });
        return 0;
    };
    defer allocator.free(full_path);

    mesh.* = Mesh.loadFromFile(allocator, io, full_path) catch |e| {
        l.raiseErrorStr("failed to load mesh '%s': '%s'", .{ full_path.ptr, @errorName(e).ptr });
        return 0;
    };

    l.setMetatableRegistry("MeshData");
    return 1;
}

pub fn loadImage(l: *Lua) i32 {
    const path = l.checkString(1);
    const sprite = l.newUserdata(Sprite, 0);
    const full_path = std.mem.concat(allocator, u8, &.{ image_path, path }) catch |e| {
        l.raiseErrorStr("failed to form full path from '%s': '%s'", .{ path.ptr, @errorName(e).ptr });
        return 0;
    };
    defer allocator.free(full_path);

    sprite.* = Sprite.loadFromFile(allocator, io, full_path) catch |e| {
        l.raiseErrorStr("failed to load image '%s': '%s'", .{ full_path.ptr, @errorName(e).ptr });
        return 0;
    };

    l.setMetatableRegistry("ImageData");
    return 1;
}

fn meshDataGc(l: *Lua) i32 {
    const mesh = l.checkUserdata(Mesh, 1, "MeshData");
    mesh.deinit();
    return 0;
}

fn imageDataGc(l: *Lua) i32 {
    const sprite = l.checkUserdata(Sprite, 1, "ImageData");
    sprite.deinit(allocator);
    return 0;
}

pub fn register(l: *Lua, a: std.mem.Allocator, i: std.Io) !void {
    allocator = a;
    io = i;

    // Assets library
    l.newTable();
    l.setFuncs(&assets_lib, 0);
    l.setGlobal("Assets");

    // Datatypes
    try l.newMetatable("MeshData");
    l.pushFunction(zlua.wrap(meshDataGc));
    l.setField(-2, "__gc");
    l.pop(1);

    try l.newMetatable("ImageData");
    l.pushFunction(zlua.wrap(imageDataGc));
    l.setField(-2, "__gc");
    l.pop(1);
}
