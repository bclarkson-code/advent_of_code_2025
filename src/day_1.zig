const std = @import("std");

const Rotation = enum { left, right };

const LinesIter = struct {
    contents: []u8,
    idx: usize = 0,

    fn next(self: *LinesIter) ?[]u8 {
        if (self.idx >= self.contents.len) return null;

        const idx = self.idx;
        for (self.idx..self.contents.len) |i| {
            if (self.contents[i] == '\n') {
                self.idx = i + 1;
                return self.contents[idx .. self.idx - 1];
            }
        }
        self.idx = self.contents.len;
        return self.contents[idx..self.idx];
    }
};

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buf = try allocator.alloc(u8, file_size);
    errdefer allocator.free(buf);

    const bytes_read: usize = try file.readAll(buf);

    return buf[0..bytes_read];
}

fn parseLine(line: []const u8) !struct { rotation: Rotation, val: i64 } {
    const rotation = switch (line[0]) {
        'L' => Rotation.left,
        'R' => Rotation.right,
        else => return error.InvalidCharacter,
    };

    const val = try std.fmt.parseInt(i64, line[1..], 10);
    return .{ .rotation = rotation, .val = val };
}

fn applyRotation(rotation: Rotation, val: i64, current: i64, count_intermediate: bool) struct { val: i64, n_zeros: u64 } {
    const coef: i64 = switch (rotation) {
        .left => -1,
        .right => 1,
    };

    var after: i64 = current;
    var n_zeros: u64 = 0;
    var to_add: i64 = val;

    while (to_add != 0) {
        const delta = @min(to_add, 100);
        to_add -= delta;

        // full rotation -> no change to val, but crosses 0
        if (delta == 100) {
            n_zeros += 1;
            continue;
        }
        // null rotation
        if (delta == 0) {
            continue;
        }

        // partial rotation (0 < delta < 100)
        const before = after;
        after += coef * delta;

        // partial starting at 0 -> cant end at 0
        if (before == 0 and delta < 100) {
            after = @mod(after, 100);
            continue;
        }

        // crossed 0 anticlockwise
        if (after < 0) {
            n_zeros += 1;
            after = @mod(after, 100);
            continue;
        }

        // landed exactly at 0
        if (after == 0) {
            n_zeros += 1;
            continue;
        }

        // started and ended in range -> no 0 crossing
        if (0 < after and after <= 99) {
            continue;
        }

        // crossed 0 clockwise
        if (99 < after) {
            n_zeros += 1;
            after = @mod(after, 100);
        }
    }

    if (!count_intermediate) {
        n_zeros = if (after == 0) 1 else 0;
    }
    return .{ .val = after, .n_zeros = n_zeros };
}

fn countZeros(contents: []const u8, count_intermediate: bool) !u64 {
    var lines = std.mem.splitScalar(u8, contents, '\n');
    var current: i64 = 50;
    var n_zeros: u64 = 0;
    while (lines.next()) |line| {
        if (line.len == 0) break;

        const out = try parseLine(line);
        const result = applyRotation(out.rotation, out.val, current, count_intermediate);

        current = result.val;
        n_zeros += result.n_zeros;
    }
    return n_zeros;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const contents = try readFile("/Users/benedictclarkson/Documents/advent_of_code_2025/inputs/day_1.txt", allocator);
    defer allocator.free(contents);

    // part 1
    var n_zeros = try countZeros(contents, false);
    std.debug.print("Part 1: {}\n", .{n_zeros});

    // part 2
    n_zeros = try countZeros(contents, true);
    std.debug.print("Part 2: {}\n", .{n_zeros});
}
