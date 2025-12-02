const std = @import("std");

const MAX_LENGTH = 32;
const Rotation = enum { left, right };

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(path, allocator, std.Io.Limit.unlimited);
}

fn isRepeat(num: u64) !bool {
    var buf: [MAX_LENGTH]u8 = undefined;
    const string = try std.fmt.bufPrint(&buf, "{}", .{num});

    if (string.len % 2 == 1) return false;

    const mid = string.len / 2;
    const left = string[0..mid];
    const right = string[mid..string.len];

    var all_match: bool = true;
    for (left, right) |l, r| {
        if (l != r) {
            all_match = false;
            break;
        }
    }
    return all_match;
}

fn isMultiRepeat(num: u64) !bool {
    var buf: [MAX_LENGTH]u8 = undefined;
    const string = try std.fmt.bufPrint(&buf, "{}", .{num});

    tryChunk: for (1..string.len) |chunk_len| {
        if (string.len % chunk_len != 0) continue;
        const n_chunks: usize = string.len / chunk_len;

        for (1..n_chunks) |chunk_idx| {
            for (0..chunk_len) |char_idx| {
                const left: usize = char_idx;
                const right: usize = (chunk_idx * chunk_len) + char_idx;

                if (string[left] != string[right]) continue :tryChunk;
            }
        }
        return true;
    }
    return false;
}

fn countRepeats(start: u64, end: u64, is_repeat: *const fn (u64) anyerror!bool) !u64 {
    var total: u64 = 0;

    for (start..end + 1) |num| {
        if (try is_repeat(num)) {
            total += num;
        }
    }
    return total;
}

fn toRange(string: []const u8) !struct { start: u64, end: u64 } {
    const trimmed = std.mem.trimRight(u8, string, "\n");
    var parts = std.mem.splitScalar(u8, trimmed, '-');
    const start = try std.fmt.parseInt(u64, parts.next().?, 10);
    const end = try std.fmt.parseInt(u64, parts.next().?, 10);

    return .{ .start = start, .end = end };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const contents = try readFile("/Users/benedictclarkson/Documents/advent_of_code_2025/inputs/day_2.txt", allocator);
    defer allocator.free(contents);

    var ranges = std.mem.splitScalar(u8, contents, ',');

    var total: u64 = 0;
    while (ranges.next()) |range_string| {
        const range = try toRange(range_string);
        total += try countRepeats(range.start, range.end, isRepeat);
    }
    std.debug.print("part 1: {}\n", .{total});

    ranges = std.mem.splitScalar(u8, contents, ',');
    total = 0;
    while (ranges.next()) |range_string| {
        const range = try toRange(range_string);
        total += try countRepeats(range.start, range.end, isMultiRepeat);
    }
    std.debug.print("part 2: {}\n", .{total});
}
