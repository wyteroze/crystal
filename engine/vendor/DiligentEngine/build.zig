const std = @import("std");

pub const Backend = enum {
    gl,
    d3d11,
    d3d12,
    vulkan,

    pub fn toCFlag(self: Backend) []const u8 {
        return switch (self) {
            .gl => "CRYSTAL_OPENGL_BACKEND",
            .vulkan => "CRYSTAL_VULKAN_BACKEND",
            .d3d11 => "CRYSTAL_D3D11_BACKEND",
            .d3d12 => "CRYSTAL_D3D12_BACKEND"
        };
    }
};

pub fn targetToCFlag(target: std.Build.ResolvedTarget) []const u8 {
    return switch (target.result.os.tag) {
        .wasi => "PLATFORM_WEB",
        .windows => "PLATFORM_WIN32",
        .macos, .maccatalyst => "PLATFORM_MACOS",
        .ios => "PLATFORM_IOS", 
        .tvos => "PLATFORM_TVOS", 
        .visionos => "PLATFORM_VISIONOS",
        .linux => "PLATFORM_LINUX",

        else => @panic("This platform is not supported by any existing backends.")
    };
}

pub const static_libs = [_][]const u8{
    "DiligentCore", "glslang", "SPIRV", "SPIRV-Tools",
    "SPIRV-Tools-opt", "spirv-cross-core", "volk", "xxhash",
    "GenericCodeGen", "MachineIndependent", "OSDependent"
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const backend = b.option(Backend, "backend", "Backend to use\n(default: gl)") orelse .gl;
    const samples = b.option(bool, "samples", "Build samples") orelse false;
    const tests = b.option(bool, "tests", "Build tests") orelse false;
    const skip_cmake = b.option(bool, "skip_cmake", "Skip CMake builds (for ZLS check)") orelse false;

    const step = b.step("diligent", "Build DiligentEngine using CMake");

    if (skip_cmake) {
        const root = b.build_root;

        const stub_include = try root.join(b.allocator, &.{"stub-include"});
        b.addNamedLazyPath("include", b.path("stub-include"));
        _ = stub_include;

        b.addNamedLazyPath("lib-core", b.path("stub-lib"));
        b.addNamedLazyPath("lib-vk-static-build", b.path("stub-lib"));

        return;
    }

    const root = b.build_root;
    const src_path = try root.join(b.allocator, &.{ "src" });
    const build_path = try root.join(b.allocator, &.{ "build" });

    const install_prefix = try root.join(b.allocator, &.{ "install" });
    const cmake_build_type = "RelWithDebInfo"; _ = optimize; // optimizeModeToCMakeBuildType(optimize);

    const cmake_configure = b.addSystemCommand(&.{ "cmake", "-S", src_path, "-B", build_path, "-G", "Ninja" });
    cmake_configure.setCwd(.{ .cwd_relative = src_path });
    cmake_configure.addArgs(&.{
        "-DDILIGENT_BUILD_TOOLS=OFF",
        b.fmt("-DCMAKE_INSTALL_PREFIX={s}", .{install_prefix}),
        b.fmt("-DCMAKE_BUILD_TYPE={s}", .{ cmake_build_type }),
        b.fmt("-DCMAKE_CXX_FLAGS=-D{s} -g0 -D{s}=1 -DCRYSTAL_DILIGENT_INCLUDE={s}", .{ 
            backend.toCFlag(), 
            targetToCFlag(target),
            b.pathJoin(&.{ install_prefix, "include" })
        }),
        boolFlag(b, "DILIGENT_BUILD_SAMPLES", samples),
        boolFlag(b, "DILIGENT_BUILD_TESTS", tests),
        boolFlag(b, "DILIGENT_NO_OPENGL", false),
        boolFlag(b, "DILIGENT_NO_DIRECT3D11", backend != .d3d11),
        boolFlag(b, "DILIGENT_NO_DIRECT3D12", backend != .d3d12),
        boolFlag(b, "DILIGENT_NO_VULKAN", backend != .vulkan)
    });

    const cmake_build = b.addSystemCommand(&.{ "cmake", "--build", build_path });
    cmake_build.addArgs(&.{ "--config", cmake_build_type, "--parallel", b.fmt("{d}", .{ try std.Thread.getCpuCount() }) });
    cmake_build.step.dependOn(&cmake_configure.step);

    const cmake_install = b.addSystemCommand(&.{ "cmake", "--install", build_path });
    cmake_install.step.dependOn(&cmake_build.step);

    step.dependOn(&cmake_install.step);
    b.getInstallStep().dependOn(step);

    const include_lazy_path = try b.allocator.create(std.Build.GeneratedFile);
    include_lazy_path.* = .{ .step = &cmake_install.step, .path = b.pathJoin(&.{ install_prefix, "include" }) };
    b.addNamedLazyPath("include", .{ .generated = .{ .file = include_lazy_path } });

    const lib_core_lazy_path = try b.allocator.create(std.Build.GeneratedFile);
    lib_core_lazy_path.* = .{ .step = &cmake_install.step, .path = b.pathJoin(&.{ install_prefix, "lib", "DiligentCore", cmake_build_type }) };
    b.addNamedLazyPath("lib-core", .{ .generated = .{ .file = lib_core_lazy_path } });

    const vk_static_lazy_path = try b.allocator.create(std.Build.GeneratedFile);
    vk_static_lazy_path.* = .{
        .step = &cmake_build.step,
        .path = b.pathJoin(&.{ build_path, "DiligentCore", "Graphics", "GraphicsEngineVulkan" })
    };
    b.addNamedLazyPath("lib-vk-static-build", .{ .generated = .{ .file = vk_static_lazy_path } });
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
    return b.fmt("-D{s}={s}", .{ name, if (disabled) "ON" else "OFF" });
}