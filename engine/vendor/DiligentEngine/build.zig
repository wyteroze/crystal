const std = @import("std");

pub const Backend = enum {
    gl,
    d3d11,
    d3d12,
    vulkan,

    pub fn toCFlag(self: Backend) []const u8 {
        return switch (self) {
            .gl => "SUMMIT_OPENGL_BACKEND",
            .vulkan => "SUMMIT_VULKAN_BACKEND",
            .d3d11 => "SUMMIT_D3D11_BACKEND",
            .d3d12 => "SUMMIT_D3D12_BACKEND"
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
        b.addNamedLazyPath("include", b.path("stub-include"));

        b.addNamedLazyPath("lib-core", b.path("stub-lib"));
        b.addNamedLazyPath("lib-vk-static-build", b.path("stub-lib"));

        return;
    }

    const src_path = b.path("src");
    const build_path =  b.path("build");

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
        "-DDILIGENT_BUILD_TOOLS=OFF",
        b.fmt("-DCMAKE_BUILD_TYPE={s}", .{ cmake_build_type }),
        b.fmt("-DCMAKE_CXX_FLAGS=-D{s} -g0 -D{s}=1", .{ backend.toCFlag(), targetToCFlag(target) }),
        boolFlag(b, "DILIGENT_BUILD_SAMPLES", samples),
        boolFlag(b, "DILIGENT_BUILD_TESTS", tests),
        boolFlag(b, "DILIGENT_NO_OPENGL", false),
        boolFlag(b, "DILIGENT_NO_DIRECT3D11", backend != .d3d11),
        boolFlag(b, "DILIGENT_NO_DIRECT3D12", backend != .d3d12),
        boolFlag(b, "DILIGENT_NO_VULKAN", backend != .vulkan)
    });

    const cmake_build = b.addSystemCommand(&.{ "cmake" });
    cmake_build.addArg("--build");
    cmake_build.addDirectoryArg(build_path);
    cmake_build.addArgs(&.{ "--config", cmake_build_type });
    cmake_build.addArgs(&.{ "--parallel", b.fmt("{d}", .{ try std.Thread.getCpuCount() }) });
    cmake_build.step.dependOn(&cmake_configure.step);
    
    const cmake_install = b.addSystemCommand(&.{ "cmake" });
    cmake_install.addArg("--install");
    cmake_install.addDirectoryArg(build_path);
    cmake_install.step.dependOn(&cmake_build.step);

    step.dependOn(&cmake_install.step);
    b.getInstallStep().dependOn(step);

    b.addNamedLazyPath("include", install_out.path(b, "include"));
    b.addNamedLazyPath("lib-core", install_out.path(b, b.pathJoin(&.{ "lib", "DiligentCore", cmake_build_type })));

    const lib_vk_static_path = try build_path.join(b.allocator, "DiligentCore/Graphics/GraphicsEngineVulkan");
    lib_vk_static_path.addStepDependencies(&cmake_install.step);
    b.addNamedLazyPath("lib-vk-static-build", lib_vk_static_path);
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