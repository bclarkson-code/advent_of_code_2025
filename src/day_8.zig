const std = @import("std");

const UnionFind = struct {
    parent: []usize,
    rank: []usize,

    fn init(len: usize, allocator: std.mem.Allocator) !UnionFind {
        var parent = try allocator.alloc(usize, len);
        errdefer allocator.free(parent);

        var rank = try allocator.alloc(usize, len);
        errdefer allocator.free(rank);

        rank[0] = 0;
        @memset(rank, 0);

        for (0..len) |i| {
            parent[i] = i;
        }

        return UnionFind{ .parent = parent, .rank = rank };
    }

    fn deinit(self: UnionFind, allocator: std.mem.Allocator) void {
        allocator.free(self.parent);
        allocator.free(self.rank);
    }

    fn outOfBounds(self: UnionFind, x: usize) bool {
        return self.rank.len <= x;
    }

    fn find(self: *UnionFind, x: usize) !usize {
        if (self.outOfBounds(x)) return error.outOfBounds;

        if (self.parent[x] != x) {
            self.parent[x] = try self.find(self.parent[x]);
        }

        return self.parent[x];
    }

    fn merge(self: *UnionFind, x: usize, y: usize) !bool {
        var parent_x = try self.find(x);
        var parent_y = try self.find(y);

        if (parent_x == parent_y) return false;

        if (self.rank[parent_x] < self.rank[parent_y]) {
            const temp: usize = parent_x;
            parent_x = parent_y;
            parent_y = temp;
        }

        self.parent[parent_y] = parent_x;
        if (self.rank[parent_x] == self.rank[parent_y]) self.rank[parent_x] += 1;

        return true;
    }
};

const Connection = struct {
    loc_1: usize,
    loc_2: usize,
    dist: f64,
};

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(path, allocator, std.Io.Limit.unlimited);
}

fn parseFile(contents: []u8, allocator: std.mem.Allocator) ![][]u64 {
    var out = std.ArrayList([]u64){};
    var lines = std.mem.splitScalar(u8, contents, '\n');

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var tokens = std.mem.splitScalar(u8, line, ',');
        const nums = try allocator.alloc(u64, 3);

        nums[0] = try std.fmt.parseInt(u64, tokens.next().?, 10);
        nums[1] = try std.fmt.parseInt(u64, tokens.next().?, 10);
        nums[2] = try std.fmt.parseInt(u64, tokens.next().?, 10);

        try out.append(allocator, nums);
    }
    return out.toOwnedSlice(allocator);
}

fn distBetween(a: []usize, b: []usize) !f64 {
    if (a.len != b.len) return error.InvalidLength;

    var total: f64 = 0.0;
    for (0..a.len) |i| {
        const diff: u64 = if (a[i] < b[i]) b[i] - a[i] else a[i] - b[i];
        const diff_f: f64 = @floatFromInt(diff);
        total += diff_f * diff_f;
    }
    return std.math.sqrt(total);
}

fn connectionIsAscending(_: @TypeOf(.{}), con_1: Connection, con_2: Connection) bool {
    return con_1.dist < con_2.dist;
}

fn calcDistances(locs: [][]usize, allocator: std.mem.Allocator) ![]Connection {
    var distances = try allocator.alloc(Connection, (((locs.len - 1) * locs.len) / 2));
    var i: usize = 0;

    for (0..locs.len - 1) |x| {
        for (x + 1..locs.len) |y| {
            distances[i] = .{
                .loc_1 = x,
                .loc_2 = y,
                .dist = try distBetween(locs[x], locs[y]),
            };
            i += 1;
        }
    }
    std.sort.pdq(Connection, distances, .{}, connectionIsAscending);
    return distances;
}

fn makeConnections(locs: [][]usize, distances: []Connection, n: u64, allocator: std.mem.Allocator) !u64 {
    var uf = try UnionFind.init(locs.len, allocator);
    defer uf.deinit(allocator);

    for (0..n) |i| {
        const con = distances[i];
        _ = try uf.merge(con.loc_1, con.loc_2);
    }

    var counts = try allocator.alloc(u64, locs.len);
    defer allocator.free(counts);

    for (0..counts.len) |c| counts[c] = 0;

    for (0..counts.len) |c| {
        const parent = try uf.find(c);
        counts[parent] += 1;
    }

    std.mem.sort(u64, counts, {}, comptime std.sort.desc(u64));

    return counts[0] * counts[1] * counts[2];
}

fn joinAllLocs(locs: [][]usize, distances: []Connection, allocator: std.mem.Allocator) !u64 {
    var uf = try UnionFind.init(locs.len, allocator);
    defer uf.deinit(allocator);

    var counts = try allocator.alloc(u64, locs.len);
    defer allocator.free(counts);
    for (0..counts.len) |c| counts[c] = 0;

    var all_joined: bool = false;
    var i: usize = 0;
    while (!all_joined) : (i += 1) {
        const con = distances[i];
        _ = try uf.merge(con.loc_1, con.loc_2);

        for (0..counts.len) |c| counts[c] = 0;
        for (0..counts.len) |c| {
            const parent = try uf.find(c);
            counts[parent] += 1;
        }
        const max_count = std.mem.max(u64, counts);

        if (max_count == counts.len) all_joined = true;
    }

    const last_con = distances[i - 1];
    const con_1: []usize = locs[last_con.loc_1];
    const con_2: []usize = locs[last_con.loc_2];

    return con_1[0] * con_2[0];
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const contents = try readFile("/Users/benedictclarkson/Documents/advent_of_code_2025/inputs/day_8.txt", allocator);
    defer allocator.free(contents);

    const locs = try parseFile(contents, allocator);
    defer {
        for (0..locs.len) |i| {
            allocator.free(locs[i]);
        }
        allocator.free(locs);
    }

    const distances = try calcDistances(locs, allocator);
    defer {
        allocator.free(distances);
    }

    var total = try makeConnections(locs, distances, 1000, allocator);
    std.debug.print("Part 1: {}\n", .{total});

    total = try joinAllLocs(locs, distances, allocator);
    std.debug.print("Part 2: {}\n", .{total});
}
