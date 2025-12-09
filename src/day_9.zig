const std = @import("std");

const LocList = std.ArrayList([2]u64);
const PointList = std.ArrayList(*Point);
const ListMap = std.AutoHashMap(u64, *LocList);
const PointMap = std.AutoHashMap([2]u64, *Point);

const Point = struct {
    y: u64,
    x: u64,
    next: *Point = undefined,
    prev: *Point = undefined,

    fn attachNeighbours(self: *Point, prev: *Point, rows: ListMap, cols: ListMap, points: PointMap) !void {
        const prev_is_hor = prev.y == self.y;
        var next: *Point = undefined;
        if (prev_is_hor) {
            var col = cols.get(self.x).?.items;
            const ver_neighbour = if (col[0][1] == self.y) col[1] else col[0];
            next = points.get(ver_neighbour).?;
        } else {
            var row = rows.get(self.y).?.items;
            const hor_neighbour = if (row[0][0] == self.x) row[1] else row[0];
            next = points.get(hor_neighbour).?;
        }
        self.prev = prev;
        self.next = next;
    }

    fn print(self: Point) void {
        std.debug.print("Point(.y={}, .x={}, .next=({}, {}), .prev=({}, {}))\n", .{
            self.y,
            self.x,
            self.next.y,
            self.next.x,
            self.prev.y,
            self.prev.x,
        });
    }
};

const Hull = struct {
    points: []*Point,

    pub fn init(point: *Point, allocator: std.mem.Allocator) !*Hull {
        var point_list = PointList{};
        defer point_list.deinit(allocator);

        const start_ptr = point;
        try point_list.append(allocator, start_ptr);
        var curr = point.next;

        while (curr != start_ptr) {
            try point_list.append(allocator, curr);
            curr = curr.next;
        }

        const points = try point_list.toOwnedSlice(allocator);

        const hull = try allocator.create(Hull);
        hull.* = .{
            .points = points,
        };

        return hull;
    }

    pub fn deinit(self: *Hull, allocator: std.mem.Allocator) void {
        for (self.points) |p| {
            allocator.destroy(p);
        }
        allocator.free(self.points);
        allocator.destroy(self);
    }

    // count how many edges are to the right of this point (ray casting)
    pub fn isInside(self: Hull, point: Point) !bool {
        var crosses: usize = 0;

        for (self.points) |curr| {
            const next = curr.next;

            if (curr.x == next.x) {
                // on vertical edge
                if (point.x == curr.x) {
                    const min_y = @min(curr.y, next.y);
                    const max_y = @max(curr.y, next.y);
                    if (point.y >= min_y and point.y <= max_y) return true;
                }
            } else {
                // on horizontal edge
                if (point.y == curr.y) {
                    const min_x = @min(curr.x, next.x);
                    const max_x = @max(curr.x, next.x);
                    if (point.x >= min_x and point.x <= max_x) return true;
                }
            }
            // edge is horizontal -> ignore
            if (next.y == curr.y) continue;
            // edge to the left -> ignore
            if (curr.x < point.x) continue;

            const min_y = @min(curr.y, next.y);
            const max_y = @max(curr.y, next.y);
            if (point.y >= min_y and point.y < max_y) {
                crosses += 1;
            }
        }

        return crosses % 2 == 1;
    }
    pub fn edgesIntersect(self: Hull, point_1: Point, next_1: Point, point_2: Point, next_2: Point) bool {
        _ = self;

        // parallel -> ignore
        if (point_1.x == next_1.x and point_2.x == next_2.x) return false;
        if (point_1.y == next_1.y and point_2.y == next_2.y) return false;

        // 1 vertical, 2 horizontal
        if (point_1.x == next_1.x) {
            const min_y1 = @min(point_1.y, next_1.y);
            const max_y1 = @max(point_1.y, next_1.y);
            if (point_2.y <= min_y1 or point_2.y >= max_y1) return false;

            const min_x2 = @min(point_2.x, next_2.x);
            const max_x2 = @max(point_2.x, next_2.x);
            if (point_1.x <= min_x2 or point_1.x >= max_x2) return false;

            return true;
        }

        // 1 horizontal, 2 vertical
        if (point_1.y == next_1.y) {
            const min_y2 = @min(point_2.y, next_2.y);
            const max_y2 = @max(point_2.y, next_2.y);
            if (point_1.y <= min_y2 or point_1.y >= max_y2) return false;

            const min_x1 = @min(point_1.x, next_1.x);
            const max_x1 = @max(point_1.x, next_1.x);
            if (point_2.x <= min_x1 or point_2.x >= max_x1) return false;

            return true;
        }
        unreachable;
    }
    pub fn overflows(self: Hull, point_1: *Point, point_2: *Point) !bool {
        var top: *Point = undefined;
        var bot: *Point = undefined;
        if (point_1.y < point_2.y) {
            top = point_1;
            bot = point_2;
        } else {
            top = point_2;
            bot = point_1;
        }
        var left: *Point = undefined;
        var right: *Point = undefined;
        if (point_1.x < point_2.x) {
            left = point_1;
            right = point_2;
        } else {
            left = point_2;
            right = point_1;
        }

        // if any of our corners are outside then we overflow
        const tl_inside = try self.isInside(.{ .x = left.x, .y = top.y });
        const bl_inside = try self.isInside(.{ .x = left.x, .y = bot.y });
        const tr_inside = try self.isInside(.{ .x = right.x, .y = top.y });
        const br_inside = try self.isInside(.{ .x = right.x, .y = bot.y });

        if (!tl_inside or !bl_inside or !tr_inside or !br_inside) return true;

        // if any of our edges intersect fully with others, then we overflow
        const top_left = Point{ .x = left.x, .y = top.y };
        const top_right = Point{ .x = right.x, .y = top.y };
        const bot_left = Point{ .x = left.x, .y = bot.y };
        const bot_right = Point{ .x = right.x, .y = bot.y };

        for (self.points) |curr| {
            const next = curr.next;
            if (self.edgesIntersect(top_left, top_right, curr.*, next.*)) return true;
            if (self.edgesIntersect(bot_left, bot_right, curr.*, next.*)) return true;
            if (self.edgesIntersect(top_left, bot_left, curr.*, next.*)) return true;
            if (self.edgesIntersect(top_right, bot_right, curr.*, next.*)) return true;
        }

        return false;
    }
};

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(path, allocator, std.Io.Limit.unlimited);
}

fn parseLocs(contents: []u8, allocator: std.mem.Allocator) ![][2]u64 {
    var locs = std.ArrayList([2]u64){};

    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var tokens = std.mem.splitScalar(u8, line, ',');
        const num_1 = try std.fmt.parseInt(u64, tokens.next().?, 10);
        const num_2 = try std.fmt.parseInt(u64, tokens.next().?, 10);

        const loc: [2]u64 = .{ num_1, num_2 };

        try locs.append(allocator, loc);
    }
    return locs.toOwnedSlice(allocator);
}

fn largestRectangle(locs: [][2]u64) u64 {
    var largest: u64 = 0;
    var diff: [2]u64 = .{ 0, 0 };

    for (0..locs.len - 1) |left_idx| {
        const left = locs[left_idx];
        for (left_idx..locs.len) |right_idx| {
            const right = locs[right_idx];

            if (right[0] > left[0]) {
                diff[0] = right[0] - left[0] + 1;
            } else {
                diff[0] = left[0] - right[0] + 1;
            }

            if (right[1] > left[1]) {
                diff[1] = right[1] - left[1] + 1;
            } else {
                diff[1] = left[1] - right[1] + 1;
            }

            const size = diff[0] * diff[1];

            if (size > largest) {
                largest = size;
            }
        }
    }
    return largest;
}
fn largestRectangleInside(points: []*Point, hull: *Hull) !u64 {
    var largest: u64 = 0;
    var row_diff: u64 = 0;
    var col_diff: u64 = 0;

    for (0..points.len - 1) |left_idx| {
        const left = points[left_idx];
        for (left_idx + 1..points.len) |right_idx| {
            const right = points[right_idx];

            if (try hull.overflows(left, right)) continue;

            if (right.y > left.y) {
                row_diff = right.y - left.y + 1;
            } else {
                row_diff = left.y - right.y + 1;
            }

            if (right.x > left.x) {
                col_diff = right.x - left.x + 1;
            } else {
                col_diff = left.x - right.x + 1;
            }

            const size = row_diff * col_diff;

            if (size > largest) {
                left.print();
                right.print();
                std.debug.print("size: {}\n", .{size});
                std.debug.print("\n", .{});
                largest = size;
            }
        }
    }
    return largest;
}

fn buildHull(locs: [][2]u64, allocator: std.mem.Allocator) !*Hull {
    var rows = std.AutoHashMap(u64, *LocList).init(allocator);
    defer {
        var iter = rows.valueIterator();
        while (iter.next()) |arr_ptr| {
            arr_ptr.*.deinit(allocator);
            allocator.destroy(arr_ptr.*);
        }
        rows.deinit();
    }
    var cols = std.AutoHashMap(u64, *LocList).init(allocator);
    defer {
        var iter = cols.valueIterator();
        while (iter.next()) |arr_ptr| {
            arr_ptr.*.deinit(allocator);
            allocator.destroy(arr_ptr.*);
        }
        cols.deinit();
    }
    var points = std.AutoHashMap([2]u64, *Point).init(allocator);
    defer {
        points.deinit();
    }

    for (locs) |loc| {
        const row_arr = try rows.getOrPut(loc[1]);
        const col_arr = try cols.getOrPut(loc[0]);
        if (!row_arr.found_existing) {
            const arr = try allocator.create(LocList);
            arr.* = .{};
            row_arr.value_ptr.* = arr;
        }
        if (!col_arr.found_existing) {
            const arr = try allocator.create(LocList);
            arr.* = .{};
            col_arr.value_ptr.* = arr;
        }
        try row_arr.value_ptr.*.append(allocator, loc);
        try col_arr.value_ptr.*.append(allocator, loc);

        const point = try allocator.create(Point);
        point.y = loc[1];
        point.x = loc[0];
        try points.put(loc, point);
    }

    const start_ptr = points.get(locs[0]).?;
    const start = start_ptr.*;
    const same_row = rows.get(start.y).?.items;
    const next_loc = if (same_row[0][0] == start.x) same_row[1] else same_row[0];

    var prev = start_ptr;
    var point = points.get(next_loc).?;

    while (point != start_ptr) {
        try point.attachNeighbours(prev, rows, cols, points);
        prev = point;
        point = point.next;
    }
    try point.attachNeighbours(prev, rows, cols, points);
    return Hull.init(start_ptr, allocator);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const contents = try readFile("/Users/benedictclarkson/Documents/advent_of_code_2025/inputs/day_9.txt", allocator);
    defer allocator.free(contents);

    const locs = try parseLocs(contents, allocator);
    defer allocator.free(locs);

    const largest = largestRectangle(locs);

    std.debug.print("Part 1: {}\n", .{largest});

    const hull = try buildHull(locs, allocator);
    defer hull.deinit(allocator);

    const largest_inside = try largestRectangleInside(hull.points, hull);
    std.debug.print("Part 2: {}\n", .{largest_inside});
}
