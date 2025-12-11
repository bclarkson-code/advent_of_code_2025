const std = @import("std");

const NAME_SIZE = 3;
const Map = std.StringHashMap(*Node);
const Node = struct {
    name: []const u8,
    children: ?[]*Node = null,
    in_degree: usize = 0,
    _node: std.DoublyLinkedList.Node = .{},

    fn print(self: Node, allocator: std.mem.Allocator) !void {
        if (self.children == null) {
            std.debug.print("Node(.name={s}, .children={{null}}, .in_degree={})\n", .{ self.name, self.in_degree });
            return;
        }

        var child_names = try allocator.alloc(u8, self.children.?.len * (NAME_SIZE + 2));
        defer allocator.free(child_names);

        var idx: usize = 0;
        for (self.children.?) |child| {
            for (0..NAME_SIZE) |i| child_names[idx + i] = child.*.name[i];
            child_names[idx + NAME_SIZE] = ',';
            child_names[idx + NAME_SIZE + 1] = ' ';
            idx += NAME_SIZE + 2;
        }
        std.debug.print("Node(.name={s}, .children={{{s}}}, .in_degree={})\n", .{ self.name, child_names, self.in_degree });
    }
};

// visit nodes in topological order
const TopologicalCounter = struct {
    degrees: std.StringHashMap(usize),
    counts: std.StringHashMap(u64),
    queue: std.DoublyLinkedList,

    fn init(nodes: Map, allocator: std.mem.Allocator) !TopologicalCounter {
        var degrees = std.StringHashMap(usize).init(allocator);
        var counts = std.StringHashMap(u64).init(allocator);
        var queue: std.DoublyLinkedList = .{};

        var node_iter = nodes.iterator();

        while (node_iter.next()) |entry| {
            const name = entry.key_ptr.*;
            const node = entry.value_ptr.*;

            try degrees.put(name, node.in_degree);
            try counts.put(name, 0);
            if (node.in_degree == 0) queue.prepend(&node._node);
        }
        return .{ .degrees = degrees, .queue = queue, .counts = counts };
    }

    fn deinit(self: *TopologicalCounter) void {
        self.degrees.deinit();
        self.counts.deinit();
    }

    fn attachCounts(self: *TopologicalCounter) !void {
        while (true) {
            const node_ptr = self.queue.pop() orelse break;
            const node: *Node = @fieldParentPtr("_node", node_ptr);
            const node_count = self.counts.get(node.*.name).?;

            const children = node.*.children orelse continue;
            for (children) |child| {
                const child_degree = self.degrees.get(child.*.name).?;
                switch (child_degree) {
                    0 => continue, // already added
                    1 => self.queue.prepend(&child.*._node), // currently at final parent
                    else => {
                        try self.degrees.put(child.*.name, child_degree - 1);
                    },
                }
                const count = self.counts.get(child.*.name).?;
                try self.counts.put(child.*.name, count + node_count);
            }
        }
    }

    fn countBetween(self: *TopologicalCounter, start: *Node, end: *Node) !u64 {
        try self.counts.put(start.*.name, 1);
        try self.attachCounts();
        return self.counts.get(end.*.name).?;
    }
};

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(path, allocator, std.Io.Limit.unlimited);
}

fn parseFile(contents: []u8, allocator: std.mem.Allocator) !Map {
    var lines = std.mem.splitScalar(u8, contents, '\n');
    var nodes = Map.init(allocator);

    // make all the nodes
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        const colon_idx = std.mem.indexOfScalar(u8, line, ':').?;
        const name = line[0..colon_idx];
        const node = try allocator.create(Node);

        node.* = .{ .name = name };
        try nodes.put(name, node);
    }

    // attach children
    lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        const colon_idx = std.mem.indexOfScalar(u8, line, ':').?;

        const node_name = line[0..colon_idx];
        const node_ptr = nodes.get(node_name).?;

        var names = std.mem.splitScalar(u8, line[colon_idx + 2 ..], ' ');
        var children = std.ArrayList(*Node){};
        while (names.next()) |name| {
            if (nodes.get(name)) |child_ptr| {
                child_ptr.*.in_degree += 1;
                try children.append(allocator, child_ptr);
            } else {
                const child_ptr = try allocator.create(Node);

                child_ptr.* = .{ .name = name, .in_degree = 1 };
                try nodes.put(name, child_ptr);
                try children.append(allocator, child_ptr);
            }
        }

        node_ptr.*.children = try children.toOwnedSlice(allocator);
    }

    return nodes;
}

fn countBetween(nodes: Map, start: []const u8, end: []const u8, allocator: std.mem.Allocator) !u64 {
    var iter = try TopologicalCounter.init(nodes, allocator);
    defer iter.deinit();

    const start_ptr = nodes.get(start).?;
    const end_ptr = nodes.get(end).?;
    const count = try iter.countBetween(start_ptr, end_ptr);

    return count;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const contents = try readFile("/Users/benedictclarkson/Documents/advent_of_code_2025/inputs/day_11.txt", allocator);
    defer allocator.free(contents);

    const nodes = try parseFile(contents, arena_allocator);

    const part_1 = try countBetween(nodes, "you", "out", allocator);
    std.debug.print("Count: {}\n", .{part_1});

    const part_2 = (
        // svr -> fft
        try countBetween(nodes, "svr", "fft", allocator)
        // fft -> dac
        * try countBetween(nodes, "fft", "dac", allocator)
            // dac -> out
        * try countBetween(nodes, "dac", "out", allocator));
    std.debug.print("Count: {}\n", .{part_2});
}
