// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const desc = @import("desc.zig");

// Export shader stuff
pub fn basicShaderDesc() desc.ShaderDesc {
    const basic = @import("shaders/basic.zig");
    return .{ .stages = &.{
        .{ .name = "BasicShader: vertex", .stage = .vertex, .source = basic.source, .entrypoint = "vertexMain" },
        .{ .name = "BasicShader: pixel", .stage = .fragment, .source = basic.source, .entrypoint = "fragmentMain" }
    } };
}
