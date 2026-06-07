// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl = @import("zsdl2");

const math      = @import("math.zig");
const types     = @import("types.zig");
const Mesh      = @import("Mesh.zig").Mesh;
const Sprite    = @import("Sprite.zig").Sprite;
const Camera    = @import("Camera.zig").Camera;

const Mat4 = types.Mat4;
const Vertex = types.Vertex;
const Triangle  = types.Triangle;
const Transform = types.Transform;
const Vec2_SIMD = types.Vec2_SIMD;
const Vec3_SIMD = types.Vec3_SIMD;
const Vec4_SIMD = types.Vec4_SIMD;
pub const Vec2_cint = struct { x: c_int, y: c_int };
pub const Plane = struct { point: Vec3_SIMD, normal: Vec3_SIMD };

const clear_color = 0xFF_8A_AA_FF;

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    renderer: *sdl.Renderer,
    texture: *sdl.Texture,
    framebuffer: []u32,
    depthbuffer: []f32,
    size: Vec2_cint,
    camera: *Camera,
    tri_buffer: std.ArrayList(Triangle),
    tri_raster_list: std.ArrayList(Triangle),

    pub fn init(allocator: std.mem.Allocator, window: *sdl.Window, size: Vec2_cint, camera: *Camera, vsync: ?bool) !Renderer {
        const renderer = try sdl.createRenderer(window, null, .{ .accelerated = true, .present_vsync = vsync orelse false });
        const texture = try sdl.createTexture(renderer, .argb8888, .streaming, size.x, size.y);

        return .{
            .allocator = allocator,
            .renderer = renderer,
            .texture = texture,
            .framebuffer = try allocator.alloc(u32, @as(usize, @intCast(size.x * size.y))),
            .depthbuffer = try allocator.alloc(f32, @as(usize, @intCast(size.x * size.y))),
            .size = size,
            .camera = camera,
            .tri_buffer = std.ArrayList(Triangle).empty,
            .tri_raster_list = std.ArrayList(Triangle).empty
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.renderer.destroy();
        self.texture.destroy();
        self.allocator.free(self.framebuffer);
        self.allocator.free(self.depthbuffer);
        self.tri_buffer.deinit(self.allocator);
        self.tri_raster_list.deinit(self.allocator);
    }

    pub fn present(self: Renderer) !void {
        try sdl.updateTexture(self.texture, null, self.framebuffer.ptr, self.size.x * @sizeOf(u32));
        try self.renderer.copy(self.texture, null, null);

        // renderer is sdl renderer, not this
        self.renderer.present();
    }


    // rendering methods
    pub fn drawBackground(self: *Renderer) void {
        @memset(self.framebuffer, clear_color);
        @memset(self.depthbuffer, 0.0);
    }

    pub fn drawMesh(self: *Renderer, mesh: *const Mesh, transform: *const Transform) !void {
        const camera_transform = self.camera.transform;
        const projection_matrix = self.camera.getProjectionMatrix();
        const view_matrix = self.camera.getViewMatrix();

        const rotationRad = transform.rotation * @as(Vec3_SIMD, @splat(std.math.pi / 180.0));
        const rotate_x_matrix = Mat4{ .rows = .{
            Vec4_SIMD{ 1, 0, 0, 0 },
            Vec4_SIMD{ 0, @cos(rotationRad[0]), @sin(rotationRad[0]), 0 },
            Vec4_SIMD{ 0, -@sin(rotationRad[0]), @cos(rotationRad[0]), 0 },
            Vec4_SIMD{ 0, 0, 0, 1 },
        }};

        const rotate_y_matrix = Mat4{ .rows = .{
            Vec4_SIMD{ @cos(rotationRad[1]), 0, @sin(rotationRad[1]), 0 },
            Vec4_SIMD{ 0, 1, 0, 0 },
            Vec4_SIMD{ -@sin(rotationRad[1]), 0, @cos(rotationRad[1]), 0 },
            Vec4_SIMD{ 0, 0, 0, 1 }
        }};

        const rotate_z_matrix = Mat4{ .rows = .{
            Vec4_SIMD{ @cos(rotationRad[2]), @sin(rotationRad[2]), 0, 0 },
            Vec4_SIMD{ -@sin(rotationRad[2]), @cos(rotationRad[2]), 0, 0 },
            Vec4_SIMD{ 0, 0, 1, 0 },
            Vec4_SIMD{ 0, 0, 0, 1 }
        }};

        // ZYX order rotation
        var world_matrix = math.multiplyMatrices(
            math.multiplyMatrices(rotate_z_matrix, rotate_y_matrix),
            rotate_x_matrix
        );

        // transform
        world_matrix.rows[3] += Vec4_SIMD{
            transform.position[0],
            transform.position[1],
            transform.position[2],
            0.0
        };

        self.tri_buffer.clearRetainingCapacity();
        for (mesh.faces) |*face| {
            var i = @as(usize, 0);

            while (i < face.length) : (i += 3) {
                const ia = mesh.vertices[mesh.indices[face.start + i]];
                const ib = mesh.vertices[mesh.indices[face.start + i + 1]];
                const ic = mesh.vertices[mesh.indices[face.start + i + 2]];

                const va = math.multiplyMatrixVector(world_matrix, ia.position);
                const vb = math.multiplyMatrixVector(world_matrix, ib.position);
                const vc = math.multiplyMatrixVector(world_matrix, ic.position);

                // culling
                const world_normal = math.normal(va, vb, vc);
                const view_dir = math.normalize(va - camera_transform.position);
                if (math.dot(world_normal, view_dir) >= 0.0) continue;

                // lighting
                const light_direction = math.normalize(Vec3_SIMD{ 0.0, 0.0, -1.0 });
                const light_normal = math.dot(light_direction, world_normal);
                const color = math.luminanceToRGB(light_normal);

                // world space to view space
                var view_space = Triangle{
                    .pa = Vertex{
                        .position = math.multiplyMatrixVector(view_matrix, va),
                        .uv = ia.uv
                    },
                    .pb = Vertex{
                        .position = math.multiplyMatrixVector(view_matrix, vb),
                        .uv = ib.uv
                    },
                    .pc = Vertex{
                        .position = math.multiplyMatrixVector(view_matrix, vc),
                        .uv = ic.uv
                    },

                    .color = color,
                    .depth = 0 // we will set this below
                };

                view_space.depth = (view_space.pa.position[2] + view_space.pb.position[2] + view_space.pc.position[2]) / 3.0;

                const clip = math.clipTriangleAgainstPlane(Vec3_SIMD{ 0.0, 0.0, 0.1 }, Vec3_SIMD{ 0.0, 0.0, 1.0 }, view_space);

                for (0..clip.n) |n| {
                    const clipped = switch (n) {
                        0 => clip.t1.?,
                        1 => clip.t2.?,

                        else => unreachable
                    };

                    // project from 3d to 2d
                    const proj_a = math.multiplyMatrixVectorW(projection_matrix, clipped.pa.position);
                    const proj_b = math.multiplyMatrixVectorW(projection_matrix, clipped.pb.position);
                    const proj_c = math.multiplyMatrixVectorW(projection_matrix, clipped.pc.position);

                    // divide UVs by W before dividing position
                    const uv_a = clipped.pa.uv / @as(Vec2_SIMD, @splat(proj_a.w));
                    const uv_b = clipped.pb.uv / @as(Vec2_SIMD, @splat(proj_b.w));
                    const uv_c = clipped.pc.uv / @as(Vec2_SIMD, @splat(proj_c.w));

                    // now divide position by W
                    var p = [3]Vec3_SIMD{
                        proj_a.xyz / @as(Vec3_SIMD, @splat(proj_a.w)),
                        proj_b.xyz / @as(Vec3_SIMD, @splat(proj_b.w)),
                        proj_c.xyz / @as(Vec3_SIMD, @splat(proj_c.w)),
                    };

                    // scale into view
                    const sx = 0.5 * @as(f32, @floatFromInt(self.size.x));
                    const sy = 0.5 * @as(f32, @floatFromInt(self.size.y));

                    inline for (&p) |*v| {
                        v[0] = (v[0] + 1.0) * sx;
                        v[1] = (1.0 - v[1]) * sy; // invert y
                    }

                    // add to buffer to be rendered later
                    try self.tri_buffer.append(self.allocator, .{
                        .pa = Vertex{
                            .position = Vec3_SIMD{ p[0][0], p[0][1], 1.0 / proj_a.w },
                            .uv = uv_a
                        },
                        .pb = Vertex{
                            .position = Vec3_SIMD{ p[1][0], p[1][1], 1.0 / proj_b.w },
                            .uv = uv_b
                        },
                        .pc = Vertex{
                            .position = Vec3_SIMD{ p[2][0], p[2][1], 1.0 / proj_c.w },
                            .uv = uv_c
                        },
                        .color = clipped.color,
                        .depth = clipped.depth
                    });
                }
            }
        }


        const f_width  = @as(f32, @floatFromInt(self.size.x));
        const f_height = @as(f32, @floatFromInt(self.size.y));

        const planes = [4]Plane{
            .{ .point = .{ 0.0,    0.0,     0.0 }, .normal = .{  0.0,  1.0, 0.0 } }, // top
            .{ .point = .{ 0.0,    f_height, 0.0 }, .normal = .{  0.0, -1.0, 0.0 } }, // bottom
            .{ .point = .{ 0.0,    0.0,     0.0 }, .normal = .{  1.0,  0.0, 0.0 } }, // left
            .{ .point = .{ f_width, 0.0,    0.0 }, .normal = .{ -1.0,  0.0, 0.0 } }, // right
        };

        for (self.tri_buffer.items) |tri| {
            self.tri_raster_list.clearRetainingCapacity();
            try self.tri_raster_list.append(self.allocator, tri);

            for (0..4) |p| {
                const tris_to_process = self.tri_raster_list.items.len;

                for (0..tris_to_process) |i| {
                    const test_tri = self.tri_raster_list.items[i];

                    const clip = switch (p) {
                        0 => math.clipTriangleAgainstPlane(planes[0].point, planes[0].normal, test_tri),
                        1 => math.clipTriangleAgainstPlane(planes[1].point, planes[1].normal, test_tri),
                        2 => math.clipTriangleAgainstPlane(planes[2].point, planes[2].normal, test_tri),
                        3 => math.clipTriangleAgainstPlane(planes[3].point, planes[3].normal, test_tri),

                        else => unreachable,
                    };

                    for (0..clip.n) |w| {
                        const clipped = if (w == 0) clip.t1.? else clip.t2.?;
                        try self.tri_raster_list.append(self.allocator, clipped);
                    }
                }

                self.tri_raster_list.replaceRangeAssumeCapacity(0, tris_to_process, &.{});
            }

            if (mesh.texture) |t| {
                for (self.tri_raster_list.items) |final_tri| {
                    self.drawTexturedTriangle(final_tri, t.*);
                }
            } else {
                for (self.tri_raster_list.items) |final_tri| {
                    self.drawTriangle(final_tri.pa.position, final_tri.pb.position, final_tri.pc.position, final_tri.color);
                    //self.drawTriangleWireframe(final_tri.pa.position, final_tri.pb.position, final_tri.pc.position, 0xFF_FF_FF_FF);
                }
            }
        }
    }

    inline fn drawPoint(self: *Renderer, x: f32, y: f32, color: ?u32) void {
        const fw = @as(f32, @floatFromInt(self.size.x));
        const fh = @as(f32, @floatFromInt(self.size.y));
        if (x < 0 or y < 0 or x >= fw or y >= fh) return;

        const ix = @as(usize, @intFromFloat(x));
        const iy = @as(usize, @intFromFloat(y));
        const width_usize = @as(usize, @intCast(self.size.x));

        const idx = iy * width_usize + ix;

        if (idx >= self.framebuffer.len) return;
        self.framebuffer[idx] = color orelse 0xFF_FF_FF_FF;
    }

    fn drawLine(self: *Renderer, p0: Vec3_SIMD, p1: Vec3_SIMD, color: ?u32) void {
        var x0 = @as(i32, @intFromFloat(p0[0]));
        var y0 = @as(i32, @intFromFloat(p0[1]));
        const x1 = @as(i32, @intFromFloat(p1[0]));
        const y1 = @as(i32, @intFromFloat(p1[1]));

        const dx = @as(i32, if (x0 < x1) x1 - x0 else x0 - x1);
        const dy = @as(i32, if (y0 < y1) y1 - y0 else y0 - y1);
        const sx = @as(i32, if (x0 < x1) 1 else -1);
        const sy = @as(i32, if (y0 < y1) 1 else -1);
        var err = dx - dy;

        while (true) {
            self.drawPoint(
                @as(f32, @floatFromInt(x0)),
                @as(f32, @floatFromInt(y0)),
                color
            );
            if (x0 == x1 and y0 == y1) break;

            const e2 = 2 * err;
            if (e2 > -dy) { err -= dy; x0 += sx; }
            if (e2 <  dx) { err += dx; y0 += sy; }
        }
    }

    fn drawTriangle(self: *Renderer, p0: Vec3_SIMD, p1: Vec3_SIMD, p2: Vec3_SIMD, color: ?u32) void {
        var a = p0;
        var b = p1;
        var c = p2;

        if (a[1] > b[1]) std.mem.swap(Vec3_SIMD, &a, &b);
        if (b[1] > c[1]) std.mem.swap(Vec3_SIMD, &b, &c);
        if (a[1] > b[1]) std.mem.swap(Vec3_SIMD, &a, &b);

        const y_top    = a[1];
        const y_mid    = b[1];
        const y_bottom = c[1];

        if (y_top == y_bottom) return;

        const ac = (c[0] - a[0]) / (y_bottom - y_top);
        const ab = if (y_mid != y_top)   (b[0] - a[0]) / (y_mid - y_top)    else 0.0;
        const bc = if (y_bottom != y_mid) (c[0] - b[0]) / (y_bottom - y_mid) else 0.0;

        { // upper half
            const y_start = @as(i32, @intFromFloat(@ceil(y_top)));
            const y_end   = @as(i32, @intFromFloat(@ceil(y_mid)));

            var y = y_start;
            while (y < y_end) : (y += 1) {
                const t = @as(f32, @floatFromInt(y));
                var xa = a[0] + (t - y_top) * ac;
                var xb = a[0] + (t - y_top) * ab;
                if (xa > xb) std.mem.swap(f32, &xa, &xb);

                const x0 = @as(i32, @intFromFloat(@ceil(xa)));
                const x1 = @as(i32, @intFromFloat(@floor(xb))) + 1;

                var x: i32 = x0;
                while (x < x1) : (x += 1) {
                    self.drawPoint(@floatFromInt(x), t, color);
                }
            }
        }

        { // lower half
            const y_start = @as(i32, @intFromFloat(@ceil(y_mid)));
            const y_end   = @as(i32, @intFromFloat(@ceil(y_bottom)));

            var y = y_start;
            while (y < y_end) : (y += 1) {
                const t = @as(f32, @floatFromInt(y));
                var xa = a[0] + (t - y_top) * ac;
                var xb = b[0] + (t - y_mid) * bc;
                if (xa > xb) std.mem.swap(f32, &xa, &xb);

                const x0 = @as(i32, @intFromFloat(@ceil(xa)));
                const x1 = @as(i32, @intFromFloat(@floor(xb))) + 1;

                var x: i32 = x0;
                while (x < x1) : (x += 1) {
                    self.drawPoint(@floatFromInt(x), t, color);
                }
            }
        }
    }

    fn drawTriangleWireframe(self: *Renderer, p0: Vec3_SIMD, p1: Vec3_SIMD, p2: Vec3_SIMD, color: ?u32) void {
        self.drawLine(p0, p1, color);
        self.drawLine(p1, p2, color);
        self.drawLine(p2, p0, color);
    }

    pub fn visualizeAxes(self: *Renderer) void {
        const projection_matrix = self.camera.getProjectionMatrix();
        const view_matrix = self.camera.getViewMatrix();

        const sx = 0.5 * @as(f32, @floatFromInt(self.size.x));
        const sy = 0.5 * @as(f32, @floatFromInt(self.size.y));

        // this changes the axis line length
        const axis_length = @as(f32, 2.0);

        // axes in world space
        const world_origin = Vec3_SIMD{ 0.0, 0.0, 0.0 };
        const world_x = Vec3_SIMD{ axis_length, 0.0, 0.0 };
        const world_y = Vec3_SIMD{ 0.0, axis_length, 0.0 };
        const world_z = Vec3_SIMD{ 0.0, 0.0, axis_length };

        // view space
        const view_origin = math.multiplyMatrixVector(view_matrix, world_origin);
        const view_x = math.multiplyMatrixVector(view_matrix, world_x);
        const view_y = math.multiplyMatrixVector(view_matrix, world_y);
        const view_z = math.multiplyMatrixVector(view_matrix, world_z);

        const LineClipper = struct {
            fn drawClippedLine(
                r: *Renderer,
                p0_view: Vec3_SIMD,
                p1_view: Vec3_SIMD,
                proj: Mat4,
                scale_x: f32,
                scale_y: f32,
                color: u32
            ) void {
                const near_z = 0.1;
                const d0 = p0_view[2] - near_z;
                const d1 = p1_view[2] - near_z;

                var start = p0_view;
                var end = p1_view;

                // it's behind plane, discard
                if (d0 < 0.0 and d1 < 0.0) return;

                if (d0 < 0.0) { // clip start point if behind near plane
                    start = math.vectorIntersectPlane(
                        Vec3_SIMD{ 0.0, 0.0, near_z },
                        Vec3_SIMD{ 0.0, 0.0, 1.0 },
                        p0_view,
                        p1_view
                    ).intersect;
                } else if (d1 < 0.0) { // clip end point if behind near plane
                    end = math.vectorIntersectPlane(
                        Vec3_SIMD{ 0.0, 0.0, near_z },
                        Vec3_SIMD{ 0.0, 0.0, 1.0 },
                        p0_view,
                        p1_view
                    ).intersect;
                }

                const proj_start = math.multiplyMatrixVector(proj, start);
                const proj_end   = math.multiplyMatrixVector(proj, end);

                // map to screen space
                const screen_start = Vec3_SIMD{ (proj_start[0] + 1.0) * scale_x, (1.0 - proj_start[1]) * scale_y, 0.0 };
                const screen_end   = Vec3_SIMD{ (proj_end[0] + 1.0) * scale_x,   (1.0 - proj_end[1]) * scale_y,   0.0 };

                r.drawLine(screen_start, screen_end, color);
            }
        };

        // draw
        LineClipper.drawClippedLine(self, view_origin, view_x, projection_matrix, sx, sy, 0xFF_FF_00_00); // x = red
        LineClipper.drawClippedLine(self, view_origin, view_y, projection_matrix, sx, sy, 0xFF_00_FF_00); // y = green
        LineClipper.drawClippedLine(self, view_origin, view_z, projection_matrix, sx, sy, 0xFF_00_00_FF); // z = blue
    }

    // I'm sorry
    pub fn drawTexturedTriangle(self: *Renderer, tri: Triangle, sprite: Sprite) void {
        var pa = tri.pa;
        var pb = tri.pb;
        var pc = tri.pc;

        if (pb.position[1] < pa.position[1]) std.mem.swap(Vertex, &pa, &pb);
        if (pc.position[1] < pa.position[1]) std.mem.swap(Vertex, &pa, &pc);
        if (pc.position[1] < pb.position[1]) std.mem.swap(Vertex, &pb, &pc);

        const x1 = @as(i32, @intFromFloat(pa.position[0]));
        const y1 = @as(i32, @intFromFloat(pa.position[1]));
        const tu1 = pa.uv[0];
        const tv1 = pa.uv[1];
        const tw1 = pa.position[2];

        const x2 = @as(i32, @intFromFloat(pb.position[0]));
        const y2 = @as(i32, @intFromFloat(pb.position[1]));
        const tu2 = pb.uv[0];
        const tv2 = pb.uv[1];
        const tw2 = pb.position[2];

        const x3 = @as(i32, @intFromFloat(pc.position[0]));
        const y3 = @as(i32, @intFromFloat(pc.position[1]));
        const tu3 = pc.uv[0];
        const tv3 = pc.uv[1];
        const tw3 = pc.position[2];

        // top half
        var dy1: i32 = y2 - y1;
        var dx1: i32 = x2 - x1;
        var dv1: f32 = tv2 - tv1;
        var du1: f32 = tu2 - tu1;
        var dw1: f32 = tw2 - tw1;

        const dy2 = y3 - y1;
        const dx2 = x3 - x1;
        const dv2 = tv3 - tv1;
        const du2 = tu3 - tu1;
        const dw2 = tw3 - tw1;

        var dax_step: f32 = 0;
        var dbx_step: f32 = 0;
        var du1_step: f32 = 0;
        var dv1_step: f32 = 0;
        var dw1_step: f32 = 0;
        var du2_step: f32 = 0;
        var dv2_step: f32 = 0;
        var dw2_step: f32 = 0;

        if (dy1 != 0) dax_step = @as(f32, @floatFromInt(dx1)) / @as(f32, @floatFromInt(@abs(dy1)));
        if (dy2 != 0) dbx_step = @as(f32, @floatFromInt(dx2)) / @as(f32, @floatFromInt(@abs(dy2)));

        if (dy1 != 0) du1_step = du1 / @as(f32, @floatFromInt(@abs(dy1)));
        if (dy1 != 0) dv1_step = dv1 / @as(f32, @floatFromInt(@abs(dy1)));
        if (dy1 != 0) dw1_step = dw1 / @as(f32, @floatFromInt(@abs(dy1)));

        if (dy2 != 0) du2_step = du2 / @as(f32, @floatFromInt(@abs(dy2)));
        if (dy2 != 0) dv2_step = dv2 / @as(f32, @floatFromInt(@abs(dy2)));
        if (dy2 != 0) dw2_step = dw2 / @as(f32, @floatFromInt(@abs(dy2)));

        if (dy1 != 0) {
            var i: i32 = y1;
            while (i <= y2) : (i += 1) {
                const fi = @as(f32, @floatFromInt(i - y1));

                var ax: i32 = x1 + @as(i32, @intFromFloat(fi * dax_step));
                var bx: i32 = x1 + @as(i32, @intFromFloat(fi * dbx_step));

                var tex_su: f32 = tu1 + fi * du1_step;
                var tex_sv: f32 = tv1 + fi * dv1_step;
                var tex_sw: f32 = tw1 + fi * dw1_step;

                var tex_eu: f32 = tu1 + fi * du2_step;
                var tex_ev: f32 = tv1 + fi * dv2_step;
                var tex_ew: f32 = tw1 + fi * dw2_step;

                if (ax > bx) {
                    std.mem.swap(i32, &ax, &bx);
                    std.mem.swap(f32, &tex_su, &tex_eu);
                    std.mem.swap(f32, &tex_sv, &tex_ev);
                    std.mem.swap(f32, &tex_sw, &tex_ew);
                }

                const tstep = 1.0 / @as(f32, @floatFromInt(bx - ax));
                var t: f32 = 0.0;

                var j: i32 = ax;
                while (j < bx) : (j += 1) {
                    const tex_u = (1.0 - t) * tex_su + t * tex_eu;
                    const tex_v = (1.0 - t) * tex_sv + t * tex_ev;
                    const tex_w = (1.0 - t) * tex_sw + t * tex_ew;

                    if (i < 0 or j < 0) continue;
                    const idx = @as(usize, @intCast(i)) * @as(usize, @intCast(self.size.x)) + @as(usize, @intCast(j));
                    if (idx >= self.depthbuffer.len) continue;
                    if (tex_w > self.depthbuffer[idx]) {
                        self.drawPoint(@floatFromInt(j), @floatFromInt(i), sprite.sample(tex_u / tex_w, tex_v / tex_w));
                       self.depthbuffer[idx] = tex_w;
                    }

                    t += tstep;
                }
            }
        }

        // bottom half
        dy1 = y3 - y2;
        dx1 = x3 - x2;
        dv1 = tv3 - tv2;
        du1 = tu3 - tu2;
        dw1 = tw3 - tw2;

        if (dy1 != 0) dax_step = @as(f32, @floatFromInt(dx1)) / @as(f32, @floatFromInt(@abs(dy1)));
        if (dy2 != 0) dbx_step = @as(f32, @floatFromInt(dx2)) / @as(f32, @floatFromInt(@abs(dy2)));

        du1_step = 0;
        dv1_step = 0;
        if (dy1 != 0) du1_step = du1 / @as(f32, @floatFromInt(@abs(dy1)));
        if (dy1 != 0) dv1_step = dv1 / @as(f32, @floatFromInt(@abs(dy1)));
        if (dy1 != 0) dw1_step = dw1 / @as(f32, @floatFromInt(@abs(dy1)));

        if (dy1 != 0) {
            var i: i32 = y2;
            while (i <= y3) : (i += 1) {
                const fi_top = @as(f32, @floatFromInt(i - y2));
                const fi_bot = @as(f32, @floatFromInt(i - y1));

                var ax: i32 = x2 + @as(i32, @intFromFloat(fi_top * dax_step));
                var bx: i32 = x1 + @as(i32, @intFromFloat(fi_bot * dbx_step));

                var tex_su: f32 = tu2 + fi_top * du1_step;
                var tex_sv: f32 = tv2 + fi_top * dv1_step;
                var tex_sw: f32 = tw2 + fi_top * dw1_step;

                var tex_eu: f32 = tu1 + fi_bot * du2_step;
                var tex_ev: f32 = tv1 + fi_bot * dv2_step;
                var tex_ew: f32 = tw1 + fi_bot * dw2_step;

                if (ax > bx) {
                    std.mem.swap(i32, &ax, &bx);
                    std.mem.swap(f32, &tex_su, &tex_eu);
                    std.mem.swap(f32, &tex_sv, &tex_ev);
                    std.mem.swap(f32, &tex_sw, &tex_ew);
                }

                const tstep: f32 = 1.0 / @as(f32, @floatFromInt(bx - ax));
                var t: f32 = 0.0;

                var j: i32 = ax;
                while (j < bx) : (j += 1) {
                    const tex_u = (1.0 - t) * tex_su + t * tex_eu;
                    const tex_v = (1.0 - t) * tex_sv + t * tex_ev;
                    const tex_w = (1.0 - t) * tex_sw + t * tex_ew;

                    if (i < 0 or j < 0) continue;
                    const idx = @as(usize, @intCast(i)) * @as(usize, @intCast(self.size.x)) + @as(usize, @intCast(j));
                    if (idx >= self.depthbuffer.len) continue;
                    if (tex_w > self.depthbuffer[idx]) {
                        self.drawPoint(@floatFromInt(j), @floatFromInt(i), sprite.sample(tex_u / tex_w, tex_v / tex_w));
                       self.depthbuffer[idx] = tex_w;
                    }

                    t += tstep;
                }
            }
        }
    }
};
