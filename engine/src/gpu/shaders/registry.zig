const std = @import("std");

const module_sources = std.StaticStringMap([:0]const u8).initComptime(&.{
    .{ "lighting", @embedFile("src/lighting.slang") },
    .{ "basic", @embedFile("src/basic.slang") }
});

pub fn lookupShaderModule(name: []const u8) ?[:0]const u8 {
    return module_sources.get(name);
}