const std = @import("std");

const Symbol = enum { add, mul };

const Column = struct {
    values: [][]const u8,
    op: Symbol,

    fn apply(self: Column) !u64 {
        var buf: [16]u8 = undefined;
        var idx: usize = 0;
        var total: u64 = if (self.op == Symbol.add) 0 else 1;

        for (0..self.values[0].len) |col| {
            for (self.values) |val| {
                if (val[col] != ' ') {
                    buf[idx] = val[col];
                    idx += 1;
                }
            }
            const num = try std.fmt.parseInt(u64, buf[0..idx], 10);
            idx = 0;

            if (self.op == Symbol.add) {
                total += num;
            } else {
                total *= num;
            }
        }
        return total;
    }
};

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(path, allocator, std.Io.Limit.unlimited);
}

fn parseLine(line: []const u8, allocator: std.mem.Allocator) ![]u64 {
    var out = std.ArrayList(u64){};
    var buf: [16]u8 = undefined;
    var buf_idx: usize = 0;
    for (line) |c| {
        if ('0' <= c and c <= '9') {
            buf[buf_idx] = c;
            buf_idx += 1;
            continue;
        }
        if (c == ' ' and buf_idx == 0) continue;
        if (c == ' ' and buf_idx > 0) {
            const num: u64 = try std.fmt.parseInt(u64, buf[0..buf_idx], 10);
            try out.append(allocator, num);
            buf_idx = 0;
            continue;
        }
        if (c == '\n' and buf_idx > 0) {
            const num: u64 = try std.fmt.parseInt(u64, buf[0..buf_idx], 10);
            try out.append(allocator, num);
            buf_idx = 0;
            continue;
        }
    }
    if (buf_idx > 0) {
        const num: u64 = try std.fmt.parseInt(u64, buf[0..buf_idx], 10);
        try out.append(allocator, num);
    }
    return out.items;
}

fn parseSymbolLine(line: []const u8, allocator: std.mem.Allocator) ![]Symbol {
    var out = std.ArrayList(Symbol){};
    for (line) |c| {
        switch (c) {
            '+' => try out.append(allocator, Symbol.add),
            '*' => try out.append(allocator, Symbol.mul),
            ' ' => continue,
            '\n' => continue,
            else => return error.InvalidCharacter,
        }
    }
    return out.items;
}

fn parseFile(contents: []const u8, allocator: std.mem.Allocator) !struct { nums: [][]u64, ops: []Symbol } {
    var lines = std.mem.splitScalar(u8, contents, '\n');
    var rows = std.ArrayList([]u64){};
    var ops: []Symbol = undefined;

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (('0' <= line[0] and line[0] <= '9') or line[0] == ' ') {
            const row: []u64 = try parseLine(line, allocator);
            try rows.append(allocator, row);
            continue;
        }
        if (line[0] == '*' or line[0] == '+') {
            ops = try parseSymbolLine(line, allocator);
        }
    }

    // check lengths match
    const width = rows.items[0].len;
    for (rows.items) |r| {
        if (r.len != width) return error.InconsistentLength;
    }
    if (ops.len != width) return error.InconsistentLength;

    return .{ .nums = rows.items, .ops = ops };
}

fn applyOps(nums: [][]u64, ops: []Symbol) u64 {
    var total: u64 = 0;
    const width: usize = ops.len;
    const height: usize = nums.len;

    for (0..width) |col| {
        const symbol = ops[col];
        var row_total: u64 = if (symbol == Symbol.add) 0 else 1;

        for (0..height) |row| {
            if (symbol == Symbol.add) {
                row_total += nums[row][col];
            } else {
                row_total *= nums[row][col];
            }
        }
        total += row_total;
    }
    return total;
}

fn parseOps(contents: []const u8, allocator: std.mem.Allocator) !struct { symbols: []Symbol, sizes: []usize } {
    var op_line: []const u8 = undefined;

    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (line[0] != '*' and line[0] != '+') continue;
        op_line = line;
    }
    var sizes = std.ArrayList(usize){};
    var ops = std.ArrayList(Symbol){};
    var size: usize = 0;
    for (op_line) |op| {
        if (op != '*' and op != '+') {
            size += 1;
            continue;
        }
        switch (op) {
            '+' => try ops.append(allocator, Symbol.add),
            '*' => try ops.append(allocator, Symbol.mul),
            else => return error.InvalidCharacter,
        }

        if (size == 0) continue;

        try sizes.append(allocator, size + 1);
        size = 0;
    }
    try sizes.append(allocator, size + 2);

    return .{ .symbols = ops.items, .sizes = sizes.items };
}
fn parseFileToString(contents: []const u8, allocator: std.mem.Allocator) ![]Column {
    const ops = try parseOps(contents, allocator);

    const width = std.mem.indexOf(u8, contents, "\n").?;
    const height = contents.len / width;

    var columns = std.ArrayList(Column){};
    var col_values = std.ArrayList([]const u8){};
    var idx: usize = 0;

    for (ops.symbols, ops.sizes) |symbol, size| {
        col_values = .empty;
        for (0..(height - 1)) |row| {
            const start = (row * (width + 1)) + idx;
            const end = start + size - 1;
            try col_values.append(allocator, contents[start..end]);
        }
        idx += size;
        const column = Column{ .values = col_values.items, .op = symbol };
        try columns.append(allocator, column);
    }
    return columns.items;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const contents = try readFile("/Users/benedictclarkson/Documents/advent_of_code_2025/inputs/day_6.txt", allocator);
    defer allocator.free(contents);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const parsed = try parseFile(contents, arena_allocator);
    const part_1_total = applyOps(parsed.nums, parsed.ops);
    std.debug.print("Part 1: {}\n", .{part_1_total});

    var total: u64 = 0;
    const columns = try parseFileToString(contents, arena_allocator);
    for (columns) |col| {
        total += try col.apply();
    }
    std.debug.print("Part 2: {}\n", .{total});
}
