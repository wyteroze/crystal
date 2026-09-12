// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const sokol = @import("sokol");
const Translator = @import("translate_c").Translator;
const diligent_vendor = @import("diligent_engine");
const slang_vendor = @import("slang");

// The newlines are needed for these headers so concatenating doesn't break them
const assimp_headers =
    \\#include "assimp/cimport.h"
    \\#include "assimp/scene.h"
    \\#include "assimp/postprocess.h"
    \\
;

// These 3 following headers are specifically for
// implementations of each backend in os/backends/*os name*.
// Headers for other reasons most likely have a better place
// (though I couldn't tell you where, maybe just create a new place for it)
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

const CompileCommands = struct {
    const Command = struct {
        b: *std.Build = undefined, // This gets set when CompileCommands.addCommand is called
        cmd: []const u8,
        std: []const u8,
        file_path: std.Build.LazyPath,
        cxx_args: []const []const u8 = &.{},
        include_paths: []const std.Build.LazyPath = &.{},

        pub fn format(
            self: Command,
            writer: *std.Io.Writer,
        ) !void {
            //  {{
            //      "directory": "{s}",
            //      "file": "{s}",
            //      "arguments": [
            //          "clang++", "-std=c++17",
            //          "-D{s}=1", "-D{s}",
            //          "-I{s}", "-I{s}",
            //          "-c", "{s}"
            //      ]
            //  }}

            try writer.writeAll("{"); {
                try writer.print("\"directory\": \"{s}\",", .{ self.b.path(".").getPath(self.b) });
                try writer.print("\"file\": \"{s}\",", .{ self.file_path.getPath(self.b) });

                try writer.writeAll("\"arguments\": ["); {
                    try writer.print("\"{s}\", \"-std={s}\"", .{ self.cmd, self.std });
                    for (self.cxx_args) |a| try writer.print(", \"-D{s}\"", .{ a });
                    for (self.include_paths) |path| try writer.print(", \"-I{s}\"", .{ path.getPath(self.b) });
                    try writer.print(", \"-c\", \"{s}\"", .{ self.file_path.getPath(self.b) });
                } try writer.writeAll("]");
            } try writer.writeAll("}");
        }
    };

    b: *std.Build,
    commands: std.ArrayList(Command),
    step: *std.Build.Step,

    pub fn init(b: *std.Build) CompileCommands {
        return .{
            .b = b,
            .commands = .empty,
            .step = b.step("compile_commands", "Generate compile_commands.json")
        };
    }

    pub fn addCommand(self: *CompileCommands, command: Command) void {
        const cmd = self.b.allocator.create(Command) catch @panic("Out of memory");
        cmd.* = command;
        cmd.b = self.b;

        self.commands.append(self.b.allocator, cmd.*) catch @panic("Out of memory");
    }

    pub fn finalize(self: *CompileCommands) !void {
        var allocating_writer: std.Io.Writer.Allocating = .init(self.b.allocator);
        const writer = &allocating_writer.writer;

        try writer.writeAll("[");
        for (self.commands.items, 0..) |cmd, i| {
            if (i != 0) try writer.writeAll(",");
            try writer.print("{f}", .{ cmd });
        }
        try writer.writeAll("]");
        
        const write_cc = self.b.addWriteFile("compile_commands.json", try allocating_writer.toOwnedSlice());
        const update = self.b.addUpdateSourceFiles();
        update.addCopyFileToSource(write_cc.getDirectory().path(self.b, "compile_commands.json"), ".clangd-db/compile_commands.json");
        self.step.dependOn(&update.step);
    }
};

// There is like a 99% chance this does not compile on anything other than mac because of missing libraries
// It shouldn't be too hard to fix though. I'm just focused on the engine for now
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdk_path = b.option([]const u8, "sdk", "Path to macOS SDK (looks something like MacOSX26.5.sdk)")
        orelse std.zig.system.darwin.getSdk(b.allocator, b.graph.io, &target.result);
    const sdk: ?SdkPaths = .resolve(b, sdk_path);
    const backend = b.option(diligent_vendor.Backend, "backend", "Backend to use\n(default: gl)") orelse .gl;
    const skip_cmake = b.option(bool, "skip_cmake", "Skip CMake builds (for ZLS check)") orelse false;
    
    const dep_sdl3 = b.dependency("sdl3", .{ .target = target, .optimize = optimize });
    const dep_zlua = b.dependency("zlua", .{ .target = target, .optimize = optimize, .lang = .lua55 });
    const dep_toml = b.dependency("toml", .{ .target = target, .optimize = optimize });
    const dep_zigimg = b.dependency("zigimg", .{ .target = target, .optimize = optimize });
    const dep_translate_c = b.dependency("translate_c", .{});
    const dep_diligent = b.dependency("diligent_engine", 
        .{ .optimize = optimize, .backend = backend, .skip_cmake = skip_cmake });
    const dep_slang = b.dependency("slang", 
        .{ .optimize = optimize, .skip_cmake = skip_cmake });
    const dep_assimp = b.dependency("zig_assimp", .{
        .target = target, .optimize = optimize, .formats = "STL,Obj,FBX,glTF,glTF2", .double = false, .zlib = false });

    // Runs cmake for diligent engine
    const diligent_step = dependencyStep(dep_diligent, "diligent");

    // Runs cmake for slang
    const slang_step = dependencyStep(dep_slang, "slang");

    const os_headers = switch (target.result.os.tag) {
        .windows => windows_c_headers,
        .macos, .ios, .tvos, .watchos, .visionos, .maccatalyst => darwin_c_headers,
        .linux => linux_c_headers,

        else => @panic("This platform is not supported by any existing backends.")
    };

    const c_src = b.addWriteFiles();
    const assimp_h = c_src.add("assimp.h", assimp_headers);
    const wrapper_h = c_src.add("wrapper.h", os_headers);

    const translator: Translator =
        .init(dep_translate_c, .{ .name = "Translate system headers", .c_source_file = wrapper_h, .target = target, .optimize = optimize });
    const assimp_translator: Translator =
        .init(dep_translate_c, .{ .name = "Translate assimp", .c_source_file = assimp_h, .target = target, .optimize = optimize });

    var compile_commands: CompileCommands = .init(b);
    defer compile_commands.finalize() catch @panic("Out of memory");

    const diligent_mod = blk: {
        if (skip_cmake) {
            break :blk b.createModule(.{
                .root_source_file = null,
                .target = target,
                .optimize = optimize,
            });
        }

        const diligent_glue_translate: Translator = .init(dep_translate_c, .{
            .c_source_file = b.path("src/gpu/glue/diligent/diligent.h"),
            .target = target,
            .optimize = optimize
        });

        const diligent_glue_cpp_path = b.path("src/gpu/glue/diligent/diligent.cpp");

        diligent_glue_translate.addIncludePath(b.path("src/gpu/glue/diligent"));
        diligent_glue_translate.addIncludePath(dep_diligent.namedLazyPath("include"));
        diligent_glue_translate.mod.link_libcpp = true;
        diligent_glue_translate.mod.addCSourceFile(.{
            .file = diligent_glue_cpp_path,
            .flags = &.{ 
                b.fmt("-D{s}=1", .{ diligent_vendor.targetToCFlag(target) }), 
                b.fmt("-D{s}", .{ backend.toCFlag() }),
                "-std=c++17" 
            },
        });

        diligent_step.dependOn(compile_commands.step);
        compile_commands.addCommand(.{
            .cmd = "clang++", .std = "c++17",
            .file_path = diligent_glue_cpp_path,
            .cxx_args = &.{
                b.fmt("{s}=1", .{ diligent_vendor.targetToCFlag(target) }),
                b.fmt("{s}", .{ backend.toCFlag() }),
            },
            .include_paths = &.{
                b.path("vendor/DiligentEngine/install/include"),
                b.path("src/gpu/glue/diligent/")
            }
        });

        if (target.result.os.tag == .macos and sdk != null) {
            sdk.?.applyToTranslator(diligent_glue_translate);
        }

        diligent_glue_translate.run.step.dependOn(diligent_step);
        break :blk diligent_glue_translate.mod;
    };

    const slang_mod = blk: {
        if (skip_cmake) {
            break :blk b.createModule(.{
                .root_source_file = null,
                .target = target,
                .optimize = optimize,
            });
        }

        const slang_glue_translate: Translator = .init(dep_translate_c, .{
            .c_source_file = b.path("src/gpu/glue/slang/glue_slang.h"),
            .target = target,
            .optimize = optimize
        });

        const slang_glue_cpp_path = b.path("src/gpu/glue/slang/slang.cpp");

        slang_glue_translate.addIncludePath(b.path("src/gpu/glue/slang"));
        slang_glue_translate.addIncludePath(dep_slang.namedLazyPath("include"));
        slang_glue_translate.mod.link_libcpp = true;
        slang_glue_translate.mod.addCSourceFile(.{
            .file = slang_glue_cpp_path,
            .flags = &.{ 
                "-std=c++17" 
            },
        });

        compile_commands.addCommand(.{
            .cmd = "clang++", .std = "c++17",
            .file_path = slang_glue_cpp_path,
            .include_paths = &.{
                b.path("vendor/slang/build/Release/include"),
                b.path("src/gpu/glue/slang/")
            }
        });

        slang_step.dependOn(compile_commands.step);

        if (target.result.os.tag == .macos and sdk != null) {
            sdk.?.applyToTranslator(slang_glue_translate);
        }

        slang_glue_translate.run.step.dependOn(slang_step);
        break :blk slang_glue_translate.mod;
    };

    const engine_mod = b.addModule("engine", .{
        .root_source_file = b.path("src/engine.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sdl3", .module = dep_sdl3.module("sdl3") },
            .{ .name = "zlua", .module = dep_zlua.module("zlua") },
            .{ .name = "toml", .module = dep_toml.module("toml") },
            .{ .name = "zigimg", .module = dep_zigimg.module("zigimg") },
            .{ .name = "c", .module = translator.mod },
            .{ .name = "assimp", .module = assimp_translator.mod },
            .{ .name = "diligent", .module = diligent_mod },
            .{ .name = "slang", .module = slang_mod }
        }
    });

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
    if (!skip_cmake) {
        engine_mod.addIncludePath(dep_diligent.namedLazyPath("include"));
        engine_mod.addLibraryPath(dep_diligent.namedLazyPath("lib-core"));

        const diligent_lib_dir = dep_diligent.namedLazyPath("lib-core");
        for (diligent_vendor.static_libs) |lib_name| {
            engine_mod.addObjectFile(diligent_lib_dir.path(b, b.fmt("lib{s}.a", .{lib_name})));
        }

        const diligent_vk_static_dir = dep_diligent.namedLazyPath("lib-vk-static-build");
        engine_mod.addObjectFile(diligent_vk_static_dir.path(b, "libDiligent-GraphicsEngineVk-static.a"));
    }

    // Slang
    if (!skip_cmake) {
        engine_mod.addIncludePath(dep_slang.namedLazyPath("include"));
        engine_mod.addLibraryPath(dep_slang.namedLazyPath("lib"));

        const slang_lib_dir = dep_slang.namedLazyPath("lib-build");
        for (slang_vendor.static_libs) |lib_name| {
            engine_mod.addObjectFile(slang_lib_dir.path(b, b.fmt("lib{s}.a", .{ lib_name })));
        }

        engine_mod.addObjectFile(dep_slang.namedLazyPath("lib-miniz"));
        engine_mod.addObjectFile(dep_slang.namedLazyPath("lib-cmark"));
        engine_mod.addObjectFile(dep_slang.namedLazyPath("lib-lz4"));
    }

    if (target.result.os.tag == .macos and sdk != null) {
        sdk.?.applyToTranslator(translator);
        sdk.?.applyToTranslator(assimp_translator);
        sdk.?.applyToModule(engine_mod);

        engine_mod.linkFramework("CoreVideo", .{});
        engine_mod.linkFramework("Cocoa", .{});
        engine_mod.linkFramework("OpenGL", .{});
        engine_mod.linkFramework("IOKit", .{});
        engine_mod.linkFramework("CoreServices", .{});

        // Link zlib for assimp
        lib_assimp.root_module.addFrameworkPath(.{ .cwd_relative = sdk.?.frameworks });
        lib_assimp.root_module.addLibraryPath(.{ .cwd_relative = sdk.?.libs });
        lib_assimp.root_module.linkSystemLibrary("z", .{});
    }

    b.installArtifact(engine_lib);
}