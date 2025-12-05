const std = @import("std");

const Interval = struct {
    low: u64,
    high: u64,

    fn contains(self: Interval, val: u64) bool {
        return self.low <= val and val <= self.high;
    }

    fn overlaps(self: *Interval, other: *Interval) bool {
        return @max(self.low, other.low) <= @min(self.high, other.high);
    }

    fn merge(self: *Interval, other: *Interval, allocator: std.mem.Allocator) !?*Interval {
        if (!self.overlaps(other)) return null;

        const out = try allocator.create(Interval);
        out.* = .{
            .low = @min(self.low, other.low),
            .high = @max(self.high, other.high),
        };

        return out;
    }

    fn width(self: Interval) u64 {
        return self.high - self.low + 1;
    }
};
const List = std.ArrayList(*Interval);

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(path, allocator, std.Io.Limit.unlimited);
}

fn parseFile(contents: []const u8, allocator: std.mem.Allocator) !struct { intervals: []*Interval, nums: []u64 } {
    var sections = std.mem.splitSequence(u8, contents, "\n\n");
    const header = sections.next().?;

    var lines = std.mem.splitScalar(u8, header, '\n');
    var intervals = List{};

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var parts = std.mem.splitScalar(u8, line, '-');

        const interval: *Interval = try allocator.create(Interval);

        const low: u64 = try std.fmt.parseInt(u64, parts.next().?, 10);
        const high: u64 = try std.fmt.parseInt(u64, parts.next().?, 10);

        interval.* = .{ .low = low, .high = high };
        try intervals.append(allocator, interval);
    }

    const body = sections.next().?;
    var num_tokens = std.mem.splitScalar(u8, body, '\n');
    var nums = std.ArrayList(u64){};

    while (num_tokens.next()) |token| {
        if (token.len == 0) continue;
        const num: u64 = try std.fmt.parseInt(u64, token, 10);
        try nums.append(allocator, num);
    }

    return .{ .intervals = intervals.items, .nums = nums.items };
}

fn isFresh(val: u64, intervals: []const *Interval) bool {
    for (intervals) |interval| {
        if (interval.contains(val)) return true;
    }
    return false;
}

fn inOrder(_: void, interval_1: *Interval, interval_2: *Interval) bool {
    return interval_1.low < interval_2.low;
}

fn mergeIntervals(intervals: []*Interval, allocator: std.mem.Allocator) ![]*Interval {
    std.mem.sort(*Interval, intervals, {}, inOrder);
    var out = std.ArrayList(*Interval){};

    var current = intervals[0];
    for (intervals) |interval| {
        if (try current.merge(interval, allocator)) |merged| {
            current = merged;
        } else {
            try out.append(allocator, current);
            current = interval;
        }
    }
    try out.append(allocator, current);

    return out.items;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const contents = try readFile("/Users/benedictclarkson/Documents/advent_of_code_2025/inputs/day_5.txt", allocator);
    defer allocator.free(contents);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const out = try parseFile(contents, arena_allocator);
    const intervals = out.intervals;
    const nums = out.nums;

    var n_fresh: usize = 0;
    for (nums) |item| {
        if (isFresh(item, intervals)) n_fresh += 1;
    }
    std.debug.print("Part 1: {}\n", .{n_fresh});

    const merged = try mergeIntervals(intervals, arena_allocator);
    var width: u64 = 0;
    for (merged) |interval| {
        width += interval.width();
    }
    std.debug.print("Part 2: {}\n", .{width});
}
