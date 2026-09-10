// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const types = @import("types.zig");
const gpu = @import("../gpu/gpu.zig");
const importers = @import("importers/importers.zig");

pub const AssetResidency = enum { cpu, gpu };
pub const AssetType = enum { 
    mesh, 
    image, 
    script_source,

    pub fn uploadable(self: AssetType) bool {
        return switch (self) {
            .mesh, .image => true,
            else => false
        };
    }
};

pub const AssetData = union(AssetResidency) {
    cpu: CpuAssetData,
    gpu: GpuAssetData
};

pub const CpuAssetData = union(AssetType) {
    mesh: types.Mesh,
    image: types.Image,
    script_source: types.ScriptSource,

    pub fn deinit(self: CpuAssetData, allocator: std.mem.Allocator) void {
        switch (self) {
            inline else => |a| a.deinit(allocator)
        }
    }

    pub fn parse(allocator: std.mem.Allocator, io: std.Io, path: []const u8, bytes: []u8) !CpuAssetData {
        const ext = std.Io.Dir.path.extension(path);

        if (std.mem.eql(u8, ext, ".obj") 
            or std.mem.eql(u8, ext, ".glb") 
            or std.mem.eql(u8, ext, ".gltf") 
            or std.mem.eql(u8, ext, ".stl") 
            or std.mem.eql(u8, ext, ".fbx")
        ) {
            defer allocator.free(bytes);
            return .{ .mesh = try importers.mesh_assimp.importMesh(allocator, .{ .bytes = bytes }) };
        }

        if (std.mem.eql(u8, ext, ".png")
            or std.mem.eql(u8, ext, ".bmp")
            or std.mem.eql(u8, ext, ".jpg")
            or std.mem.eql(u8, ext, ".jpeg")
            or std.mem.eql(u8, ext, ".tiff")
            or std.mem.eql(u8, ext, ".png")
        ) {
            defer allocator.free(bytes);
            return .{ .image = try importers.image_zigimg.importImage(allocator, io, .{ .bytes = bytes }) };
        }

        if (std.mem.eql(u8, ext, ".lua")) {
            return .{ .script_source = .{ .type = .text, .data = bytes } };
        } else if (std.mem.eql(u8, ext, ".luac")) {
            return .{ .script_source = .{ .type = .bytecode, .data = bytes } };
        }

        std.log.err("unknown file type '{s}'", .{ ext });
        return error.UnknownFileType;
    }
};

pub const GpuAssetData = union(AssetType) {
    mesh: types.GpuMesh,
    image: types.GpuImage,

    // Not supported
    script_source: noreturn,

    pub fn fromCpuData(from: CpuAssetData, name: []const u8, allocator: std.mem.Allocator, gpu_device: *gpu.GpuDevice) !GpuAssetData {
        switch (from) {
            .mesh => |m| {
                const vbuf_name = try std.mem.concatWithSentinel(allocator, u8, &.{ "'", name, "'", " Vertex Buffer" }, 0);
                const ibuf_name = try std.mem.concatWithSentinel(allocator, u8, &.{ "'", name, "'", " Index Buffer" }, 0);
                defer allocator.free(vbuf_name);
                defer allocator.free(ibuf_name);

                return .{ .mesh = .{
                    .vertex_buffer = try gpu_device.createBuffer(.{
                        .name = vbuf_name, .type = .vertex, .data = std.mem.sliceAsBytes(m.vertices)
                    }),
                    .index_buffer = try gpu_device.createBuffer(.{
                        .name = ibuf_name, .type = .index, .data = std.mem.sliceAsBytes(m.indices)
                    }),
                    .vertex_count = @intCast(m.vertices.len),
                    .index_count = @intCast(m.indices.len)
                } };
            },
            .image => |i| {
                const img_name = try std.mem.concat(allocator, u8, &.{ "'", name, "'", " Image" });
                defer allocator.free(img_name);

                return .{ .image = .{ .handle = 
                    try gpu_device.createImage(.{ 
                        .name = "teapot texture",
                        .width = @intCast(i.width), 
                        .height = @intCast(i.height), 
                        .data = std.mem.sliceAsBytes(i.data),
                        .format = i.format,
                    })
                } };
            },
            
            else => unreachable
        }
    }

    pub fn deinit(self: GpuAssetData) void {
        switch (self) {
            inline else => |a| a.deinit()
        }
    }
};