// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "kebab",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
            .link_libc = true
        }),
    });

    const zsdl = b.dependency("zsdl", .{});
    exe.root_module.addImport("zsdl2", zsdl.module("zsdl2"));
    linkSDLLibs(target, exe);

    const lua = b.dependency("zlua", .{ .target = target, .optimize = optimize, .lang = .lua54 });
    exe.root_module.addImport("zlua", lua.module("zlua"));

    b.installArtifact(exe);

    // invoked when running `zig build`
    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}

fn linkSDLLibs(t: std.Build.ResolvedTarget, e: *std.Build.Step.Compile) void {
    const tag = t.result.os.tag;

    if (tag == .windows) {
        e.root_module.linkSystemLibrary("SDL2", .{});
        e.root_module.linkSystemLibrary("SDL2main", .{});
    } else if (tag == .linux) {
        e.root_module.linkSystemLibrary("SDL2", .{});
    } else if (tag.isDarwin()) {
        e.root_module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include/" });
        e.root_module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/lib/" });
        e.root_module.linkSystemLibrary("SDL2", .{});
    }
}
