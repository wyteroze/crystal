// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub const static_libs = [_][]const u8{
    "slang-compiler",
    "core",
    "compiler-core",
    "slang-cpp-parser"
};

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const skip_cmake = b.option(bool, "skip_cmake", "Skip CMake builds (for ZLS check)") orelse false;

    const step = b.step("slang", "Build slang using CMake");
    if (skip_cmake) {
        b.addNamedLazyPath("include", b.path("stub-include"));
        b.addNamedLazyPath("lib", b.path("stub-lib"));
        return;
    }

    const root = b.build_root;
    const src_path = try root.join(b.allocator, &.{ "src" });
    const build_path = try root.join(b.allocator, &.{ "build" });

    // Building with debug info severely bloats .zig-cache (~1.5gb per build)
    const cmake_build_type = "Release"; _ = optimize; // optimizeModeToCMakeBuildType(optimize);

    const cmake_configure = b.addSystemCommand(&.{ "cmake", "-S", src_path, "-B", build_path, "-G", "Ninja" });
    cmake_configure.setCwd(.{ .cwd_relative = src_path });
    const install_out = cmake_configure.addPrefixedOutputDirectoryArg("-DCMAKE_INSTALL_PREFIX=", "install");

    cmake_configure.addArgs(&.{
        b.fmt("-DCMAKE_BUILD_TYPE={s}", .{ cmake_build_type }),
        "-DSLANG_LIB_TYPE=STATIC",
        boolFlag(b, "SLANG_ENABLE_TESTS", true),
        boolFlag(b, "SLANG_ENABLE_EXAMPLES", true),
        boolFlag(b, "SLANG_ENABLE_GFX", true),
        boolFlag(b, "SLANG_ENABLE_SLANGD", true),
        boolFlag(b, "SLANG_ENABLE_REPLAYER", true),
        boolFlag(b, "SLANG_ENABLE_SLANG_RHI", true),
        boolFlag(b, "SLANG_ENABLE_SLANGI", true),
        boolFlag(b, "SLANG_ENABLE_SLANGC", true),
        boolFlag(b, "SLANG_ENABLE_SLANGRT", true),
        boolFlag(b, "SLANG_ENABLE_SLANG_GLSLANG", false),
        boolFlag(b, "SLANG_ENABLE_SLANG_PROXY", true),
        "-DSLANG_SLANG_LLVM_FLAVOR=DISABLE",
        "-DSLANG_EXCLUDE_DAWN=TRUE",
        "-DSLANG_EXCLUDE_TINT=TRUE"
    });

    const cmake_build = b.addSystemCommand(&.{ "cmake", "--build", build_path, "--config", cmake_build_type, "--target", "all", "--target", "slang-glsl-module", "--parallel", b.fmt("{d}", .{try std.Thread.getCpuCount()}) });
    cmake_build.step.dependOn(&cmake_configure.step);

    const cmake_install = b.addSystemCommand(&.{ "cmake", "--install", build_path, "--config", cmake_build_type, "--component", "Unspecified" });
    cmake_install.step.dependOn(&cmake_build.step);

    const include_path = install_out.path(b, "include");
    include_path.addStepDependencies(&cmake_install.step);

    const lib_path = install_out.path(b, "lib");
    lib_path.addStepDependencies(&cmake_install.step);

    step.dependOn(&cmake_install.step);
    b.getInstallStep().dependOn(step);

    b.addNamedLazyPath("include", include_path);
    b.addNamedLazyPath("lib", lib_path);
    
    b.addNamedLazyPath("lib-build", .{ .cwd_relative = try root.join(b.allocator, &.{ "build", "Debug", "lib" }) });
    b.addNamedLazyPath("lib-miniz", .{ .cwd_relative = try root.join(b.allocator, &.{ "build", "external", "miniz", "libminiz.a" }) });
    b.addNamedLazyPath("lib-cmark", .{ .cwd_relative = try root.join(b.allocator, &.{ "build", "external", "cmark", "src", "libcmark-gfm.a" }) });
    b.addNamedLazyPath("lib-lz4", .{ .cwd_relative = try root.join(b.allocator, &.{ "build", "external", "lz4", "build", "cmake", "liblz4.a" }) });
}

fn optimizeModeToCMakeBuildType(optimize: std.builtin.OptimizeMode) []const u8 {
    return switch (optimize) {
        .Debug => "Debug",
        .ReleaseFast => "Release",
        .ReleaseSafe => "RelWithDebInfo",
        .ReleaseSmall => "MinSizeRel"
    };
}

fn boolFlag(b: *std.Build, name: []const u8, disabled: bool) []const u8 {
    return b.fmt("-D{s}={s}", .{ name, if (disabled) "OFF" else "ON" });
}