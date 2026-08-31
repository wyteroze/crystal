// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

const BindingScan = @This();

pub fn findBindingPaths(io: std.Io, allocator: std.mem.Allocator, registry_path: []const u8) ![][]const u8 {
    const source = try std.Io.Dir.readFileAlloc(.cwd(), io, registry_path, allocator, .unlimited);
    const source_z = try allocator.dupeSentinel(u8, source, 0);

    const ast = try std.zig.Ast.parse(allocator, source_z, .zig);
    if (ast.errors.len > 0) return error.RegistryHasErrors;

    var paths: std.ArrayList([]const u8) = .empty;
    
    const bindings_init = findBindingsInitNode(&ast) orelse return error.BindingsDeclNotFound;

    var elem_buf: [2]std.zig.Ast.Node.Index = undefined;
    const elems = arrayInitElements(&ast, bindings_init, &elem_buf) orelse return error.BindingsNotAnArrayInit;

    for (elems) |e| {
        const import_path = importPathFromBuiltinCall(&ast, e) orelse continue;
        try paths.append(allocator, try allocator.dupe(u8, import_path));
    }

    return paths.toOwnedSlice(allocator);
}

fn findBindingsInitNode(ast: *const std.zig.Ast) ?std.zig.Ast.Node.Index {
    for (ast.rootDecls()) |d| {
        switch (ast.nodeTag(d)) {
            .simple_var_decl, .local_var_decl, .global_var_decl, .aligned_var_decl => {},
            else => continue
        }

        const var_decl = ast.fullVarDecl(d) orelse continue;
        const name_tok = var_decl.ast.mut_token+1; // the token after the const/var keyword
        const name = ast.tokenSlice(name_tok);
        if (!std.mem.eql(u8, name, "bindings")) continue;

        return var_decl.ast.init_node.unwrap() orelse continue;
    }

    return null;
}

fn arrayInitElements(
    ast: *const std.zig.Ast,
    node: std.zig.Ast.Node.Index,
    buf: *[2]std.zig.Ast.Node.Index
) ?[]const std.zig.Ast.Node.Index {
    return switch (ast.nodeTag(node)) {
        .array_init_dot_two, .array_init_dot_two_comma => blk: {
            const opt_pair = ast.nodeData(node).opt_node_and_opt_node;
            var len: usize = 0;

            if (opt_pair[0].unwrap()) |n| { buf[len] = n; len += 1; }
            if (opt_pair[1].unwrap()) |n| { buf[len] = n; len += 1; }

            break :blk buf[0..len];
        },
        .array_init_dot, .array_init_dot_comma => blk: {
            const range = ast.nodeData(node).extra_range;
            break :blk ast.extraDataSlice(range, std.zig.Ast.Node.Index);
        },
        else => null
    };
}

/// If `node` is `@import("some/path.zig")`, returns the unquoted string, otherwise null
fn importPathFromBuiltinCall(ast: *const std.zig.Ast, node: std.zig.Ast.Node.Index) ?[]const u8 {
    var arg_buf: [2]std.zig.Ast.Node.Index = undefined;

    const args: []const std.zig.Ast.Node.Index = switch (ast.nodeTag(node)) {
        .builtin_call_two, .builtin_call_two_comma => blk: {
            const opt_pair = ast.nodeData(node).opt_node_and_opt_node;
            var len: usize = 0;

            if (opt_pair[0].unwrap()) |n| { arg_buf[len] = n; len += 1; }
            if (opt_pair[1].unwrap()) |n| { arg_buf[len] = n; len += 1; }

            break :blk arg_buf[0..len];
        },
        .builtin_call, .builtin_call_comma => blk: {
            const range = ast.nodeData(node).extra_range;
            break :blk ast.extraDataSlice(range, std.zig.Ast.Node.Index);
        },
        else => return null,
    };

    const builtin_token = ast.nodeMainToken(node);
    const builtin_name = ast.tokenSlice(builtin_token);
    if (!std.mem.eql(u8, builtin_name, "@import")) return null;
    if (args.len != 1) return null;
    if (ast.nodeTag(args[0]) != .string_literal) return null;

    const str_token = ast.nodeMainToken(args[0]);
    const raw = ast.tokenSlice(str_token); // includes the surrounding quotes
    return unescapeStringLiteral(raw);
}

fn unescapeStringLiteral(raw: []const u8) []const u8 {
    std.debug.assert(raw.len >= 2 and raw[0] == '"' and raw[raw.len - 1] == '"');

    return raw[1 .. raw.len - 1];
}