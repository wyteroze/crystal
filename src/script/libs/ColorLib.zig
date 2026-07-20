// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const Diagnostic = @import("../shared.zig").Diagnostic;
const Color = @import("../../Color.zig").Color;
const ColorRegistry = @import("../../engine/ColorRegistry.zig").ColorRegistry;

pub const ColorLib = struct {
    pub const hidden = .{ "registry" };
    pub const name = "Color";
    diagnostic: Diagnostic = .{},
    registry: *ColorRegistry,

    pub fn init(colorRegistry: *ColorRegistry) !ColorLib {
        return .{
            .registry = colorRegistry
        };
    }

    pub fn fromName(self: *ColorLib, colorName: []const u8, alpha: ?u8) !Color {
        return self.registry.named(colorName, alpha orelse 255) orelse {
            self.diagnostic.set("no color named '{s}'", .{colorName});
            return error.UnknownColor;
        };
    }

    pub fn fromARGB(_: *ColorLib, a: u8, r: u8, g: u8, b: u8) Color {
        return Color.fromARGB(a, r, g, b);
    }

    pub fn fromHex(self: *ColorLib, hexCode: []const u8) !Color {
        return Color.fromHex(hexCode) catch |e| {
            switch (e) {
                error.InvalidHex => self.diagnostic.set("invalid hex code '{s}', expected AARRGGBB", .{hexCode}),
            }

            return e;
        };
    }
};
