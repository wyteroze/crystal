// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl = @import("zsdl2");

const Mesh = @import("Mesh.zig").Mesh;
const types = @import("Types.zig");

const mem = std.mem;

const Vec2_i32 = types.Vec2_i32;
const Vec2_u32 = types.Vec2_u32;
const Vec2_f32 = types.Vec2_f32;
const Vec3_f32 = types.Vec3;
const Vec3_u32 = types.Vec3_u32;

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    sdl_window: *sdl.Window,
    sdl_renderer: *sdl.Renderer,
    sdl_texture: *sdl.Texture,
    background_color: types.Color3RGB = .{ .r = 0, .g = 0, .b = 0 },
    framebuffer: []u32,
    width: c_int,
    height: c_int,

    pub fn init(allocator: std.mem.Allocator, window: *sdl.Window, size: types.Size2D) !Renderer {
        const width = @as(c_int, @intCast(size.width));
        const height = @as(c_int, @intCast(size.height));

        const framebuffer = try allocator.alloc(u32, @as(usize, @intCast(width * height)));
        const sdl_renderer = try sdl.Renderer.create(window, null, .{ .accelerated = true, .present_vsync = false });
        const sdl_texture = try sdl.createTexture(sdl_renderer, .argb8888, .streaming, width, height);

        return .{
            .allocator = allocator,
            .sdl_window = window,
            .sdl_renderer = sdl_renderer,
            .sdl_texture = sdl_texture,
            .framebuffer = framebuffer,
            .width = width,
            .height = height
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.allocator.free(self.framebuffer);
        self.sdl_renderer.destroy();
        self.sdl_texture.destroy();
    }

    pub fn draw(self: *Renderer) !void {
        try self.sdl_texture.update(null, self.framebuffer.ptr, @as(c_int, @intCast(self.width)) * @sizeOf(u32));
        try self.sdl_renderer.copy(self.sdl_texture, null, null);

        self.sdl_renderer.present();
    }

    pub fn clearBackground(self: *Renderer) void {
        for (self.framebuffer) |*pixel| {
            pixel.* = 0xFF_00_00_00
                    | (@as(u32, self.background_color.r) << 16)
                    | (@as(u32, self.background_color.g) << 8)
                    | (@as(u32, self.background_color.b));
        }
    }

    fn point(self: *Renderer, p: Vec2_u32) void {
        if ((0 <= p.x and p.x < self.width) and (0 <= p.y and p.y < self.height)) {
            self.framebuffer[p[1] * self.width + p[0]] = 0xFF_00_FF_00;
        }
    }

    fn fillTri(self: *Renderer, a: Vec2_u32, b: Vec2_u32, c: Vec2_u32, color: u32) void {
        const ai = Vec2_i32 { .x = @intCast(a.x), .y = @intCast(a.y) };
        const bi = Vec2_i32 { .x = @intCast(b.x), .y = @intCast(b.y) };
        const ci = Vec2_i32 { .x = @intCast(c.x), .y = @intCast(c.y) };

        // sort from Y ascending
        var p = [3]Vec2_i32 { ai, bi, ci };
        if (p[0].y > p[1].y) mem.swap(Vec2_i32, &p[0], &p[1]);
        if (p[1].y > p[2].y) mem.swap(Vec2_i32, &p[1], &p[2]);
        if (p[0].y > p[1].y) mem.swap(Vec2_i32, &p[0], &p[1]);

        self.fillBottomTri(p[0], p[1], p[2], color);
        self.fillTopTri(p[0], p[1], p[2], color);
    }

    fn fillBottomTri(self: *Renderer, top: Vec2_i32, mid: Vec2_i32, bot: Vec2_i32, color: u32) void {
        const dy_long  = bot.y - top.y;
        const dy_short = mid.y - top.y;
        if (dy_short == 0) {
            return;
        }

        const y_start = @max(top.y, 0);
        const y_end   = @min(mid.y, @as(i32, @intCast(self.height)));

        var y = y_start;
        while (y < y_end) : (y += 1) {
            const t_long  = @as(f32, @floatFromInt(y - top.y)) / @as(f32, @floatFromInt(dy_long));
            const t_short = @as(f32, @floatFromInt(y - top.y)) / @as(f32, @floatFromInt(dy_short));

            var x_left  = top.x + @as(i32, @intFromFloat(t_long  * @as(f32, @floatFromInt(bot.x - top.x))));
            var x_right = top.x + @as(i32, @intFromFloat(t_short * @as(f32, @floatFromInt(mid.x - top.x))));

            if (x_left > x_right) mem.swap(i32, &x_left, &x_right);

            self.fillHspan(y, x_left, x_right, color);
        }
    }

    fn fillTopTri(self: *Renderer, top: Vec2_i32, mid: Vec2_i32, bot: Vec2_i32, color: u32) void {
        const dy_long  = bot.y - top.y;
        const dy_short = bot.y - mid.y;
        if (dy_short == 0) {
            return;
        }

        const y_start = @max(mid.y, 0);
        const y_end   = @min(bot.y + 1, @as(i32, @intCast(self.height)));

        var y = y_start;
        while (y < y_end) : (y += 1) {
            const t_long  = @as(f32, @floatFromInt(y - top.y)) / @as(f32, @floatFromInt(dy_long));
            const t_short = @as(f32, @floatFromInt(y - mid.y)) / @as(f32, @floatFromInt(dy_short));

            var x_left  = top.x + @as(i32, @intFromFloat(t_long  * @as(f32, @floatFromInt(bot.x - top.x))));
            var x_right = mid.x + @as(i32, @intFromFloat(t_short * @as(f32, @floatFromInt(bot.x - mid.x))));

            if (x_left > x_right) mem.swap(i32, &x_left, &x_right);

            self.fillHspan(y, x_left, x_right, color);
        }
    }

    inline fn fillHspan(self: *Renderer, y: i32, x_left: i32, x_right: i32, color: u32) void {
        const x0 = @as(usize, @intCast(@max(x_left,  0)));
        const x1 = @as(usize, @intCast(@min(x_right, @as(i32, @intCast(self.width - 1)))));

        const row = @as(usize, @intCast(y)) * @as(usize, @intCast(self.width));

        var x = x0;
        while (x <= x1) : (x += 1) {
            self.framebuffer[row + x] = color;
        }
    }

    fn line(self: *Renderer, p1: Vec2_u32, p2: Vec2_u32) void {
        var x0 = @as(i32, @intCast(p1.x));
        var y0 = @as(i32, @intCast(p1.y));
        const x1 = @as(i32, @intCast(p2.x));
        const y1 = @as(i32, @intCast(p2.y));

        const dx = @as(i32, @intCast(@abs(x1 - x0)));
        const dy = @as(i32, @intCast(@abs(y1 - y0)));
        const sx = @as(i32, if (x0 < x1) 1 else -1);
        const sy = @as(i32, if (y0 < y1) 1 else -1);
        var err = dx - dy;

        while (true) {
            self.point(Vec2_u32{ .x = @intCast(x0), .y = @intCast(y0) });
            if (x0 == x1 and y0 == y1) break;

            const e2 = 2 * err;
            if (e2 > -dy) { err -= dy; x0 += sx; }
            if (e2 < dx) { err += dx; y0 += sy; }
        }
    }

    fn screen(self: *Renderer, p: Vec2_f32) !Vec2_u32 {
        const x = (p.x + 1) / 2 * @as(f32, @floatFromInt(self.width));
        const y = (1 - (p.y + 1) / 2) * @as(f32, @floatFromInt(self.height));

        const w: f32 = @floatFromInt(self.width);
        const h: f32 = @floatFromInt(self.height);

        if (x >= 0 and x < w and y >= 0 and y < h) {
            return Vec2_u32{
                .x = @intFromFloat(x),
                .y = @intFromFloat(y),
            };
        }

        return error.PointOutOfBounds;
    }

    fn project(_: *Renderer, p: @Vector(3, f32)) Vec2_f32 {
        return Vec2_f32 {
            .x = p[0] / p[2],
            .y = p[1] / p[2]
        };
    }

    fn rotateXZ(_: *Renderer, p: @Vector(3, f32), angle: f32) @Vector(3, f32) {
        const c = @cos(angle);
        const s = @sin(angle);

        return @Vector(3, f32){
            p[0] * c - p[2] * s,
            p[1],
            p[0] * s + p[2] * c
        };
    }

    pub fn renderMesh(self: *Renderer, mesh: *const Mesh, transform: types.Transform) void {
        for (mesh.faces) |f| {
            var i = @as(usize, 0);

            while (i < f.count) : (i += 3) {
                const a_idx = mesh.indices[f.start + i];
                const b_idx = mesh.indices[f.start + i + 1];
                const c_idx = mesh.indices[f.start + i + 2];

                const a = mesh.vertices[@as(usize, a_idx)];
                const b = mesh.vertices[@as(usize, b_idx)];
                const c = mesh.vertices[@as(usize, c_idx)];

                const y = transform.rotation[1];
                const ta = self.screen(self.project(self.rotateXZ(a, y) + transform.position)) catch continue;
                const tb = self.screen(self.project(self.rotateXZ(b, y) + transform.position)) catch continue;
                const tc = self.screen(self.project(self.rotateXZ(c, y) + transform.position)) catch continue;

                // negative = facing away
                const ax: i32 = @intCast(ta.x); const ay: i32 = @intCast(ta.y);
                const bx: i32 = @intCast(tb.x); const by: i32 = @intCast(tb.y);
                const cx: i32 = @intCast(tc.x); const cy: i32 = @intCast(tc.y);

                const signed_area = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay);
                if (signed_area <= 0) {
                    continue; // ... so we don't render it
                }

                self.fillTri(ta, tb, tc, 0xFF_00_FF_00);
            }
        }
    }
};
