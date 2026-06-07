// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const types = @import("types.zig");

const Mat4 = types.Mat4;
const Vec2_SIMD = types.Vec2_SIMD;
const Vec3_SIMD = types.Vec3_SIMD;
const Vec4_SIMD = types.Vec4_SIMD;
const Triangle = types.Triangle;
const Vertex = types.Vertex;

pub const ClipResult = struct {
    n: usize,
    t1: ?Triangle,
    t2: ?Triangle
};

pub inline fn dot(a: Vec3_SIMD, b: Vec3_SIMD) f32 {
    return @reduce(.Add, a * b);
}

pub fn cross(a: Vec3_SIMD, b: Vec3_SIMD) Vec3_SIMD {
    const a_yzw = @shuffle(f32, a, a, @Vector(3, i32){1, 2, 0});
    const b_yzw = @shuffle(f32, b, b, @Vector(3, i32){2, 0, 1});
    const a_zxy = @shuffle(f32, a, a, @Vector(3, i32){2, 0, 1});
    const b_zxy = @shuffle(f32, b, b, @Vector(3, i32){1, 2, 0});

    return (a_yzw * b_yzw) - (a_zxy * b_zxy);
}

pub fn normal(p1: Vec3_SIMD, p2: Vec3_SIMD, p3: Vec3_SIMD) Vec3_SIMD {
    const line1 = p2 - p1;
    const line2 = p3 - p1;
    const norm = types.Vec3_SIMD{
        line1[1] * line2[2] - line1[2] * line2[1],
        line1[2] * line2[0] - line1[0] * line2[2],
        line1[0] * line2[1] - line1[1] * line2[0]
    };

    return normalize(norm);
}

pub inline fn normalize(a: Vec3_SIMD) Vec3_SIMD {
    const norm_len = @sqrt(dot(a, a));
    return a / @as(Vec3_SIMD, @splat(norm_len));
}

/// Luminance is clamped between 0.0 - 1.0
pub fn luminanceToRGB(luminance: f32) u32 {
    const channel = @as(u8, @intFromFloat(@max(0.0, @min(1.0, luminance)) * 255.0));

    return 0xFF_00_00_00 |
        (@as(u32, channel) << 16) |
        (@as(u32, channel) << 8)  |
        (@as(u32, channel));
}

pub fn multiplyMatrixVector(self: Mat4, vec: Vec3_SIMD) Vec3_SIMD {
    const r = self.rows;

    var output = Vec3_SIMD{
        vec[0] * r[0][0] + vec[1] * r[1][0] + vec[2] * r[2][0] + r[3][0], // x
        vec[0] * r[0][1] + vec[1] * r[1][1] + vec[2] * r[2][1] + r[3][1], // y
        vec[0] * r[0][2] + vec[1] * r[1][2] + vec[2] * r[2][2] + r[3][2], // z
    };

    const w = vec[0] * r[0][3] + vec[1] * r[1][3] + vec[2] * r[2][3] + r[3][3];
    if (w != 0.0 and w != 1.0) {
        output /= @splat(w);
    }

    return output;
}

pub fn multiplyMatrixVectorW(self: Mat4, vec: Vec3_SIMD) struct { xyz: Vec3_SIMD, w: f32 } {
    const r = self.rows;

    const xyz = Vec3_SIMD{
        vec[0] * r[0][0] + vec[1] * r[1][0] + vec[2] * r[2][0] + r[3][0],
        vec[0] * r[0][1] + vec[1] * r[1][1] + vec[2] * r[2][1] + r[3][1],
        vec[0] * r[0][2] + vec[1] * r[1][2] + vec[2] * r[2][2] + r[3][2],
    };

    const w = vec[0] * r[0][3] + vec[1] * r[1][3] + vec[2] * r[2][3] + r[3][3];

    return .{ .xyz = xyz, .w = w };
}

pub fn multiplyMatrices(a: Mat4, b: Mat4) Mat4 {
    var out = Mat4.initZero();
    const b_transposed = Mat4{ .rows = .{
        Vec4_SIMD{ b.rows[0][0], b.rows[1][0], b.rows[2][0], b.rows[3][0] },
        Vec4_SIMD{ b.rows[0][1], b.rows[1][1], b.rows[2][1], b.rows[3][1] },
        Vec4_SIMD{ b.rows[0][2], b.rows[1][2], b.rows[2][2], b.rows[3][2] },
        Vec4_SIMD{ b.rows[0][3], b.rows[1][3], b.rows[2][3], b.rows[3][3] },
    }};

    inline for (0..4) |r| {
        out.rows[r] = Vec4_SIMD{
            @reduce(.Add, a.rows[r] * b_transposed.rows[0]),
            @reduce(.Add, a.rows[r] * b_transposed.rows[1]),
            @reduce(.Add, a.rows[r] * b_transposed.rows[2]),
            @reduce(.Add, a.rows[r] * b_transposed.rows[3]),
        };
    }

    return out;
}

pub fn pointAt(pos: Vec3_SIMD, target: Vec3_SIMD, up: Vec3_SIMD) Mat4 {
    const forward_dir = normalize(target - pos);
    const up_dir = up - (forward_dir * @as(Vec3_SIMD, @splat(dot(up, forward_dir))));
    const right_dir = cross(up_dir, forward_dir);

    const matrix = Mat4{ .rows = .{
        Vec4_SIMD{ right_dir[0],    right_dir[1],   right_dir[2],   0 },
        Vec4_SIMD{ up_dir[0],       up_dir[1],      up_dir[2],      0 },
        Vec4_SIMD{ forward_dir[0],  forward_dir[1], forward_dir[2], 0 },
        Vec4_SIMD{ pos[0],          pos[1],         pos[2],         1 }
    }};

    return matrix;
}

pub fn matrixQuickInverse(m: Mat4) Mat4 {
    const r0 = Vec4_SIMD{ m.rows[0][0], m.rows[1][0], m.rows[2][0], 0.0 };
    const r1 = Vec4_SIMD{ m.rows[0][1], m.rows[1][1], m.rows[2][1], 0.0 };
    const r2 = Vec4_SIMD{ m.rows[0][2], m.rows[1][2], m.rows[2][2], 0.0 };

    const r3 = Vec4_SIMD{
        -(m.rows[3][0] * r0[0] + m.rows[3][1] * r1[0] + m.rows[3][2] * r2[0]),
        -(m.rows[3][0] * r0[1] + m.rows[3][1] * r1[1] + m.rows[3][2] * r2[1]),
        -(m.rows[3][0] * r0[2] + m.rows[3][1] * r1[2] + m.rows[3][2] * r2[2]),
        1.0,
    };

    return Mat4{ .rows = .{ r0, r1, r2, r3 }};
}

pub fn vectorIntersectPlane(
    plane_point: Vec3_SIMD,
    plane_normal: Vec3_SIMD,
    line_start: Vec3_SIMD,
    line_end: Vec3_SIMD
) struct{ intersect: Vec3_SIMD, t: f32 } {
    const normalized = normalize(plane_normal);
    const plane_dot = -dot(normalized, plane_point);
    const ad = dot(line_start, normalized);
    const bd = dot(line_end, normalized);

    const t = (-plane_dot - ad) / (bd - ad);

    const start_to_end = line_end - line_start;
    const intersect = start_to_end * @as(Vec3_SIMD, @splat(t));

    return .{
        .intersect = line_start + intersect,
        .t = t
    };
}

pub fn clipTriangleAgainstPlane(
    plane_point: Vec3_SIMD,
    plane_normal: Vec3_SIMD,
    triangle: Triangle
) ClipResult {
    const normalized = normalize(plane_normal);
    const plane_dp = dot(normalized, plane_point);

    const d0 = dot(normalized, triangle.pa.position) - plane_dp;
    const d1 = dot(normalized, triangle.pb.position) - plane_dp;
    const d2 = dot(normalized, triangle.pc.position) - plane_dp;

    var inside_points: [3]Vec3_SIMD = undefined;
    var outside_points: [3]Vec3_SIMD = undefined;
    var inside_point_count: usize = 0;
    var outside_point_count: usize = 0;

    var inside_texes: [3]Vec2_SIMD = undefined;
    var outside_texes: [3]Vec2_SIMD = undefined;
    var inside_tex_count: usize = 0;
    var outside_tex_count: usize = 0;

    if (d0 >= 0) {
        inside_points[inside_point_count] = triangle.pa.position;
        inside_point_count += 1;

        inside_texes[inside_tex_count] = triangle.pa.uv;
        inside_tex_count += 1;
    } else {
        outside_points[outside_point_count] = triangle.pa.position;
        outside_point_count += 1;

        outside_texes[outside_tex_count] = triangle.pa.uv;
        outside_tex_count += 1;
    }

    if (d1 >= 0) {
        inside_points[inside_point_count] = triangle.pb.position;
        inside_point_count += 1;

        inside_texes[inside_tex_count] = triangle.pb.uv;
        inside_tex_count += 1;
    } else {
        outside_points[outside_point_count] = triangle.pb.position;
        outside_point_count += 1;

        outside_texes[outside_tex_count] = triangle.pb.uv;
        outside_tex_count += 1;
    }

    if (d2 >= 0) {
        inside_points[inside_point_count] = triangle.pc.position;
        inside_point_count += 1;

        inside_texes[inside_tex_count] = triangle.pc.uv;
        inside_tex_count += 1;
    } else {
        outside_points[outside_point_count] = triangle.pc.position;
        outside_point_count += 1;

        outside_texes[outside_tex_count] = triangle.pc.uv;
        outside_tex_count += 1;
    }

    if (inside_point_count == 0) {
        // all points are outside plane, entire triangle is clipped
        return .{ .n = 0, .t1 = null, .t2 = null };
    } else if (inside_point_count == 3) {
        // are points are inside plane, triangle is not clipped
        return .{ .n = 1, .t1 = triangle, .t2 = null };
    } else if (inside_point_count == 1 and outside_point_count == 2) {
        // tri should be clipped. makes one triangle
        const p1 = vectorIntersectPlane(plane_point, plane_normal, inside_points[0], outside_points[0]);
        const p2 = vectorIntersectPlane(plane_point, plane_normal, inside_points[0], outside_points[1]);

        const t1 = Triangle{
            .color = triangle.color,
            .depth = triangle.depth,
            .pa = Vertex{
                .position = inside_points[0],
                .uv = inside_texes[0]
            },
            .pb = Vertex {
                .position = p1.intersect,
                .uv = Vec2_SIMD{
                    p1.t * (outside_texes[0][0] - inside_texes[0][0]) + inside_texes[0][0],
                    p1.t * (outside_texes[0][1] - inside_texes[0][1]) + inside_texes[0][1]
                }
            },
            .pc = Vertex {
                .position = p2.intersect,
                .uv = Vec2_SIMD{
                    p2.t * (outside_texes[1][0] - inside_texes[0][0]) + inside_texes[0][0],
                    p2.t * (outside_texes[1][1] - inside_texes[0][1]) + inside_texes[0][1]
                }
            },
        };

        return .{ .n = 1, .t1 = t1, .t2 = null };
    } else if (inside_point_count == 2 and outside_point_count == 1) {
        // tri should be clipped. makes a quad in the form of two tris
        const p1 = vectorIntersectPlane(plane_point, plane_normal, inside_points[0], outside_points[0]);
        const p2 = vectorIntersectPlane(plane_point, plane_normal, inside_points[1], outside_points[0]);
        const uv1 = Vec2_SIMD{
            p1.t * (outside_texes[0][0] - inside_texes[0][0]) + inside_texes[0][0],
            p1.t * (outside_texes[0][1] - inside_texes[0][1]) + inside_texes[0][1],
        };

        const t1 = Triangle{
            .color = triangle.color,
            .depth = triangle.depth,
            .pa = Vertex{
                .position = inside_points[0],
                .uv = inside_texes[0]
            },
            .pb = Vertex{
                .position = inside_points[1],
                .uv = inside_texes[1]
            },
            .pc = Vertex{
                .position = p1.intersect,
                .uv = uv1
            }
        };

        const t2 = Triangle{
            .color = triangle.color,
            .depth = triangle.depth,
            .pa = Vertex{
                .position = inside_points[1],
                .uv = inside_texes[1]
            },
            .pb = Vertex{
                .position = p1.intersect,
                .uv = uv1
            },
            .pc = Vertex{
                .position = p2.intersect,
                .uv = Vec2_SIMD{
                    p2.t * (outside_texes[0][0] - inside_texes[1][0]) + inside_texes[1][0],
                    p2.t * (outside_texes[0][1] - inside_texes[1][1]) + inside_texes[1][1]
                }
            }
        };

        return .{ .n = 2, .t1 = t1, .t2 = t2 };
    } else unreachable;
}
