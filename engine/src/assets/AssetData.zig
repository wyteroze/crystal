// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const types = @import("types.zig");
const gpu = @import("../gpu/gpu.zig");
const Assets = @import("Assets.zig");
const importers = @import("importers/importers.zig");
const render = @import("../render/render.zig");

pub const AssetResidency = enum { cpu, gpu };
pub const AssetType = enum { 
    mesh, 
    image, 
    font,
    script_source,

    pub fn uploadable(self: AssetType) bool {
        return switch (self) {
            .mesh, .image, .font => true,
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
    font: types.Font,
    script_source: types.ScriptSource,

    pub fn deinit(self: CpuAssetData, allocator: std.mem.Allocator) void {
        switch (self) {
            inline else => |a| a.deinit(allocator)
        }
    }

    pub fn parse(allocator: std.mem.Allocator, io: std.Io, path: []const u8, bytes: []u8, load_ctx: Assets.LoadContext) !CpuAssetData {
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

        if (std.mem.eql(u8, ext, ".ttf")) {
            defer allocator.free(bytes);
            return .{ .font = try importers.font_freetype.importFont(allocator, .{ .bytes = bytes }, .{ .pixel_size = load_ctx.pixel_size }) };
        }

        std.log.err("unknown file type '{s}'", .{ ext });
        return error.UnknownFileType;
    }
};

pub const GpuAssetData = union(AssetType) {
    mesh: types.GpuMesh,
    image: types.GpuImage,
    font: render.text.FontAtlas,

    // Not supported
    script_source: noreturn,

    pub fn fromCpuData(from: CpuAssetData, name: []const u8, allocator: std.mem.Allocator, gpu_device: *gpu.GpuDevice, upload_ctx: Assets.UploadContext) !GpuAssetData {
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
                const img_name = try std.mem.concatWithSentinel(allocator, u8, &.{ "'", name, "'", " Image" }, 0);
                defer allocator.free(img_name);

                const stride: u32 = switch (i.format) {
                    .rgba8 => 4,
                    .rgba16f => 8,
                    else => return error.UnsupportedCubemapFormat
                };

                if (upload_ctx.is_cubemap) {
                    const face_size: u32 = @intCast(i.height / 3);
                    const face_data = try sliceCubemapCross(allocator, i.data, @intCast(i.width), face_size, stride);
                    defer allocator.free(face_data);

                    return .{ .image =
                        try gpu_device.createImage(.{
                            .name = img_name,
                            .width = face_size,
                            .height = face_size,
                            .data = face_data,
                            .format = i.format,
                            .is_cubemap = true
                        })
                    };
                }

                return .{ .image =
                     try gpu_device.createImage(.{ 
                        .name = img_name,
                        .width = @intCast(i.width), 
                        .height = @intCast(i.height), 
                        .data = std.mem.sliceAsBytes(i.data),
                        .format = i.format,
                        .is_cubemap = false
                    }) 
                };
            },
            .font => |f| {
                const font_name = try std.mem.concatWithSentinel(allocator, u8, &.{ "'", name, "'", " Font" }, 0);
                defer allocator.free(font_name);

                return .{ .font = try .bake(allocator, font_name, gpu_device, f) };
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

fn sliceCubemapCross(allocator: std.mem.Allocator, src: []const u8, src_width: u32, face_size: u32, stride: u32) ![]u8 {
    const cells = [6][2]u32{
        .{ 2, 1 }, // +x
        .{ 0, 1 }, // -x
        .{ 1, 0 }, // +y
        .{ 1, 2 }, // -y
        .{ 1, 1 }, // +z
        .{ 3, 1 }, // -z
    };

    const face_bytes = face_size * face_size * stride;
    const out = try allocator.alloc(u8, face_bytes * 6);
    errdefer allocator.free(out);

    for (cells, 0..) |cell, face_idx| {
        const col = cell[0];
        const row = cell[1];
        const src_x0 = col * face_size;
        const src_y0 = row * face_size;

        for (0..face_size) |y| {
            const src_row_offset = ((src_y0 + y) * src_width + src_x0) * stride;
            const dst_row_offset = face_idx * face_bytes + y * face_size * stride;
            const row_bytes = face_size * stride;

            @memcpy(out[dst_row_offset..dst_row_offset + row_bytes], src[src_row_offset..src_row_offset + row_bytes]);
        }
    }

    return out;
}