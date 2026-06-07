// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl = @import("zsdl2");

const types     = @import("types.zig");
const Platform  = @import("Platform.zig").Platform;
const Renderer  = @import("Renderer.zig").Renderer;
const Mesh      = @import("Mesh.zig").Mesh;
const Sprite    = @import("Sprite.zig").Sprite;
const Camera    = @import("Camera.zig").Camera;
const Instance  = @import("Instance.zig").Instance;

const fps = 120;
const fps_ms = 1000 / fps;
const width = 384;
const height = 360;

fn isPressed(state: []const u8, scancode: sdl.Scancode) bool {
    return state[@intFromEnum(scancode)] != 0;
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var platform = try Platform.init();
    defer platform.deinit();

    var window = try platform.createWindow("kebab", .centered, .{ .x = width*2, .y = height*2 });
    defer window.destroy();

    var camera = Camera.init(0.1, 1000.0, 90.0, @as(f32, @floatFromInt(height)) / @as(f32, @floatFromInt(width)));
    var renderer = try Renderer.init(allocator, window, .{ .x = width, .y = height }, &camera, true);
    defer renderer.deinit();

    var texture = try Sprite.loadFromFile(allocator, io, "src/assets/images/bullymoon.bmp");
    defer texture.deinit(allocator);

    var cubeMesh = try Mesh.loadFromFile(allocator, io, "src/assets/models/bullymoon.obj");
    defer cubeMesh.deinit();

    cubeMesh.texture = &texture;

    var cube = Instance{
        .mesh = &cubeMesh,
        .transform = types.Transform.identity()
    };

    cube.transform.position[2] += 5.0;

    var running = true;
    var lastTimeMs: u64 = sdl.getPerformanceCounter();
    const frequency = @as(f32, @floatFromInt(sdl.getPerformanceFrequency()));

    while (running) {
        const currentTime = sdl.getPerformanceCounter();
        const dt = @as(f32, @floatFromInt(currentTime - lastTimeMs)) / frequency;
        lastTimeMs = currentTime;

        // events
        var event: sdl.Event = undefined;
        while (sdl.pollEvent(&event)) {
            switch (event.type) {
                .quit => running = false,
                .mousemotion => {
                    camera.transform.rotation[0] += @as(f32, @floatFromInt(event.motion.yrel));
                    camera.transform.rotation[1] += @as(f32, @floatFromInt(event.motion.xrel));
                },
                .keydown => {
                    switch (event.key.keysym.sym) {
                        .escape => {
                            try sdl.showCursor(.disable);
                        },

                        else => {}
                    }
                },
                .mousebuttondown => {
                    if (event.button.state == .pressed) {
                        try sdl.showCursor(.enable);
                    }
                },

                else => {}
            }
        }

        const state = sdl.getKeyboardState();
        const factor = 2;

        const ratio = @as(types.Vec3_SIMD, @splat(dt * factor));
        if (isPressed(state, .w))                               camera.transform.position += camera.getLookDirection() * ratio;
        if (isPressed(state, .s))                               camera.transform.position -= camera.getLookDirection() * ratio;
        if (isPressed(state, .a))                               camera.transform.position -= camera.getRightDirection() * ratio;
        if (isPressed(state, .d))                               camera.transform.position += camera.getRightDirection() * ratio;
        if (isPressed(state, .space) or isPressed(state, .e))   camera.transform.position += camera.getUpDirection() * ratio;
        if (isPressed(state, .lshift) or isPressed(state, .q))  camera.transform.position -= camera.getUpDirection() * ratio;

        // object updates
        //cube.transform.rotation += types.Vec3_SIMD{ dt * 45, 0, dt * 45 };

        // make sure the camera isn't funky
        std.debug.print("{any}\n", .{camera.transform.rotation[0]});

        // rendering
        renderer.drawBackground();
        try renderer.drawMesh(cube.mesh, &cube.transform);
        renderer.visualizeAxes();

        try renderer.present();
    }
}
