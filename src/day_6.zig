const std = @import("std");

const Symbol = enum { add, mul };

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

fn parseVertically(contents: []const u8, allocator: std.mem.Allocator) !u64 {
    const width = std.mem.indexOf(u8, contents, "\n").?;
    const height = contents.len / width;
    var buf = try allocator.alloc(u8, height - 1);
    var buf_idx: usize = 0;
    var symbol: usize = ' ';
    var col_total: u64 = 0;
    var total: u64 = 0;

    for (0..width) |col| {
        const symbol_idx = ((width + 1) * (height - 1)) + col;
        const symbol_val = contents[symbol_idx];
        if (symbol_val == '+') {
            symbol = symbol_val;
            total += col_total;
            col_total = 0;
        } else if (symbol_val == '*') {
            symbol = symbol_val;
            total += col_total;
            col_total = 1;
        }

        for (0..(height - 1)) |row| {
            const idx: usize = (row * (width + 1)) + col;
            const val: u8 = contents[idx];

            if (val == ' ') continue;

            buf[buf_idx] = val;
            buf_idx += 1;
        }
        if (buf_idx == 0) continue;
        const num = try std.fmt.parseInt(u64, buf[0..buf_idx], 10);
        buf_idx = 0;

        if (symbol == '+') {
            col_total += num;
        } else {
            col_total *= num;
        }
    }
    total += col_total;
    return total;
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

    const total: u64 = try parseVertically(contents, arena_allocator);
    std.debug.print("Part 2: {}\n", .{total});
}
