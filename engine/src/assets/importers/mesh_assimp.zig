// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const types = @import("../types.zig");
const c = @cImport({
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});

pub fn importMesh(allocator: std.mem.Allocator, path: [:0]const u8) !types.Mesh {
    const scene = c.aiImportFile(path.ptr, c.aiProcess_Triangulate | c.aiProcess_GenNormals);

    if (scene == null) { std.log.err("{s:0}", .{ c.aiGetErrorString() }); return error.ImportFailed; }
    defer c.aiReleaseImport(scene);

    // TODO: import all meshes in the scene instead of only first
    const ai_mesh = scene.*.mMeshes[0].*;

    var vertices = try allocator.alloc(types.Vertex, ai_mesh.mNumVertices);
    errdefer allocator.free(vertices);

    for (0..ai_mesh.mNumVertices) |i| {
        const pos = ai_mesh.mVertices[i];
        const norm = ai_mesh.mNormals[i];
        const uv = if (ai_mesh.mTextureCoords[0] != null)
            ai_mesh.mTextureCoords[0][i]
        else
            c.aiVector3D{ .x = 0, .y = 0, .z = 0 };

        vertices[i] = .{
            .position = .{ pos.x, pos.y, pos.z },
            .normal = .{ norm.x, norm.y, norm.z },
            .uv = .{ uv.x, uv.y }
        };
    }

    var indices = try allocator.alloc(u32, ai_mesh.mNumFaces * 3);
    errdefer allocator.free(indices);

    for (0..ai_mesh.mNumFaces) |i| {
        const face = ai_mesh.mFaces[i];

        indices[i * 3 + 0] = face.mIndices[0];
        indices[i * 3 + 1] = face.mIndices[1];
        indices[i * 3 + 2] = face.mIndices[2];
    }

    return .{ .vertices = vertices, .indices = indices };
}
