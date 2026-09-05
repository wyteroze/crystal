// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const sokol = @import("sokol");
const Translator = @import("translate_c").Translator;

// The newlines are needed so concatenating headers doesn't break them
const shared_headers =
    \\#include "assimp/cimport.h"
    \\#include "assimp/scene.h"
    \\#include "assimp/postprocess.h"
    \\
;

const windows_c_headers =
    \\
;

const darwin_c_headers = 
    // Scheduling
    \\#include <sys/sysctl.h>
    \\#include <pthread.h>
    \\
;

const linux_c_headers = 
    // Scheduling
    \\#include <sched.h>
    \\#include <sys/resource.h>
    \\#include <unistd.h>
    \\#include <sys/syscall.h>
    \\
;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdk_path = b.option([]const u8, "sdk", "Path to macOS SDK (looks something like MacOSX26.5.sdk") 
        orelse std.zig.system.darwin.getSdk(b.allocator, b.graph.io, &target.result);

    b.sysroot = sdk_path;

    const dep_sdl3 = b.dependency("sdl3", .{ .target = target, .optimize = optimize });
    const dep_zlua = b.dependency("zlua", .{ .target = target, .optimize = optimize, .lang = .lua55 });
    const dep_sokol = b.dependency("sokol", .{ .target = target, .optimize = optimize, .gl = true });
    const dep_toml = b.dependency("toml", .{ .target = target, .optimize = optimize });
    const dep_zigimg = b.dependency("zigimg", .{ .target = target, .optimize = optimize });
    const dep_translate_c = b.dependency("translate_c", .{});
    const dep_shdc = dep_sokol.builder.dependency("shdc", .{});
    const dep_assimp = b.dependency("zig_assimp", .{ 
        .target = target, 
        .optimize = optimize, 
        .formats = "STL,Obj,FBX,glTF,glTF2", 
        .double = false, 
        .zlib = false 
    });

    const os_headers = switch (target.result.os.tag) {
        .windows => windows_c_headers, 
        .macos, .ios, .tvos, .watchos, .visionos, .maccatalyst => darwin_c_headers,
        .linux => linux_c_headers,

        else => @panic("This platform is not supported by any existing backends.")
    };

    const c_src = b.addWriteFiles();
    const headers = try std.mem.concat(b.allocator, u8, &.{ shared_headers, os_headers });
    const wrapper_h = c_src.add("wrapper.h", headers);

    const translator: Translator = .init(dep_translate_c, .{
        .c_source_file = wrapper_h,
        .target = target,
        .optimize = optimize
    });

    const c_mod = b.addModule("c", .{ 
        .root_source_file = translator.output_file 
    });

    const shader_mod = try sokol.shdc.createModule(b, "shaders", dep_sokol.module("sokol"), .{
        .shdc_dep = dep_shdc,
        .input = "src/gpu/shaders/basic.glsl",
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
            .{ .name = "zigimg", .module = dep_zigimg.module("zigimg") },
            .{ .name = "shaders", .module = shader_mod } ,
            .{ .name = "c", .module = c_mod }
        }
    });

    const engine_lib = b.addLibrary(.{ 
        .name = "engine", 
        .root_module = engine_mod, 
        .linkage = .static 
    });

    const lib_assimp = dep_assimp.artifact("assimp");

    engine_lib.root_module.linkLibrary(lib_assimp);
    engine_lib.root_module.addIncludePath(lib_assimp.getEmittedIncludeTree());
    translator.addIncludePath(lib_assimp.getEmittedIncludeTree());

    if (target.result.os.tag == .macos and sdk_path != null) {
        // Link SDK framework and includes
        const frameworks = b.pathJoin(&.{ sdk_path.?, "System", "Library", "Frameworks" });
        const includes = b.pathJoin(&.{ sdk_path.?, "usr", "include" });
        const libs = b.pathJoin(&.{ "/", "usr", "lib" });
        
        translator.addIncludePath(.{ .cwd_relative = includes });
        translator.addFrameworkPath(.{ .cwd_relative = frameworks });

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
