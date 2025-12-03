const std = @import("std");

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(path, allocator, std.Io.Limit.unlimited);
}

fn findLargestNum(line: []const u8, n_digits: usize, allocator: std.mem.Allocator) !u64 {
    var buf = try allocator.alloc(u8, n_digits);
    defer allocator.free(buf);

    for (0..n_digits) |i| {
        buf[i] = 0;
    }

    for (0..line.len) |i| {
        const c = line[i];

        for (0..n_digits - 1) |d| {
            if (buf[d] < buf[d + 1]) {
                buf[d] = buf[d + 1];
                buf[d + 1] = 0;
            }
        }

        if (buf[n_digits - 1] < c) buf[n_digits - 1] = c;
    }
    return try std.fmt.parseInt(u64, buf, 10);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const contents = try readFile("/Users/benedictclarkson/Documents/advent_of_code_2025/inputs/day_3.txt", allocator);
    defer allocator.free(contents);

    var lines = std.mem.splitScalar(u8, contents, '\n');
    var total: u64 = 0;

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const num = try findLargestNum(line, 2, allocator);
        total += num;
    }
    std.debug.print("part 1: {}\n", .{total});

    total = 0;
    lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const num = try findLargestNum(line, 12, allocator);
        total += num;
    }
    std.debug.print("part 2: {}\n", .{total});
}
