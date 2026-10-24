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

    const src_path = b.path("src");
    const build_path = b.path("build");

    // Building with debug info severely bloats .zig-cache (~1.5gb per build)
    const cmake_build_type = "Release"; _ = optimize; // optimizeModeToCMakeBuildType(optimize);

    const cmake_configure = b.addSystemCommand(&.{ "cmake" });
    cmake_configure.addArg("-S");
    cmake_configure.addDirectoryArg2(src_path, .{ .make_absolute = true });
    cmake_configure.addArg("-B");
    cmake_configure.addDirectoryArg2(build_path, .{ .make_absolute = true });
    cmake_configure.addArgs(&.{ "-G", "Ninja" });
    cmake_configure.setCwd(src_path);

    const install_out = cmake_configure.addPrefixedOutputDirectoryArg("-DCMAKE_INSTALL_PREFIX=", "install");

    cmake_configure.addArgs(&.{
        b.fmt("-DCMAKE_BUILD_TYPE={s}", .{ cmake_build_type }),
        "-DSLANG_LIB_TYPE=STATIC",
        "-DCMAKE_CXX_FLAGS_RELEASE=-O3 -DNDEBUG -g0",
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
        boolFlag(b, "SLANG_ENABLE_RELEASE_DEBUG_INFO", true),
        "-DSLANG_SLANG_LLVM_FLAVOR=DISABLE",
        "-DSLANG_EXCLUDE_DAWN=TRUE",
        "-DSLANG_EXCLUDE_TINT=TRUE"
    });

    const cmake_build = b.addSystemCommand(&.{ "cmake" });
    cmake_build.addArg("--build");
    cmake_build.addDirectoryArg(build_path);
    cmake_build.addArgs(&.{ "--config", cmake_build_type });
    cmake_build.addArgs(&.{ "--target", "all" });
    cmake_build.addArgs(&.{ "--target", "slang-glsl-module" });
    cmake_build.addArgs(&.{ "--parallel", b.fmt("{d}", .{ try std.Thread.getCpuCount() }) });
    cmake_build.step.dependOn(&cmake_configure.step);

    const cmake_install = b.addSystemCommand(&.{ "cmake" });
    cmake_install.addArg("--install");
    cmake_install.addDirectoryArg(build_path);
    cmake_install.addArgs(&.{ "--config", cmake_build_type });
    cmake_install.addArgs(&.{ "--component", "Unspecified" });
    cmake_install.step.dependOn(&cmake_build.step);

    const include_path = install_out.path(b, "include");
    include_path.addStepDependencies(&cmake_install.step);

    const lib_path = install_out.path(b, "lib");
    lib_path.addStepDependencies(&cmake_install.step);

    step.dependOn(&cmake_install.step);
    b.getInstallStep().dependOn(step);

    b.addNamedLazyPath("include", include_path);
    b.addNamedLazyPath("lib", lib_path);
    
    b.addNamedLazyPath("lib-build", b.path("build/Release/lib/"));
    b.addNamedLazyPath("lib-miniz", b.path("build/external/miniz/libminiz.a"));
    b.addNamedLazyPath("lib-cmark", b.path("build/external/cmark/src/libcmark-gfm.a"));
    b.addNamedLazyPath("lib-lz4", b.path("build/external/lz4/build/cmake/liblz4.a"));
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