// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl = @import("zsdl2");
const mem = std.mem;

const Platform = @import("Platform.zig").Platform;
const Renderer = @import("Renderer.zig").Renderer;
const Mesh = @import("Mesh.zig").Mesh;
const Scene = @import("Scene.zig").Scene;
const Instance = @import("Instance.zig").Instance;
const types = @import("Types.zig");

const window_size = types.Size2D{ .width = 800, .height = 600 };

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var platform = try Platform.init(allocator);
    defer platform.deinit();

    const window = try platform.createWindow("kebab", .centered, window_size);
    var renderer = try Renderer.init(allocator, window, window_size);
    defer renderer.deinit();

    var scene = try Scene.init(allocator);
    defer scene.deinit();

    var cube_mesh = try Mesh.init(allocator,
        &[_]@Vector(3, f32) {
            .{ 0.25, 0.25, 0.25 },
            .{ -0.25, 0.25, 0.25 },
            .{ -0.25, -0.25, 0.25 },
            .{ 0.25, -0.25, 0.25 },

            .{ 0.25, 0.25, -0.25 },
            .{ -0.25, 0.25, -0.25 },
            .{ -0.25, -0.25, -0.25 },
            .{ 0.25, -0.25, -0.25 },
        },

        &[_]u32 {
            // front
            0, 1, 2,
            0, 2, 3,

            // back
            4, 6, 5,
            4, 7, 6,

            // left
            1, 5, 6,
            1, 6, 2,

            // right
            4, 0, 3,
            4, 3, 7,

            // top
            4, 5, 1,
            4, 1, 0,

            // bottom
            3, 2, 6,
            3, 6, 7,
        },

        &[_]types.Face {
            .{ .start = 0,  .count = 6 },  // front
            .{ .start = 6,  .count = 6 },  // back
            .{ .start = 12, .count = 6 },  // left
            .{ .start = 18, .count = 6 },  // right
            .{ .start = 24, .count = 6 },  // top
            .{ .start = 30, .count = 6 },  // bottom
        }
    );
    defer cube_mesh.deinit();
    try scene.instances.append(allocator, Instance{
        .mesh = &cube_mesh,
        .transform = types.Transform{
            .position = @Vector(3, f32){ 0, 0, 1 }
        }}
    );

    var running = true;
    var lastTime: u32 = 0;

    while (running) {
        { // events
            var event: sdl.Event = undefined;
            while (sdl.pollEvent(&event)) {
                switch (event.type) {
                    .quit => running = false,
                    .keydown => {
                        if (event.key.keysym.sym == .escape) running = false;
                    },

                    else => {}
                }
            }
        }

        const before = sdl.getPerformanceCounter();

        { // render
            renderer.clearBackground();
            const dt = @as(f32, @floatFromInt(sdl.getTicks() - lastTime)) / 1000.0;

            for (scene.instances.items) |*inst| {
                inst.update(dt);
                renderer.renderMesh(inst.mesh, inst.transform);
            }

            try renderer.draw();
            lastTime = sdl.getTicks();
        }

        const after = sdl.getPerformanceCounter();
        std.debug.print("render ms: {any}\n", .{1000*(@as(f32, @floatFromInt(after-before))/@as(f32, @floatFromInt(sdl.getPerformanceFrequency())))});
    }
}
