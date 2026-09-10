// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const types = @import("../types.zig");
const ImportLocation = @import("importers.zig").ImportLocation;
const assimp = @import("assimp");

pub fn importMesh(allocator: std.mem.Allocator, location: ImportLocation) !types.Mesh {
    const flags = assimp.aiProcess_Triangulate | assimp.aiProcess_GenNormals | assimp.aiProcess_FixInfacingNormals;
    const scene = switch (location) {
        .path => |p| blk: {
            const p_sentinel = try allocator.dupeSentinel(u8, p, 0);
            defer allocator.free(p_sentinel);

            break :blk assimp.aiImportFile(p_sentinel, flags);
        },
        .bytes => |b| blk: {
            break :blk assimp.aiImportFileFromMemory(b.ptr, @intCast(b.len), flags, null);
        }
    };

    if (scene == null) {
        std.log.err("{s:0}", .{ assimp.aiGetErrorString() });
        return error.ImportFailed;
    }
    defer assimp.aiReleaseImport(scene);

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
            assimp.aiVector3D{ .x = 0, .y = 0, .z = 0 };

        vertices[i] = .{ .position = .{ pos.x, pos.y, pos.z }, .normal = .{ norm.x, norm.y, norm.z }, .uv = .{ uv.x, uv.y } };
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
