// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const sokol = @import("sokol");
const Translator = @import("translate_c").Translator;
const diligent_vendor = @import("diligent_engine");

// The newlines are needed for these headers so concatenating doesn't break them
const assimp_headers =
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

const diligent_headers =
    \\#define DILIGENT_C_INTERFACE 1
    \\#include "DiligentCore/Graphics/GraphicsEngineVulkan/interface/EngineFactoryVk.h"
    \\
;

// For Apple platforms
const SdkPaths = struct {
    frameworks: []const u8,
    includes: []const u8,
    libs: []const u8,

    fn resolve(b: *std.Build, sdk_path: ?[]const u8) ?SdkPaths {
        const path = sdk_path orelse return null;
        return .{
            .frameworks = b.pathJoin(&.{ path, "System", "Library", "Frameworks" }),
            .includes = b.pathJoin(&.{ path, "usr", "include" }),
            .libs = b.pathJoin(&.{ "/", "usr", "lib" })
        };
    }

    fn applyToTranslator(self: SdkPaths, translator: Translator) void {
        translator.addIncludePath(.{ .cwd_relative = self.includes });
        translator.addFrameworkPath(.{ .cwd_relative = self.frameworks });
    }

    fn applyToModule(self: SdkPaths, module: *std.Build.Module) void {
        module.addFrameworkPath(.{ .cwd_relative = self.frameworks });
        module.addIncludePath(.{ .cwd_relative = self.includes });
        module.addLibraryPath(.{ .cwd_relative = self.libs });
    }
};

fn dependencyStep(dependency: *std.Build.Dependency, step_name: []const u8) *std.Build.Step {
    const found = dependency.builder.top_level_steps.get(step_name) orelse {
        std.debug.panic(
            "dependency '{s}' has no top-level step named '{s}'",
            .{ dependency.builder.pathFromRoot("build.zig"), step_name }
        );
    };

    return &found.step;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdk_path = b.option([]const u8, "sdk", "Path to macOS SDK (looks something like MacOSX26.5.sdk)")
        orelse std.zig.system.darwin.getSdk(b.allocator, b.graph.io, &target.result);
    const sdk: ?SdkPaths = .resolve(b, sdk_path);

    const backend = b.option(enum { gl, d3d11, d3d12, vulkan }, "backend", "Backend to use\n(default: gl)")
        orelse .gl;

    const dep_sdl3 = b.dependency("sdl3", .{ .target = target, .optimize = optimize });
    const dep_zlua = b.dependency("zlua", .{ .target = target, .optimize = optimize, .lang = .lua55 });
    const dep_sokol = b.dependency("sokol", .{ .target = target, .optimize = optimize, .gl = true });
    const dep_toml = b.dependency("toml", .{ .target = target, .optimize = optimize });
    const dep_zigimg = b.dependency("zigimg", .{ .target = target, .optimize = optimize });
    const dep_translate_c = b.dependency("translate_c", .{});
    const dep_shdc = dep_sokol.builder.dependency("shdc", .{});
    const dep_diligent = b.dependency("diligent_engine", .{ .optimize = optimize, .backend = backend });
    const dep_assimp = b.dependency("zig_assimp", .{
        .target = target,
        .optimize = optimize,
        .formats = "STL,Obj,FBX,glTF,glTF2",
        .double = false,
        .zlib = false
    });

    // Runs cmake for diligent engine
    const diligent_step = dependencyStep(dep_diligent, "diligent");

    const os_headers = switch (target.result.os.tag) {
        .windows => windows_c_headers,
        .macos, .ios, .tvos, .watchos, .visionos, .maccatalyst => darwin_c_headers,
        .linux => linux_c_headers,

        else => @panic("This platform is not supported by any existing backends.")
    };

    const platform_define = switch (target.result.os.tag) {
        .windows => "PLATFORM_WIN32",
        .macos, .ios, .tvos, .watchos, .visionos, .maccatalyst => "PLATFORM_MACOS",
        .linux => "PLATFORM_LINUX",

        else => @panic("This platform is not supported by any existing backends.")
    };

    const c_src = b.addWriteFiles();
    const assimp_h = c_src.add("assimp.h", assimp_headers);
    const wrapper_h = c_src.add("wrapper.h", os_headers);
    const diligent_h = c_src.add("diligent.h", diligent_headers);

    const translator: Translator =
        .init(dep_translate_c, .{ .c_source_file = wrapper_h, .target = target, .optimize = optimize });
    const assimp_translator: Translator =
        .init(dep_translate_c, .{ .c_source_file = assimp_h, .target = target, .optimize = optimize });

    // diligent.h needs its macros expanded by clang before we pass it thru translate-c
    const diligent_pp = b.addSystemCommand(&.{ "clang", "-E", "-x", "c" });
    diligent_pp.step.dependOn(diligent_step);
    diligent_pp.addArg(b.fmt("-D{s}=1", .{platform_define}));
    diligent_pp.addFileArg(diligent_h);
    diligent_pp.addArg("-I");
    diligent_pp.addDirectoryArg(dep_diligent.namedLazyPath("include"));
    const diligent_h_expanded = diligent_pp.captureStdOut(.{});

    const diligent_translator: Translator =
        .init(dep_translate_c, .{ .c_source_file = diligent_h_expanded, .target = target, .optimize = optimize });
    diligent_translator.run.step.dependOn(&diligent_pp.step);

    const shader_mod = try sokol.shdc.createModule(b, "shaders", dep_sokol.module("sokol"), .{
        .shdc_dep = dep_shdc,
        .input = "src/gpu/shaders/basic.glsl",
        .output = "basic.glsl.zig",
        .slang = .{
            .glsl410 = true,
            .hlsl5 = true,
            .metal_macos = true,
            .wgsl = true
        }
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
            .{ .name = "shaders", .module = shader_mod },
            .{ .name = "c", .module = translator.mod },
            .{ .name = "assimp", .module = assimp_translator.mod },
            .{ .name = "diligent", .module = diligent_translator.mod }
        }
    });

    if (target.result.os.tag == .macos) {
        const dep_zig_objc = b.dependency("zig_objc", .{
            .target = target,
            .optimize = optimize,
            .@"add-paths" = false
        });
        engine_mod.addImport("objc", dep_zig_objc.module("objc"));
    }

    const engine_lib = b.addLibrary(.{
        .name = "engine",
        .root_module = engine_mod,
        .linkage = .static
    });

    // Assimp
    const lib_assimp = dep_assimp.artifact("assimp");
    engine_mod.linkLibrary(lib_assimp);
    engine_mod.addIncludePath(lib_assimp.getEmittedIncludeTree());
    assimp_translator.addIncludePath(lib_assimp.getEmittedIncludeTree());

    // DiligentEngine (Core)
    engine_mod.addIncludePath(dep_diligent.namedLazyPath("include"));
    engine_mod.addLibraryPath(dep_diligent.namedLazyPath("lib-core"));
    diligent_translator.addIncludePath(dep_diligent.namedLazyPath("include"));
    diligent_translator.run.step.dependOn(diligent_step);

    const diligent_lib_dir = dep_diligent.namedLazyPath("lib-core");
    for (diligent_vendor.static_libs) |lib_name| {
        engine_mod.addObjectFile(diligent_lib_dir.path(b, b.fmt("lib{s}.a", .{lib_name})));
    }

    const diligent_vk_static_dir = dep_diligent.namedLazyPath("lib-vk-static-build");
    engine_mod.addObjectFile(diligent_vk_static_dir.path(b, "libDiligent-GraphicsEngineVk-static.a"));

    if (target.result.os.tag == .macos and sdk != null) {
        sdk.?.applyToTranslator(translator);
        sdk.?.applyToTranslator(assimp_translator);
        sdk.?.applyToTranslator(diligent_translator);
        sdk.?.applyToModule(engine_mod);

        engine_mod.linkFramework("OpenGL", .{});
        engine_mod.linkFramework("Cocoa", .{});

        // Sokol
        const scl = dep_sokol.artifact("sokol_clib");
        sdk.?.applyToModule(scl.root_module);

        // Link zlib for assimp
        lib_assimp.root_module.addFrameworkPath(.{ .cwd_relative = sdk.?.frameworks });
        lib_assimp.root_module.addLibraryPath(.{ .cwd_relative = sdk.?.libs });
        lib_assimp.root_module.linkSystemLibrary("z", .{});
    }

    b.installArtifact(engine_lib);
}