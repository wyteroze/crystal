// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdk_path = b.option([]const u8, "sdk", "Path to macOS SDK (looks something like `MacOSX26.5.sdk`)")
        orelse std.zig.system.darwin.getSdk(b.allocator, b.graph.io, &target.result);

    const backend = b.option(enum { gl, d3d11, d3d12, vulkan }, "backend", "Backend to use\n(default: gl)")
        orelse .gl;

    // this might be a yikes move but SDL3 needs sysroot which is identical to sdk_path
    // and having to pass it twice would be dumb and have no good use, so we do this instead
    b.sysroot = sdk_path;

    const dep_engine = b.dependency("engine", .{ .target = target, .optimize = optimize, .sdk = sdk_path, .backend = backend });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("runtime/src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "engine", .module = dep_engine.module("engine") }
        },
        .link_libc = true
    });

    exe_mod.linkLibrary(dep_engine.artifact("engine"));

    const exe = b.addExecutable(.{
        .name = "crystal",
        .root_module = exe_mod
    });
    b.installArtifact(exe);

    // For ZLS
    const exe_check = b.addExecutable(.{ .name = "crystal", .root_module = exe_mod });

    const check = b.step("check", "Check if crystal compiles");
    check.dependOn(&exe_check.step);

    if (target.result.os.tag == .macos and sdk_path != null) {
        const sdk_frameworks = b.pathJoin(&.{ sdk_path.?, "System", "Library", "Frameworks" });
        const sdk_includes = b.pathJoin(&.{ sdk_path.?, "usr", "include" });
        const sdk_libs = b.pathJoin(&.{ "/", "usr", "lib" });

        exe.root_module.addFrameworkPath(.{ .cwd_relative = sdk_frameworks });
        exe.root_module.addIncludePath(.{ .cwd_relative = sdk_includes });
        exe.root_module.addLibraryPath(.{ .cwd_relative = sdk_libs });
    }

    // Docgen
    const docgen_dep = b.dependency("docgen", .{
        .target = b.graph.host, // this is running on our machine, not being distributed
        .optimize = .Debug
    });
    const docgen_exe = docgen_dep.artifact("docgen");

    const run_docgen = b.addRunArtifact(docgen_exe);
    run_docgen.addArg("--registry");
    run_docgen.addFileArg(b.path("engine/src/scripting/linker/registry.zig"));
    run_docgen.addArg("--out");
    run_docgen.addDirectoryArg(b.path("docs/api"));

    const docs_step = b.step("docs", "Regenerate the Crystal Lua API docs from source.");
    docs_step.dependOn(&run_docgen.step);

    // invoked when running `zig build`
    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}