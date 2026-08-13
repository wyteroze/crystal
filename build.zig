// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdk_path = b.option([]const u8, "sdk", "Path to macOS SDK (looks something like `MacOSX26.5.sdk`)")
        orelse std.zig.system.darwin.getSdk(b.allocator, b.graph.io, &target.result);

    // this might be a yikes move but SDL3 needs sysroot which is identical to sdk_path
    // and having to pass it twice would be dumb and have no good use, so we do this instead
    b.sysroot = sdk_path;

    const dep_engine = b.dependency("engine", .{ .target = target, .optimize = optimize, .sdk = sdk_path });

    const exe = b.addExecutable(.{
        .name = "crystal",
        .root_module = b.createModule(.{
            .root_source_file = b.path("runtime/src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "engine", .module = dep_engine.module("engine") },
            },
            .link_libc = true
        }),
    });

    exe.root_module.linkLibrary(dep_engine.artifact("engine"));
    b.installArtifact(exe);


    if (target.result.os.tag == .macos and sdk_path != null) {
        const sdk_frameworks = b.pathJoin(&.{ sdk_path.?, "System", "Library", "Frameworks" });
        const sdk_includes = b.pathJoin(&.{ sdk_path.?, "usr", "include" });
        const sdk_libs = b.pathJoin(&.{ "/", "usr", "lib" });

        exe.root_module.addFrameworkPath(.{ .cwd_relative = sdk_frameworks });
        exe.root_module.addIncludePath(.{ .cwd_relative = sdk_includes });
        exe.root_module.addLibraryPath(.{ .cwd_relative = sdk_libs });
    }

    // invoked when running `zig build`
    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
