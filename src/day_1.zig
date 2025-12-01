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

fn parseLine(line: []u8) !struct { Rotation, i64 } {
    const rotation = switch (line[0]) {
        'L' => Rotation.left,
        'R' => Rotation.right,
        else => return error.InvalidCharacter,
    };

    const val = try std.fmt.parseInt(i64, line[1..], 10);
    return .{ rotation, val };
}

fn applyRotation(rotation: Rotation, val: i64, current: i64, count_intermediate: bool) struct { i64, i64 } {
    const coef: i64 = switch (rotation) {
        .left => -1,
        .right => 1,
    };

    var next: i64 = current;
    var n_zeros: i64 = 0;
    var to_add: i64 = val;

    while (to_add != 0) {
        const delta = @min(to_add, 100);
        to_add -= delta;

        // at zero
        if (next == 0 and delta == 100) {
            n_zeros += 1;
            continue;
        }
        // partial rotation -> cant end at 0
        if (next == 0 and delta < 100) {
            next += coef * delta;
            next = @mod(next, 100);
            continue;
        }

        // full rotation -> no change to val, but crosses 0
        if (delta == 100) {
            n_zeros += 1;
            continue;
        }
        if (delta == 0) {
            continue;
        }

        // partial rotation
        next += coef * delta;
        if (next < 0) {
            n_zeros += 1;
            next = @mod(next, 100);
            continue;
        }

        if (next == 0) {
            n_zeros += 1;
            continue;
        }
        if (0 < next and next <= 99) {
            continue;
        }
        if (99 < next) {
            n_zeros += 1;
            next = @mod(next, 100);
        }
    }

    if (!count_intermediate) {
        n_zeros = if (next == 0) 1 else 0;
    }
    return .{ next, n_zeros };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const contents = try readFile("/Users/benedictclarkson/Documents/advent_of_code_2025/inputs/day_1.txt", allocator);
    defer allocator.free(contents);

    // part 1
    var lines = LinesIter{ .contents = contents };
    var current: i64 = 50;
    var n_zeros: i64 = 0;
    while (lines.next()) |line| {
        const out = try parseLine(line);
        const rotation = out[0];
        const val = out[1];

        const result = applyRotation(rotation, val, current, false);
        current = result[0];
        n_zeros += result[1];
    }
    std.debug.print("Part 1: {}\n", .{n_zeros});

    // part 1
    lines = LinesIter{ .contents = contents };
    current = 50;
    n_zeros = 0;
    while (lines.next()) |line| {
        const out = try parseLine(line);
        const rotation = out[0];
        const val = out[1];

        const result = applyRotation(rotation, val, current, true);
        current = result[0];
        n_zeros += result[1];
    }
    std.debug.print("Part 2: {}\n", .{n_zeros});
}
