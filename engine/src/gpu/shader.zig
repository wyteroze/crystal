// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const desc = @import("desc.zig");

// Export shader stuff
pub fn basicShaderDesc() desc.ShaderDesc {
    const source = @embedFile("shaders/src/basic.slang");
    return .{ .stages = &.{
        .{ .name = "BasicShader: vertex", .stage = .vertex, .source = source, .entrypoint = "vertexMain" },
        .{ .name = "BasicShader: pixel", .stage = .fragment, .source = source, .entrypoint = "fragmentMain" }
    } };
}

pub fn depthPrepassShaderDesc() desc.ShaderDesc {
    const source = @embedFile("shaders/src/depth_prepass.slang");
    return .{ .stages = &.{
        .{ .name = "DepthPrepassShader: vertex", .stage = .vertex, .source = source, .entrypoint = "vertexMain" },
        .{ .name = "DepthPrepassShader: pixel", .stage = .fragment, .source = source, .entrypoint = "fragmentMain" }
    } };
}

pub fn lightCullShaderDesc() desc.ShaderDesc {
    const source = @embedFile("shaders/src/light_cull.slang");
    return .{ .stages = &.{
        .{ .name = "LightCullShader: compute", .stage = .compute, .source = source, .entrypoint = "computeMain" }
    } };
}