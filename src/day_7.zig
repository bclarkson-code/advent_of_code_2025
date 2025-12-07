const std = @import("std");

const Direction = enum {
    up,
    right,
    left,
    down,
};

const Delta = struct {
    row: isize,
    col: isize,

    fn fromDirection(dir: Direction) Delta {
        return switch (dir) {
            .up => Delta{ .row = -1, .col = 0 },
            .down => Delta{ .row = 1, .col = 0 },
            .left => Delta{ .row = 0, .col = -1 },
            .right => Delta{ .row = 0, .col = 1 },
        };
    }
};

const Point = struct {
    row: usize,
    col: usize,

    fn shift(self: Point, dir: Direction) Point {
        const delta = Delta.fromDirection(dir);

        var n_row: isize = @intCast(self.row);
        var n_col: isize = @intCast(self.col);

        n_row += delta.row;
        n_col += delta.col;

        const row: usize = @intCast(n_row);
        const col: usize = @intCast(n_col);

        return Point{ .row = row, .col = col };
    }
};
const Grid = struct {
    values: []u8,
    visited: []bool,
    count: []u64,
    height: usize,
    width: usize,
    allocator: std.mem.Allocator,
    start: Point,

    fn index(self: Grid, point: Point) usize {
        return point.row * self.width + point.col;
    }

    fn inBounds(self: Grid, point: Point) bool {
        return self.height > point.row and self.width > point.col;
    }

    fn get(self: Grid, point: Point) !u8 {
        if (!self.inBounds(point)) return error.OutOfBounds;
        return self.values[self.index(point)];
    }

    fn set(self: Grid, point: Point, val: u8) !void {
        if (!self.inBounds(point)) return error.OutOfBounds;
        self.values[self.index(point)] = val;
    }

    fn haveVisited(self: Grid, point: Point) !bool {
        if (!self.inBounds(point)) return error.OutOfBounds;
        return self.visited[self.index(point)];
    }

    fn visit(self: Grid, point: Point) !void {
        if (!self.inBounds(point)) return error.OutOfBounds;
        self.visited[self.index(point)] = true;
    }

    fn getCount(self: Grid, point: Point) !u64 {
        if (!self.inBounds(point)) return error.OutOfBounds;
        return self.count[self.index(point)];
    }
    fn setCount(self: Grid, point: Point, val: u64) !void {
        if (!self.inBounds(point)) return error.OutOfBounds;
        self.count[self.index(point)] = val;
    }

    fn print(self: Grid) !void {
        const size: usize = (self.width + 1) * self.height;

        const buf = try self.allocator.alloc(u8, size);
        defer self.allocator.free(buf);

        var val_idx: usize = 0;
        const loc_idx: usize = ((self.start.row * (self.width + 1)) + self.start.col);
        for (0..size) |idx| {
            if (idx % (self.width + 1) == self.width) {
                buf[idx] = '\n';
                continue;
            } else if (idx == loc_idx) {
                buf[idx] = 'S';
                val_idx += 1;
            } else {
                buf[idx] = self.values[val_idx];
                val_idx += 1;
            }
        }
        std.debug.print("{s}", .{buf});
    }
};

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(path, allocator, std.Io.Limit.unlimited);
}

fn toGrid(contents: []u8, allocator: std.mem.Allocator) !Grid {
    const width = std.mem.indexOf(u8, contents, "\n").? + 1;
    const height = contents.len / width;

    const start_idx = std.mem.indexOf(u8, contents, "S").?;
    if (start_idx >= width) return error.InvalidStart;
    const start = Point{ .row = 0, .col = start_idx };

    var visited: []bool = try allocator.alloc(bool, contents.len);
    for (0..visited.len) |i| visited[i] = false;

    var count: []u64 = try allocator.alloc(u64, contents.len);
    for (0..count.len) |i| count[i] = 0;

    return Grid{ .values = contents, .count = count, .visited = visited, .height = height, .width = width, .allocator = allocator, .start = start };
}

fn countSplits(grid: Grid, pos: Point) !usize {
    if (!grid.inBounds(pos)) return 0;
    if (try grid.haveVisited(pos)) return 0;

    const val = try grid.get(pos);
    try grid.visit(pos);

    if (val == '.' or val == 'S') {
        return try countSplits(grid, pos.shift(Direction.down));
    }
    if (val == '^') {
        const left = pos.shift(Direction.left);
        const right = pos.shift(Direction.right);

        const left_total = try countSplits(grid, left);
        const right_total = try countSplits(grid, right);

        return left_total + right_total + 1;
    }
    return error.InvalidCharacter;
}
fn countPaths(grid: Grid, pos: Point) !u64 {
    if (pos.row >= grid.height) return 1;
    if (!grid.inBounds(pos)) return 0;

    const count = try grid.getCount(pos);
    if (count > 0) return count;

    const val = try grid.get(pos);

    if (val == '.' or val == 'S') {
        const retval = try countPaths(grid, pos.shift(Direction.down));
        try grid.setCount(pos, retval);
        return retval;
    }
    if (val == '^') {
        const left = pos.shift(Direction.left);
        const right = pos.shift(Direction.right);

        const left_total = try countPaths(grid, left);
        const right_total = try countPaths(grid, right);

        const total = left_total + right_total;
        try grid.setCount(pos, total);
        return total;
    }
    return error.InvalidCharacter;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const contents = try readFile("/Users/benedictclarkson/Documents/advent_of_code_2025/inputs/day_7.txt", allocator);
    defer allocator.free(contents);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const grid = try toGrid(contents, arena_allocator);

    const splits = try countSplits(grid, grid.start);
    std.debug.print("Part 1: {}\n", .{splits});

    const beams = try countPaths(grid, grid.start);
    std.debug.print("Part 2: {}\n", .{beams});
}
