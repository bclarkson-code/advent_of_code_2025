const std = @import("std");

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(path, allocator, std.Io.Limit.unlimited);
}

fn toGrid(contents: []const u8, allocator: std.mem.Allocator) ![][]u8 {
    const width = std.mem.indexOfScalar(u8, contents, '\n').?;
    const height = contents.len / width;

    var grid = try allocator.alloc([]u8, height);
    errdefer allocator.free(grid);

    for (grid) |*row| {
        row.* = try allocator.alloc(u8, width);
    }
    errdefer for (grid) |row| allocator.free(row);

    var lines = std.mem.splitScalar(u8, contents, '\n');
    var row: usize = 0;
    while (lines.next()) |line| : (row += 1) {
        if (line.len == 0) continue;

        for (line, 0..width) |c, col| {
            if (c == '\n') continue;
            grid[row][col] = c;
        }
    }
    return grid;
}

fn countAccessible(grid: [][]u8) u64 {
    const deltas: [8][2]isize = .{
        .{ -1, -1 },
        .{ -1, 0 },
        .{ -1, 1 },
        .{ 0, -1 },
        .{ 0, 1 },
        .{ 1, -1 },
        .{ 1, 0 },
        .{ 1, 1 },
    };

    const height = grid.len;
    const width = grid[0].len;
    var total: u64 = 0;

    for (0..height) |row| {
        for (0..width) |col| {
            if (grid[row][col] != '@') continue;

            var count: usize = 0;
            for (deltas) |d| {
                const next_row: isize = @as(isize, @intCast(row)) + d[0];
                const next_col: isize = @as(isize, @intCast(col)) + d[1];

                if (next_row < 0 or next_row >= height) continue;
                if (next_col < 0 or next_col >= width) continue;

                const row_idx: usize = @intCast(next_row);
                const col_idx: usize = @intCast(next_col);

                if (grid[row_idx][col_idx] == '@') count += 1;
            }
            if (count < 4) total += 1;
        }
    }

    return total;
}
fn removeAccessible(grid: [][]u8) u64 {
    const deltas: [8][2]isize = .{
        .{ -1, -1 },
        .{ -1, 0 },
        .{ -1, 1 },
        .{ 0, -1 },
        .{ 0, 1 },
        .{ 1, -1 },
        .{ 1, 0 },
        .{ 1, 1 },
    };

    const height = grid.len;
    const width = grid[0].len;
    var total: u64 = 0;

    for (0..height) |row| {
        for (0..width) |col| {
            if (grid[row][col] != '@') continue;

            var count: usize = 0;
            for (deltas) |d| {
                const next_row: isize = @as(isize, @intCast(row)) + d[0];
                const next_col: isize = @as(isize, @intCast(col)) + d[1];

                if (next_row < 0 or next_row >= height) continue;
                if (next_col < 0 or next_col >= width) continue;

                const row_idx: usize = @intCast(next_row);
                const col_idx: usize = @intCast(next_col);

                if (grid[row_idx][col_idx] == '@') count += 1;
            }
            if (count < 4) {
                grid[row][col] = '.';
                total += 1;
            }
        }
    }

    return total;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const contents = try readFile("/Users/benedictclarkson/Documents/advent_of_code_2025/inputs/day_4.txt", allocator);
    defer allocator.free(contents);

    const grid = try toGrid(contents, allocator);
    defer {
        for (grid) |row| allocator.free(row);
        allocator.free(grid);
    }

    const count = countAccessible(grid);
    std.debug.print("Part 1: {}\n", .{count});

    var total_removed: u64 = 0;
    var removed: u64 = removeAccessible(grid);
    while (removed > 0) {
        total_removed += removed;
        removed = removeAccessible(grid);
    }
    std.debug.print("Part 2: {}\n", .{total_removed});
}
