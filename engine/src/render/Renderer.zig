// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const gpu = @import("../gpu/gpu.zig");
const assets = @import("../assets/Assets.zig");
const types = @import("types.zig");
const core = @import("../core/core.zig");
const RenderGraph = @import("RenderGraph.zig");
const resource = @import("resource.zig");
const pass = @import("pass/pass.zig");
const math = core.math;
const Color = core.Color;

// Max size of the lights ssbo. In the future
// the buffer should be able to resize, so this
// would be unneeded.
const max_lights = 256;

const Renderer = @This();
allocator: std.mem.Allocator,
/// Freed at the end of every frame. Always use this instead
/// of a regular allocator when possible because it's way faster.
frame_allocator: std.heap.ArenaAllocator,
gpu_device: *gpu.GpuDevice,
graph: RenderGraph,
sampler: gpu.GpuDevice.GpuSampler,
shader: gpu.GpuDevice.GpuShader,
surface_size: [2]u32,
default_image: gpu.GpuDevice.GpuImage,
default_quad: assets.types.GpuMesh,
lights_ssbo: gpu.GpuDevice.GpuBuffer,
depth_image: gpu.GpuDevice.GpuImage,

pub fn init(allocator: std.mem.Allocator, surface_size: [2]u32, gpu_device: *gpu.GpuDevice, skybox_cubemap: gpu.GpuDevice.GpuImage) !Renderer {
    var graph: RenderGraph = .init(allocator);
    errdefer graph.deinit();

    const depth_shader = try gpu_device.createShader(gpu.shaders.depthPrepassShaderDesc());
    const depth_prepass = try allocator.create(pass.DepthPrepassPass);
    errdefer allocator.destroy(depth_prepass);
    depth_prepass.* = try .init(gpu_device, depth_shader);

    const skybox_shader = try gpu_device.createShader(gpu.shaders.skyboxShaderDesc());
    const skybox_pass = try allocator.create(pass.SkyboxPass);
    errdefer allocator.destroy(skybox_pass);
    skybox_pass.* = try .init(gpu_device, skybox_shader, skybox_cubemap);

    const light_cull_shader = try gpu_device.createShader(gpu.shaders.lightCullShaderDesc());
    const light_cull_pass = try allocator.create(pass.LightCullPass);
    errdefer allocator.destroy(light_cull_pass);
    light_cull_pass.* = try .init(gpu_device, light_cull_shader, surface_size);

    const shader = try gpu_device.createShader(gpu.shaders.basicShaderDesc());
    const forward_pass = try allocator.create(pass.ForwardPass);
    errdefer allocator.destroy(forward_pass);
    forward_pass.* = try .init(gpu_device, shader, .fromRgbFloat(0.1, 0.1, 0.1, 1.0));

    try graph.addNode(depth_prepass.node());
    try graph.addNode(skybox_pass.node());
    try graph.addNode(light_cull_pass.node());
    try graph.addNode(forward_pass.node());
    try graph.markExternal(resource.lights_buffer);
    try graph.compile();

    return .{ 
        .allocator = allocator, 
        .frame_allocator = .init(allocator),
        .gpu_device = gpu_device,
        .graph = graph,
        .sampler = try gpu_device.createSampler(.{}),
        .shader = shader,
        .surface_size = surface_size,
        .default_image = try gpu_device.createImage(.{
            .name = "Default image",
            .width = 1, .height = 1,
            .format = .rgba8,
            .data = &.{ 0xFF, 0xFF, 0xFF, 0xFF }
        }),
        .default_quad = .{
            .vertex_buffer = try gpu_device.createBuffer(.{
                .name = "Default quad vertex buffer",
                .data = std.mem.sliceAsBytes(([_]assets.types.Vertex{
                    .{ .position = .{ -0.5,  0.5, 0 }, .normal = .{ 0, 0, 1 }, .uv = .{ 0, 0 } },
                    .{ .position = .{  0.5,  0.5, 0 }, .normal = .{ 0, 0, 1 }, .uv = .{ 1, 0 } },
                    .{ .position = .{ -0.5, -0.5, 0 }, .normal = .{ 0, 0, 1 }, .uv = .{ 0, 1 } },
                    .{ .position = .{  0.5, -0.5, 0 }, .normal = .{ 0, 0, 1 }, .uv = .{ 1, 1 } },
                })[0..]),
                .size = 4,
            }),
            .index_buffer = try gpu_device.createBuffer(.{
                .name = "Default quad index buffer",
                .data = std.mem.sliceAsBytes(([_]u32{
                    0, 2, 1,
                    1, 2, 3
                })[0..])
            }),
            .vertex_count = 4,
            .index_count = 6
        },
        .lights_ssbo = try gpu_device.createBuffer(.{
            .name = "Lights storage buffer",
            .type = .storage,
            .usage = .default,
            .size = max_lights * @sizeOf(gpu.types.GpuLight),
            .stride = @sizeOf(gpu.types.GpuLight)
        }),
        .depth_image = try gpu_device.createImage(.{
            .name = "Depth buffer",
            .width = surface_size[0],
            .height = surface_size[1],
            .format = .d32
        }),
    };
}

pub fn deinit(self: *Renderer) void {
    self.graph.deinit();
    self.sampler.deinit();
    self.shader.deinit();
    self.default_image.deinit();
    self.default_quad.deinit();
    self.frame_allocator.deinit();
    self.depth_image.deinit();
}

pub fn render(self: *Renderer, view: types.RenderView, scene: types.RenderScene) !void {
    std.debug.assert(scene.lights.items.len <= max_lights);
    self.lights_ssbo.update(std.mem.sliceAsBytes(scene.lights.items));
    
    self.graph.resources.map.clearRetainingCapacity();
    try self.graph.resources.put(resource.lights_buffer, .{ .storage_buffer = self.lights_ssbo.handle });
    try self.graph.resources.put(resource.depth_buffer, .{ .image = self.depth_image.handle });
    
    const ctx: pass.PassContext = .{
        .device = self.gpu_device,
        .view = &view,
        .scene = &scene,
        .resources = &self.graph.resources,
        .frame_allocator = self.frame_allocator.allocator()
    };

    self.graph.execute(ctx);
    self.gpu_device.present();
    if (!self.frame_allocator.reset(.retain_capacity)) std.log.err("Frame allocator reset failed", .{});
}