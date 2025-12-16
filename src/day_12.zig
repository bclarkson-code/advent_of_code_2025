const std = @import("std");

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(path, allocator, std.Io.Limit.unlimited);
}

const Budget = struct {
    height: usize,
    width: usize,
    values: []usize,

    fn size(self: Budget) usize {
        return self.height * self.width;
    }

    fn requires(self: Budget, sizes: []usize) usize {
        var total: usize = 0;
        for (0..self.values.len) |i| {
            total += sizes[i] * self.values[i];
        }
        return total;
    }
};

fn parseFile(contents: []u8, allocator: std.mem.Allocator) !struct { sizes: []usize, budgets: []*Budget } {
    var sizes = std.ArrayList(usize){};
    defer sizes.deinit(allocator);

    var blocks = std.mem.splitSequence(u8, contents, "\n\n");
    var final_block: []const u8 = undefined;

    while (blocks.next()) |block| {
        if (std.mem.containsAtLeastScalar(u8, block, 1, 'x')) {
            final_block = block;
            break;
        }
        var size: usize = 0;
        for (block) |c| size += if (c == '#') 1 else 0;
        try sizes.append(allocator, size);
    }

    var budgets = std.ArrayList(*Budget){};
    defer budgets.deinit(allocator);

    var lines = std.mem.splitScalar(u8, final_block, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const x_idx = std.mem.indexOf(u8, line, "x").?;
        const colon_idx = std.mem.indexOf(u8, line, ":").?;

        const width = try std.fmt.parseInt(usize, line[0..x_idx], 10);
        const height = try std.fmt.parseInt(usize, line[x_idx + 1 .. colon_idx], 10);

        var budget_tokens = std.mem.splitScalar(u8, line[colon_idx + 1 ..], ' ');

        var budget_list = std.ArrayList(u64){};
        defer budget_list.deinit(allocator);

        while (budget_tokens.next()) |token| {
            if (token.len == 0) continue;
            const val = try std.fmt.parseInt(u64, token, 10);
            try budget_list.append(allocator, val);
        }

        const budget_values = try budget_list.toOwnedSlice(allocator);
        const budget = try allocator.create(Budget);
        budget.* = .{ .height = height, .width = width, .values = budget_values };
        try budgets.append(allocator, budget);
    }

    return .{
        .sizes = try sizes.toOwnedSlice(allocator),
        .budgets = try budgets.toOwnedSlice(allocator),
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const contents = try readFile("inputs/day_12.txt", arena_allocator);
    const inputs = try parseFile(contents, arena_allocator);

    var total: usize = 0;
    for (inputs.budgets) |budget| {
        if (budget.size() > budget.requires(inputs.sizes)) {
            total += 1;
        }
    }
    std.debug.print("Total: {}\n", .{total});
}
