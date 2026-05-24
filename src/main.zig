const std = @import("std");
const sdl = @import("zsdl2");

const Vec2_u32 = @Vector(2, u32);
const Vec2_f32 = @Vector(2, f32);
const Vec3_f32 = @Vector(3, f32);
const Vec3_u32 = @Vector(3, u32);
const Framebuffer = [width * height]u32;
const Face = struct { start: u32, count: u32 };

const width = 256;
const height = 256;
const background_color = Vec3_u32{ 0, 0, 0 };

const vertices = [8] Vec3_f32 {
    Vec3_f32 { 0.25, 0.25, 0.25 },
    Vec3_f32 { -0.25, 0.25, 0.25 },
    Vec3_f32 { -0.25, -0.25, 0.25 },
    Vec3_f32 { 0.25, -0.25, 0.25 },

    Vec3_f32 { 0.25, 0.25, -0.25 },
    Vec3_f32 { -0.25, 0.25, -0.25 },
    Vec3_f32 { -0.25, -0.25, -0.25 },
    Vec3_f32 { 0.25, -0.25, -0.25 },
};

const index_buffer = [_]u32{ 0,1,2,3, 4,5,6,7, 0,4, 1,5, 2,6, 3,7 };
const faces = [_] Face {
    .{ .start = 0,  .count = 4 },
    .{ .start = 4,  .count = 4 },
    .{ .start = 8,  .count = 2 },
    .{ .start = 10, .count = 2 },
    .{ .start = 12, .count = 2 },
    .{ .start = 14, .count = 2 },
};

fn clearBackground(fb: *Framebuffer) void {
    for (fb) |*pixel| {
        pixel.* = 0xFF_00_00_00 | (background_color[0] << 16) | (background_color[1] << 8) | (background_color[2]);
    }
}

fn point(fb: *Framebuffer, p: Vec2_u32) void {
    if ((0 <= p[0] and p[0] < width) and (0 <= p[1] and p[1] < height)) {
        fb.*[p[1] * width + p[0]] = 0xFF_00_FF_00;
    }
}

fn line(fb: *Framebuffer, p1: Vec2_u32, p2: Vec2_u32) void {
    var x0 = @as(i32, @intCast(p1[0]));
    var y0 = @as(i32, @intCast(p1[1]));
    const x1 = @as(i32, @intCast(p2[0]));
    const y1 = @as(i32, @intCast(p2[1]));

    const dx = @as(i32, @intCast(@abs(x1 - x0)));
    const dy = @as(i32, @intCast(@abs(y1 - y0)));
    const sx = @as(i32, if (x0 < x1) 1 else -1);
    const sy = @as(i32, if (y0 < y1) 1 else -1);
    var err = dx - dy;

    while (true) {
        point(fb, Vec2_u32{ @intCast(x0), @intCast(y0) });
        if (x0 == x1 and y0 == y1) break;

        const e2 = 2 * err;
        if (e2 > -dy) { err -= dy; x0 += sx; }
        if (e2 < dx) { err += dx; y0 += sy; }
    }
}

fn screen(p: Vec2_f32) !Vec2_u32 {
    const x = (p[0] + 1) / 2 * @as(f32, @floatFromInt(width));
    const y = (1 - (p[1] + 1) / 2) * @as(f32, @floatFromInt(height));

    const w: f32 = @floatFromInt(width);
    const h: f32 = @floatFromInt(height);

    if (x >= 0 and x < w and y >= 0 and y < h) {
        return Vec2_u32{
            @intFromFloat(x),
            @intFromFloat(y),
        };
    }

    return error.PointOutOfBounds;
}

fn project(p: Vec3_f32) Vec2_f32 {
    return Vec2_f32 {
        p[0] / p[2],
        p[1] / p[2]
    };
}

fn rotateXZ(p: Vec3_f32, angle: f32) Vec3_f32 {
    const c = @cos(angle);
    const s = @sin(angle);

    return Vec3_f32 {
        p[0] * c - p[2] * s,
        p[1],
        p[0] * s + p[2] * c
    };
}

pub fn main() !void {
    try sdl.init(.{ .video = true });
    defer sdl.quit();

    const window = try sdl.Window.create("kebab",
        sdl.Window.pos_centered,
        sdl.Window.pos_centered,
        width*2, height*2,
        .{ .resizable = true }
    );
    defer window.destroy();

    const renderer = try sdl.Renderer.create(window, null, .{ .accelerated = true });
    defer renderer.destroy();

    const texture = try sdl.createTexture(renderer, .argb8888, .streaming, width, height);
    defer texture.destroy();

    var framebuffer: Framebuffer = undefined;

    var running = true;
    var lastTime: u32 = 0;
    var dz: f32 = 1;
    var angle: f32 = 0;

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

        { // render
            const dt = @as(f32, @floatFromInt(sdl.getTicks() - lastTime)) / 1000.0;
            dz += 0;
            angle += std.math.pi * dt;

            clearBackground(&framebuffer);

            for (faces) |f| {
                for (0..f.count) |i| {
                    const a_idx = index_buffer[f.start + i];
                    const b_idx = index_buffer[f.start + (i + 1) % f.count];

                    const a = vertices[@as(usize, a_idx)];
                    const b = vertices[@as(usize, b_idx)];

                    line(&framebuffer,
                        screen(project(rotateXZ(a, angle) + Vec3_f32{ 0, 0, dz })) catch continue,
                        screen(project(rotateXZ(b, angle) + Vec3_f32{ 0, 0, dz })) catch continue
                    );
                }
            }

            lastTime = sdl.getTicks();
        }

        { // upload and present
            try texture.update(null, &framebuffer, width * @sizeOf(u32));
            try renderer.copy(texture, null, null);

            renderer.present();
        }
    }
}
