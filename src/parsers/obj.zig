// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const types = @import("../types.zig");
const Mesh = @import("../Mesh.zig").Mesh;

const Vec2_SIMD = types.Vec2_SIMD;
const Vec3_SIMD = types.Vec3_SIMD;
const Vertex = types.Vertex;
const Face = types.Face;

pub const ParseError = error{
    MissingComponents,
    InvalidFaceData,
    InvalidFloat,
    InvalidInt
};

pub fn parseObj(allocator: std.mem.Allocator, reader: *std.Io.Reader) !Mesh {
    var raw_positions = std.ArrayList(Vec3_SIMD).empty;
    defer raw_positions.deinit(allocator);
    var raw_uvs = std.ArrayList(Vec2_SIMD).empty;
    defer raw_uvs.deinit(allocator);

    var vertices = std.ArrayList(Vertex).empty;
    defer vertices.deinit(allocator);
    var indices = std.ArrayList(usize).empty;
    defer indices.deinit(allocator);
    var faces = std.ArrayList(Face).empty;
    defer faces.deinit(allocator);

    while (try reader.takeDelimiter('\n')) |line| {
        if (std.mem.startsWith(u8, line, "#")) {
            continue; // comment
        } else if (std.mem.startsWith(u8, line, "vn")) {
            continue; // we don't care about normals
        } else if (std.mem.startsWith(u8, line, "vt")) {
            const uv = try parseTextureLine(line);
            try raw_uvs.append(allocator, uv);
        } else if (std.mem.startsWith(u8, line, "v ")) {
            const vertex = try parseVertexLine(line);
            try raw_positions.append(allocator, vertex);
        } else if (std.mem.startsWith(u8, line, "f ")) {
            const start_idx = indices.items.len;

            try parseFaceLine(allocator, line, raw_positions.items, raw_uvs.items, &vertices, &indices);
            try faces.append(allocator, .{
                .start = start_idx,
                .length = 3
            });
        }
    }

    return Mesh.init(
        allocator,
        vertices.items,
        indices.items,
        faces.items,
        null // objs do not store textures
    );
}

fn parseVertexLine(line: []const u8) ParseError!Vec3_SIMD {
    var iter = std.mem.splitScalar(u8, line, ' ');
    _ = iter.next(); // consume "v"

    var vertex: [3]f32 = undefined;
    var index: usize = 0;
    while (iter.next()) |component| {
        if (component.len == 0) continue;
        if (index >= 3) break;

        vertex[index] = std.fmt.parseFloat(f32, component)
            catch return ParseError.InvalidFloat;

        index += 1;
    }

    if (index < 3) return ParseError.MissingComponents;
    return Vec3_SIMD{ vertex[0], vertex[1], vertex[2] };
}

fn parseFaceLine(allocator: std.mem.Allocator,
    line: []const u8,
    raw_positions: []const Vec3_SIMD,
    raw_uvs: []const Vec2_SIMD,
    vertices: *std.ArrayList(Vertex),
    indices: *std.ArrayList(usize)
) !void {
    var space_iter = std.mem.splitScalar(u8, line, ' ');
    _ = space_iter.next(); // consume "f"

    var corner_count: usize = 0;
    while (space_iter.next()) |corner_str| {
        if (corner_str.len == 0) continue;
        if (corner_count >= 3) break;

        var slash_iter = std.mem.splitScalar(u8, corner_str, '/');

        // position index
        const v_str = slash_iter.next()
            orelse return ParseError.InvalidFaceData;

        const v_idx = std.fmt.parseInt(usize, v_str, 10)
            catch return ParseError.InvalidInt;

        if (v_idx == 0 or v_idx > raw_positions.len)
            return ParseError.InvalidFaceData;
        const pos = raw_positions[v_idx - 1];

        // uv index
        var uv: Vec2_SIMD = Vec2_SIMD{ 0.0, 0.0 };
        if (slash_iter.next()) |vt_str| {
            if (vt_str.len > 0) {
                const vt_idx = std.fmt.parseInt(usize, vt_str, 10)
                    catch return ParseError.InvalidFaceData;

                if (vt_idx == 0 or vt_idx > raw_uvs.len)
                    return ParseError.InvalidFaceData;

                uv = raw_uvs[vt_idx - 1];
            }
        }

        // vertex
        const new_vertex = Vertex{ .position = pos, .uv = uv };
        try vertices.append(allocator, new_vertex);
        try indices.append(allocator, vertices.items.len - 1);

        corner_count += 1;
    }

    if (corner_count < 3) return ParseError.InvalidFaceData;
}


fn parseTextureLine(line: []const u8) ParseError!Vec2_SIMD {
    var iter = std.mem.splitScalar(u8, line, ' ');
    _ = iter.next(); // consume "vt"

    var uv: [2]f32 = undefined;
    var index: usize = 0;
    while (iter.next()) |component| {
        if (component.len == 0) continue;
        if (index >= 2) break; // ignore w component

        uv[index] = std.fmt.parseFloat(f32, component)
            catch return ParseError.InvalidFloat;

        index += 1;
    }

    if (index < 2) return ParseError.MissingComponents;
    return Vec2_SIMD{ uv[0], 1.0 - uv[1] }; // flip V
}
