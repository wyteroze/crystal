// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const log = @import("../log.zig").toml;

pub const ParseError = error{
    InvalidSyntax,
    InvalidKey,
    InvalidNumber,
    UnclosedString,
    InvalidEscape,
    UnclosedArray,
};

pub const TomlTable = std.StringHashMap(TomlValue);

pub const TomlValue = union(enum) {
    string: []const u8,
    integer: i64,
    float: f64,
    boolean: bool,
    array: []TomlValue,
    table: *TomlTable,

    pub fn deinit(self: *TomlValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .array => |arr| {
                for (arr) |*v| v.deinit(allocator);
                allocator.free(arr);
            },
            .table => |t| {
                deinitTable(t, allocator);
                allocator.destroy(t);
            },
            else => {},
        }
    }
};

/// Call this to free every key and value in `table`, and table's own storage.
/// You still need to free *TomlTable after calling this.
pub fn deinitTable(table: *TomlTable, allocator: std.mem.Allocator) void {
    var it = table.iterator();
    while (it.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        entry.value_ptr.deinit(allocator);
    }

    table.deinit();
}

/// Remember to free the returned table by doing `deinitTable(root, allocator)`, then `allocator.destroy(root)`.
pub fn parseToml(allocator: std.mem.Allocator, reader: *std.Io.Reader) !*TomlTable {
    log.debug("parsing toml", .{});

    const root = try createTable(allocator);
    errdefer {
        deinitTable(root, allocator);
        allocator.destroy(root);
    }

    var current: *TomlTable = root;

    while (try reader.takeDelimiter('\n')) |raw_line| {
        const line = trim(stripComment(raw_line));
        if (line.len == 0) continue;

        if (line[0] == '[') {
            if (line[line.len - 1] != ']') {
                log.warn("incorrect section header: '{s}'", .{line});
                return ParseError.InvalidSyntax;
            }

            current = try resolveSection(allocator, root, line[1 .. line.len - 1]);
            continue;
        }

        const eq = std.mem.indexOfScalar(u8, line, '=') orelse {
            log.warn("line missing '=': '{s}'", .{line});
            return ParseError.InvalidSyntax;
        };

        const key = trim(line[0..eq]);
        if (key.len == 0) return ParseError.InvalidKey;

        var value = try parseValue(allocator, trim(line[eq + 1 ..]));
        errdefer value.deinit(allocator);

        try putKey(allocator, current, key, value);
    }

    return root;
}

fn createTable(allocator: std.mem.Allocator) !*TomlTable {
    const table = try allocator.create(TomlTable);
    table.* = TomlTable.init(allocator);

    return table;
}

fn resolveSection(allocator: std.mem.Allocator, root: *TomlTable, path: []const u8) !*TomlTable {
    var current = root;
    var it = std.mem.splitScalar(u8, path, '.');
    while (it.next()) |raw_segment| {
        const segment = trim(raw_segment);
        if (segment.len == 0) return ParseError.InvalidKey;

        const gop = try current.getOrPut(segment);
        if (!gop.found_existing) {
            gop.key_ptr.* = try allocator.dupe(u8, segment);
            gop.value_ptr.* = .{ .table = try createTable(allocator) };
        }

        current = switch (gop.value_ptr.*) {
            .table => |t| t,
            else => {
                log.warn("section path '{s}' collides with a non-table key", .{path});
                return ParseError.InvalidKey;
            },
        };
    }

    return current;
}

fn putKey(allocator: std.mem.Allocator, table: *TomlTable, key: []const u8, value: TomlValue) !void {
    const gop = try table.getOrPut(key);
    if (gop.found_existing) {
        log.warn("duplicate key '{s}', overwriting", .{key});
        gop.value_ptr.deinit(allocator);
    } else {
        gop.key_ptr.* = try allocator.dupe(u8, key);
    }

    gop.value_ptr.* = value;
}

fn parseValue(allocator: std.mem.Allocator, str: []const u8) ParseError!TomlValue {
    if (str.len == 0) return ParseError.InvalidSyntax;

    if (str[0] == '"') return parseString(allocator, str);
    if (str[0] == '[') return parseArray(allocator, str);
    if (std.mem.eql(u8, str, "true")) return .{ .boolean = true };
    if (std.mem.eql(u8, str, "false")) return .{ .boolean = false };

    return parseNumber(str);
}

fn parseString(allocator: std.mem.Allocator, str: []const u8) ParseError!TomlValue {
    var buf = std.ArrayList(u8).empty;
    errdefer buf.deinit(allocator);

    // 0 is opening quote, just skip that
    var i: usize = 1;
    while (i < str.len) : (i += 1) {
        switch (str[i]) {
            '\\' => {
                i += 1;
                if (i >= str.len) return ParseError.UnclosedString;
                const decoded: u8 = switch (str[i]) {
                    'n' => '\n',
                    't' => '\t',
                    'r' => '\r',
                    '"' => '"',
                    '\\' => '\\',
                    '0' => 0,
                    else => return ParseError.InvalidEscape,
                };

                buf.append(allocator, decoded) catch return ParseError.UnclosedString;
            },

            '"' => return .{ .string = buf.toOwnedSlice(allocator) catch return ParseError.UnclosedString },
            else => |c| buf.append(allocator, c) catch return ParseError.UnclosedString,
        }
    }
    return ParseError.UnclosedString;
}

fn parseArray(allocator: std.mem.Allocator, str: []const u8) ParseError!TomlValue {
    if (str[str.len - 1] != ']') return ParseError.UnclosedArray;
    const inner = str[1 .. str.len - 1];

    var values = std.ArrayList(TomlValue).empty;
    errdefer {
        for (values.items) |*v| v.deinit(allocator);
        values.deinit(allocator);
    }

    var depth: usize = 0;
    var in_string = false;
    var start: usize = 0;
    var i: usize = 0;
    while (i < inner.len) : (i += 1) {
        const c = inner[i];
        if (in_string) {
            if (c == '\\') i += 1
            else if (c == '"') in_string = false;
            continue;
        }
        switch (c) {
            '"' => in_string = true,
            '[' => depth += 1,
            ']' => depth -= 1,
            ',' => if (depth == 0) {
                try appendElement(allocator, &values, inner[start..i]);
                start = i + 1;
            },
            else => {},
        }
    }

    try appendElement(allocator, &values, inner[start..]);
    return .{ .array = values.toOwnedSlice(allocator) catch return ParseError.UnclosedArray };
}

fn appendElement(allocator: std.mem.Allocator, values: *std.ArrayList(TomlValue), raw: []const u8) ParseError!void {
    const elem = trim(raw);
    if (elem.len == 0) return;

    const value = try parseValue(allocator, elem);
    values.append(allocator, value) catch return ParseError.UnclosedArray;
}

fn parseNumber(str: []const u8) !TomlValue {
    if (std.fmt.parseInt(i64, str, 0) catch null) |i| {
        return .{ .integer = i };
    } else {}

    if (std.fmt.parseFloat(f64, str) catch null) |f| {
        return .{ .float = f };
    } else {}

    log.warn("could not parse value as number or bool: '{s}'", .{str});
    return ParseError.InvalidNumber;
}

fn stripComment(line: []const u8) []const u8 {
    var in_string = false;
    var i: usize = 0;
    while (i < line.len) : (i += 1) {
        const c = line[i];
        if (in_string) {
            if (c == '\\') i += 1
            else if (c == '"') in_string = false;
        } else if (c == '"') {
            in_string = true;
        } else if (c == '#') {
            return line[0..i];
        }
    }

    return line;
}

fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r");
}
