const std = @import("std");
const BindingScan = @import("BindingScan.zig");

pub fn main(init: std.process.Init) !void {
    std.log.debug("[docgen] starting...", .{});

    // we'll just use an arena allocator, this isn't memory-critical shit
    const arena = init.arena.allocator();
    const io = init.io;

    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();

    var registry_path: ?[]const u8 = null;
    var out_dir: ?[]const u8 = null;

    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "--registry")) {
            registry_path = args.next() orelse return error.MissingArg;
        } else if (std.mem.eql(u8, a, "--out")) {
            out_dir = args.next() orelse return error.MissingArg;
        }
    }

    if (registry_path) |p| std.log.debug("[docgen] registry path provided: '{s}'", .{ p });
    if (out_dir) |d| std.log.debug("[docgen] output path provided: '{s}'", .{ d });

    std.log.debug("searching for binding paths...", .{});
    const paths = try BindingScan.findBindingPaths(io, arena, registry_path.?);

    std.log.debug("[docgen]: found these binding paths ({d} total):", .{ paths.len });
    for (paths) |p| {
        std.log.debug("{s}", .{ p });
    }
}