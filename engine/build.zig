// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const sokol = @import("sokol");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdk_path = b.option([]const u8, "sdk", "Path to macOS SDK (looks something like MacOSX26.5.sdk") 
        orelse std.zig.system.darwin.getSdk(b.allocator, b.graph.io, &target.result);

    const dep_sdl3 = b.dependency("sdl3", .{ .target = target, .optimize = optimize });
    const dep_zlua = b.dependency("zlua", .{ .target = target, .optimize = optimize, .lang = .lua55 });
    const dep_sokol = b.dependency("sokol", .{ .target = target, .optimize = optimize, .gl = true });
    const dep_toml = b.dependency("toml", .{ .target = target, .optimize = optimize });
    const dep_shdc = dep_sokol.builder.dependency("shdc", .{});
    const dep_assimp = b.dependency("zig_assimp", .{ 
        .target = target, 
        .optimize = optimize, 
        .formats = "STL,Obj,FBX,glTF,glTF2", 
        .double = false, 
        .zlib = false 
    });

    const shader_mod = try sokol.shdc.createModule(b, "shaders", dep_sokol.module("sokol"), .{
        .shdc_dep = dep_shdc,
        .input = "src/gfx/shaders/basic.glsl",
        .output = "basic.glsl.zig",
        .slang = .{
            .glsl410 = true,
            .hlsl5 = true,
            .metal_macos = true,
            .wgsl = true,
        },
    });

    const engine_mod = b.addModule("engine", .{
        .root_source_file = b.path("src/engine.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ 
            .{ .name = "sdl3", .module = dep_sdl3.module("sdl3") }, 
            .{ .name = "zlua", .module = dep_zlua.module("zlua") }, 
            .{ .name = "sokol", .module = dep_sokol.module("sokol") }, 
            .{ .name = "toml", .module = dep_toml.module("toml") },
            .{ .name = "shaders", .module = shader_mod } 
        },
    });

    const engine_lib = b.addLibrary(.{ 
        .name = "engine", 
        .root_module = engine_mod, 
        .linkage = .static 
    });

    const lib_assimp = dep_assimp.artifact("assimp");

    engine_lib.root_module.linkLibrary(lib_assimp);
    engine_lib.root_module.addIncludePath(lib_assimp.getEmittedIncludeTree());

    if (target.result.os.tag == .macos and sdk_path != null) {
        // Link SDK framework and includes
        const frameworks = b.pathJoin(&.{ sdk_path.?, "System", "Library", "Frameworks" });
        const includes = b.pathJoin(&.{ sdk_path.?, "usr", "include" });
        const libs = b.pathJoin(&.{ "/", "usr", "lib" });

        engine_lib.root_module.addFrameworkPath(.{ .cwd_relative = frameworks });
        engine_lib.root_module.addIncludePath(.{ .cwd_relative = includes });
        engine_lib.root_module.addLibraryPath(.{ .cwd_relative = libs });

        // Sokol
        const scl = dep_sokol.artifact("sokol_clib");
        scl.root_module.addFrameworkPath(.{ .cwd_relative = frameworks });
        scl.root_module.addIncludePath(.{ .cwd_relative = includes });
        scl.root_module.addLibraryPath(.{ .cwd_relative = libs });

        // Link zlib for assimp
        lib_assimp.root_module.addFrameworkPath(.{ .cwd_relative = frameworks });
        lib_assimp.root_module.addLibraryPath(.{ .cwd_relative = libs });
        lib_assimp.root_module.linkSystemLibrary("z", .{});
    }

    b.installArtifact(engine_lib);
}
