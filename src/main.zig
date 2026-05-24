// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl = @import("zsdl2");
const mem = std.mem;

const Vec2_i32 = @Vector(2, i32);
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

const index_buffer = [_] u32 {
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
};

const faces = [_] Face {
    .{ .start = 0,  .count = 6 },  // front
    .{ .start = 6,  .count = 6 },  // back
    .{ .start = 12, .count = 6 },  // left
    .{ .start = 18, .count = 6 },  // right
    .{ .start = 24, .count = 6 },  // top
    .{ .start = 30, .count = 6 },  // bottom
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

fn fillTri(fb: *Framebuffer, a: Vec2_u32, b: Vec2_u32, c: Vec2_u32, color: u32) void {
    // cast cast cast sahur
    const ai = Vec2_i32{ @intCast(a[0]), @intCast(a[1]) };
    const bi = Vec2_i32{ @intCast(b[0]), @intCast(b[1]) };
    const ci = Vec2_i32{ @intCast(c[0]), @intCast(c[1]) };

    // sort from Y ascending
    var p = [3]Vec2_i32{ ai, bi, ci };
    if (p[0][1] > p[1][1]) mem.swap(Vec2_i32, &p[0], &p[1]);
    if (p[1][1] > p[2][1]) mem.swap(Vec2_i32, &p[1], &p[2]);
    if (p[0][1] > p[1][1]) mem.swap(Vec2_i32, &p[0], &p[1]);

    fillBottomTri(fb, p[0], p[1], p[2], color);
    fillTopTri(fb, p[0], p[1], p[2], color);
}

fn fillBottomTri(fb: *Framebuffer, top: Vec2_i32, mid: Vec2_i32, bot: Vec2_i32, color: u32) void {
    const dy_long  = bot[1] - top[1];
    const dy_short = mid[1] - top[1];
    if (dy_short == 0) {
        return;
    }

    const y_start = @max(top[1], 0);
    const y_end   = @min(mid[1], @as(i32, @intCast(height)));

    var y = y_start;
    while (y < y_end) : (y += 1) {
        const t_long  = @as(f32, @floatFromInt(y - top[1])) / @as(f32, @floatFromInt(dy_long));
        const t_short = @as(f32, @floatFromInt(y - top[1])) / @as(f32, @floatFromInt(dy_short));

        var x_left  = top[0] + @as(i32, @intFromFloat(t_long  * @as(f32, @floatFromInt(bot[0] - top[0]))));
        var x_right = top[0] + @as(i32, @intFromFloat(t_short * @as(f32, @floatFromInt(mid[0] - top[0]))));

        if (x_left > x_right) mem.swap(i32, &x_left, &x_right);

        fillHspan(fb, y, x_left, x_right, color);
    }
}

fn fillTopTri(fb: *Framebuffer, top: Vec2_i32, mid: Vec2_i32, bot: Vec2_i32, color: u32) void {
    const dy_long  = bot[1] - top[1];
    const dy_short = bot[1] - mid[1];
    if (dy_short == 0) {
        return;
    }

    const y_start = @max(mid[1], 0);
    const y_end   = @min(bot[1] + 1, @as(i32, @intCast(height)));

    var y = y_start;
    while (y < y_end) : (y += 1) {
        const t_long  = @as(f32, @floatFromInt(y - top[1])) / @as(f32, @floatFromInt(dy_long));
        const t_short = @as(f32, @floatFromInt(y - mid[1])) / @as(f32, @floatFromInt(dy_short));

        var x_left  = top[0] + @as(i32, @intFromFloat(t_long  * @as(f32, @floatFromInt(bot[0] - top[0]))));
        var x_right = mid[0] + @as(i32, @intFromFloat(t_short * @as(f32, @floatFromInt(bot[0] - mid[0]))));

        if (x_left > x_right) mem.swap(i32, &x_left, &x_right);

        fillHspan(fb, y, x_left, x_right, color);
    }
}

inline fn fillHspan(fb: *Framebuffer, y: i32, x_left: i32, x_right: i32, color: u32) void {
    const x0 = @as(usize, @intCast(@max(x_left,  0)));
    const x1 = @as(usize, @intCast(@min(x_right, @as(i32, @intCast(width - 1)))));

    const row = @as(usize, @intCast(y)) * width;

    var x = x0;
    while (x <= x1) : (x += 1) {
        fb.*[row + x] = color;
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

        const before = sdl.getPerformanceCounter();

        { // render
            const dt = @as(f32, @floatFromInt(sdl.getTicks() - lastTime)) / 1000.0;
            dz += 0;
            angle += std.math.pi * dt;

            clearBackground(&framebuffer);

            for (faces) |f| {
                var i = @as(usize, 0);

                while (i < f.count) : (i += 3) {
                    const a_idx = index_buffer[f.start + i];
                    const b_idx = index_buffer[f.start + i + 1];
                    const c_idx = index_buffer[f.start + i + 2];

                    const a = vertices[@as(usize, a_idx)];
                    const b = vertices[@as(usize, b_idx)];
                    const c = vertices[@as(usize, c_idx)];

                    const ta = screen(project(rotateXZ(a, angle) + Vec3_f32{ 0, 0, dz })) catch continue;
                    const tb = screen(project(rotateXZ(b, angle) + Vec3_f32{ 0, 0, dz })) catch continue;
                    const tc = screen(project(rotateXZ(c, angle) + Vec3_f32{ 0, 0, dz })) catch continue;

                    // negative = facing away
                    const ax: i32 = @intCast(ta[0]); const ay: i32 = @intCast(ta[1]);
                    const bx: i32 = @intCast(tb[0]); const by: i32 = @intCast(tb[1]);
                    const cx: i32 = @intCast(tc[0]); const cy: i32 = @intCast(tc[1]);

                    const signed_area = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay);
                    if (signed_area <= 0) {
                        continue; // ... so we don't render it
                    }

                    fillTri(&framebuffer, ta, tb, tc, 0xFF_00_FF_00);
                }
            }

            lastTime = sdl.getTicks();
        }

        const after = sdl.getPerformanceCounter();
        std.debug.print("render ms: {any}\n", .{1000*(@as(f32, @floatFromInt(after-before))/@as(f32, @floatFromInt(sdl.getPerformanceFrequency())))});

        { // upload and present
            try texture.update(null, &framebuffer, width * @sizeOf(u32));
            try renderer.copy(texture, null, null);

            renderer.present();
        }
    }
}
