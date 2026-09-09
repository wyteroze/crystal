// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const desc = @import("desc.zig");

// Export shader stuff
pub fn basicShaderDesc() desc.ShaderDesc {
    const basic = @import("shaders/basic.zig");
    return .{ .stages = &.{
        .{ .stage = .vertex, .source = basic.vs_source, .entrypoint = "main" },
        .{ .stage = .fragment, .source = basic.ps_source, .entrypoint = "main" }
    } };
}