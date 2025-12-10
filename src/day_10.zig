const std = @import("std");

// in case you forgot what numbers are
const ONE: u16 = 1;

const RangeProduct = struct {
    ranges: []const [2]usize,
    indices: []usize,
    done: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, ranges: []const [2]usize) !@This() {
        const indices = try allocator.alloc(usize, ranges.len);
        for (indices, ranges) |*idx, range| {
            idx.* = range[0];
        }
        return .{ .ranges = ranges, .indices = indices, .done = false, .allocator = allocator };
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.indices);
    }

    pub fn next(self: *@This()) ?[]const usize {
        if (self.done) return null;

        const result = self.indices;

        var i = self.ranges.len;
        while (i > 0) {
            i -= 1;
            self.indices[i] += 1;
            if (self.indices[i] <= self.ranges[i][1]) return result;
            self.indices[i] = self.ranges[i][0];
        }
        self.done = true;
        return result;
    }
};
const Machine = struct {
    len: usize,
    goal: u16,
    buttons: []u16,
    costs: []u64,

    fn printState(self: Machine, state: u16) void {
        std.debug.print("[", .{});
        for (0..self.len) |i| {
            // 1 if bit i is 1
            var indicator = state >> @as(u4, @intCast(i));
            indicator = indicator & 1;

            if (indicator == 1) {
                std.debug.print("#", .{});
            } else {
                std.debug.print(".", .{});
            }
        }
        std.debug.print("]\n", .{});
    }

    fn deinit(self: *Machine, allocator: std.mem.Allocator) void {
        allocator.free(self.buttons);
        allocator.free(self.costs);
        allocator.destroy(self);
    }

    fn countOnes(self: Machine, value: u16) u64 {
        _ = self;
        var count: u64 = 0;

        for (0..16) |i| {
            var indicator = value >> @as(u4, @intCast(i));
            indicator = indicator & 1;
            if (indicator == 1) count += 1;
        }
        return count;
    }

    fn apply(self: *Machine, button: u16) void {
        self.state = self.state ^ button;
    }

    fn tryCombo(self: Machine, combo: u16) u16 {
        var state: u16 = 0;
        for (0..self.buttons.len) |i| {
            var indicator = combo >> @as(u4, @intCast(i));
            indicator = indicator & 1;
            if (indicator == 1) {
                state = state ^ self.buttons[i];
            }
        }
        return state;
    }

    fn findCombo(self: Machine) ?u16 {
        const max_combo: u16 = ONE << @as(u4, @intCast(self.buttons.len));

        var best_combo: ?u16 = null;
        var best_ones: u64 = std.math.maxInt(u64);

        for (0..max_combo) |combo| {
            const combo_int = @as(u16, @intCast(combo));
            const state = self.tryCombo(combo_int);

            if (state == self.goal) {
                if (self.countOnes(combo_int) >= best_ones) continue;

                best_combo = combo_int;
                best_ones = self.countOnes(combo_int);
            }
        }
        return best_combo;
    }

    fn toMatrix(self: Machine, allocator: std.mem.Allocator) !*Matrix {
        var values = try allocator.alloc(i64, self.len * self.buttons.len);
        defer allocator.free(values);

        for (0..self.buttons.len, self.buttons) |y, button| {
            for (0..self.len) |x| {
                var indicator = button >> @as(u4, @intCast(x));
                indicator = indicator & 1;
                values[x * self.buttons.len + y] = indicator;
            }
        }
        return Matrix.fromArray(values, self.buttons.len, self.len, allocator);
    }
    fn toVector(self: Machine, allocator: std.mem.Allocator) !*Vector {
        var values = try allocator.alloc(i64, self.len);
        defer allocator.free(values);

        for (0..self.len, self.costs) |i, cost| {
            values[i] = @as(i64, @intCast(cost));
        }

        return Vector.fromArray(values, allocator);
    }
};

const Matrix = struct {
    _values: []i64,
    m: [][]i64,
    width: usize,
    height: usize,

    fn fromArray(values: []i64, width: usize, height: usize, allocator: std.mem.Allocator) !*Matrix {
        if (values.len != width * height) return error.InvalidSize;

        const _values = try allocator.alloc(i64, values.len);
        @memcpy(_values, values);

        const m = try allocator.alloc([]i64, height);

        for (0..height) |y| {
            const idx = y * width;
            m[y] = _values[idx .. idx + width];
        }
        const mat = try allocator.create(Matrix);

        mat.* = .{
            ._values = _values,
            .m = m,
            .width = width,
            .height = height,
        };
        return mat;
    }

    fn setRow(self: *Matrix, row: []const i64, idx: usize) !void {
        if (idx >= self.height) return error.IndexError;
        if (row.len != self.width) return error.IndexError;

        for (0..self.width, row) |i, r| {
            self.m[idx][i] = r;
        }
    }

    fn getRow(self: Matrix, idx: usize) ![]const i64 {
        if (idx >= self.height) return error.IndexError;

        return self.m[idx];
    }

    fn getColVec(self: Matrix, idx: usize, allocator: std.mem.Allocator) !*Vector {
        if (idx >= self.width) return error.IndexError;

        const col = try allocator.alloc(i64, self.height);
        defer allocator.free(col);

        for (0..self.height) |i| {
            col[i] = self.m[i][idx];
        }

        return try Vector.fromArray(col, allocator);
    }

    // add a multiple of row a to a multipe of row b and store in row a
    fn rowOp(self: *Matrix, a_idx: usize, a_coef: i64, b_idx: usize, b_coef: i64) !void {
        if (a_idx >= self.height) return error.IndexError;
        if (b_idx >= self.height) return error.IndexError;

        std.debug.print("r{} -> {} * r{} + {} * r{}\n", .{ a_idx + 1, a_coef, a_idx + 1, b_coef, b_idx + 1 });

        const a: []const i64 = try self.getRow(a_idx);
        const b: []const i64 = try self.getRow(b_idx);

        for (0..self.width, a, b) |i, a_val, b_val| {
            self.m[a_idx][i] = a_coef * a_val + b_coef * b_val;
        }
    }

    fn deinit(self: *Matrix, allocator: std.mem.Allocator) void {
        allocator.free(self.m);
        allocator.free(self._values);
        allocator.destroy(self);
    }

    fn print(self: Matrix) void {
        std.debug.print("[\n", .{});
        for (self.m) |row| {
            std.debug.print("  {any}\n", .{row});
        }
        std.debug.print("]\n", .{});
    }
    fn write(self: Matrix, writer: *std.Io.Writer) !void {
        try writer.writeAll("[\n");
        for (self.m) |row| {
            try writer.writeAll("  [");
            for (row, 0..) |val, i| {
                try writer.print("{d}", .{val});
                if (i < row.len - 1) {
                    try writer.writeAll(", ");
                }
            }
            try writer.writeAll("]\n");
        }
        try writer.writeAll("]\n");
    }
};

const Vector = struct {
    v: []i64,
    len: usize,

    fn fromArray(values: []i64, allocator: std.mem.Allocator) !*Vector {
        const _values = try allocator.alloc(i64, values.len);
        @memcpy(_values, values);

        const out = try allocator.create(Vector);
        out.* = .{ .v = _values, .len = _values.len };

        return out;
    }

    fn deinit(self: *Vector, allocator: std.mem.Allocator) void {
        allocator.free(self.v);
        allocator.destroy(self);
    }

    fn rowOp(self: *Vector, a_idx: usize, a_coef: i64, b_idx: usize, b_coef: i64) !void {
        if (a_idx >= self.v.len) return error.IndexError;
        if (b_idx >= self.v.len) return error.IndexError;

        const a = self.v[a_idx];
        const b = self.v[b_idx];

        self.v[a_idx] = a_coef * a + b_coef * b;
    }

    fn mul(self: *Vector, val: i64) void {
        for (0..self.len) |i| {
            self.v[i] = self.v[i] * val;
        }
    }

    fn addVec(self: *Vector, other: *Vector) void {
        for (0..self.len) |i| {
            self.v[i] = self.v[i] + other.v[i];
        }
    }

    fn print(self: Vector) void {
        std.debug.print("[{any}]\n", .{self.v});
    }
};

fn reduceRow(mat: *Matrix, vec: *Vector, row: usize) void {
    var g: i64 = vec.v[row];
    for (mat.m[row]) |val| {
        g = gcd(g, val);
    }
    if (g > 1) {
        for (0..mat.width) |col| {
            mat.m[row][col] = @divExact(mat.m[row][col], g);
        }
        vec.v[row] = @divExact(vec.v[row], g);
    }
}

fn gcd(a: i64, b: i64) i64 {
    var x = if (a < 0) -a else a;
    var y = if (b < 0) -b else b;
    while (y != 0) {
        const t = y;
        y = @mod(x, y);
        x = t;
    }
    return x;
}
// elimintate the values in the given col, below the current value
fn eliminateBelow(mat: *Matrix, vec: *Vector, row_idx: usize, col_idx: usize) !?void {
    if (row_idx >= vec.len) return error.IndexError;
    if (row_idx >= mat.height) return error.IndexError;
    if (vec.len != mat.height) return error.IndexError;

    var b_val = mat.m[row_idx][col_idx];
    var found_nonzero: bool = false;

    // make sure we have a positive value at row_idx, col_idx
    if (b_val == 0) {
        for (row_idx + 1..mat.height) |row| {
            const a_val = mat.m[row][col_idx];
            if (a_val == 0) continue;

            found_nonzero = true;

            try mat.rowOp(row_idx, 1, row, a_val);
            try vec.rowOp(row_idx, 1, row, a_val);
            reduceRow(mat, vec, row_idx);
            break;
        }
        if (!found_nonzero) return null;
    } else if (b_val < 0) {
        try mat.rowOp(row_idx, -1, row_idx, 0);
        try vec.rowOp(row_idx, -1, row_idx, 0);
        reduceRow(mat, vec, row_idx);
    }
    b_val = mat.m[row_idx][col_idx];

    // eliminate everything below
    found_nonzero = false;
    for (row_idx + 1..mat.height) |row| {
        const a_val = mat.m[row][col_idx];
        if (a_val == 0) continue;
        found_nonzero = true;

        try mat.rowOp(row, b_val, row_idx, a_val * -1);
        try vec.rowOp(row, b_val, row_idx, a_val * -1);
        reduceRow(mat, vec, row);
    }
}

fn eliminateAbove(mat: *Matrix, vec: *Vector, row_idx: usize, col_idx: usize) !?void {
    if (row_idx >= vec.len) return error.IndexError;
    if (row_idx >= mat.height) return error.IndexError;
    if (vec.len != mat.height) return error.IndexError;

    const b_val = mat.m[row_idx][col_idx];
    var found_nonzero: bool = false;

    if (b_val == 0) unreachable;

    // eliminate everything above
    for (0..row_idx) |row| {
        const a_val = mat.m[row][col_idx];
        if (a_val == 0) continue;
        found_nonzero = true;

        try mat.rowOp(row, b_val, row_idx, a_val * -1);
        try vec.rowOp(row, b_val, row_idx, a_val * -1);
    }
}

fn eliminate(mat: *Matrix, vec: *Vector) !void {
    var row_idx: usize = 0;
    var col_idx: usize = 0;

    mat.print();
    vec.print();
    std.debug.print("--------------------\n", .{});

    // get to upper triangluar form
    while (col_idx < mat.width) : (col_idx += 1) {
        std.debug.print("{}, {}\n", .{ row_idx, col_idx });
        if ((try eliminateBelow(mat, vec, row_idx, col_idx)) != null) {
            mat.print();
            vec.print();
            row_idx += 1;
            if (row_idx >= mat.height) break;
        } else {
            std.debug.print("Skipping col {}\n", .{col_idx});
        }
        std.debug.print("--------------------\n", .{});
    }

    std.debug.print("Reduced to upper triangular\n", .{});

    // get to fully reduced
    row_idx = 0;
    col_idx = 0;
    while (col_idx < mat.width) : (col_idx += 1) {
        if (mat.m[row_idx][col_idx] == 0) {
            std.debug.print("Skipping col {}\n", .{col_idx});
            continue;
        }

        if ((try eliminateAbove(mat, vec, row_idx, col_idx)) != null) {
            mat.print();
            vec.print();
            row_idx += 1;
            if (row_idx >= mat.height) break;
        } else {
            std.debug.print("Skipping col {}\n", .{col_idx});
        }
        std.debug.print("--------------------\n", .{});
    }
    std.debug.print("Fully reduced\n", .{});
}

// extract vectors that span the solution space
fn extractBasisVectors(mat: *Matrix, vec: *Vector, allocator: std.mem.Allocator) !*Matrix {
    var free_indices: []usize = try allocator.alloc(usize, mat.width);
    defer allocator.free(free_indices);
    var free_idx: usize = 0;

    var pivot_cols: []bool = try allocator.alloc(bool, mat.width);
    defer allocator.free(pivot_cols);
    for (pivot_cols) |*p| p.* = false;

    var pivot_col_to_row: []?usize = try allocator.alloc(?usize, mat.width);
    defer allocator.free(pivot_col_to_row);
    for (pivot_col_to_row) |*p| p.* = null;

    for (0..mat.height) |row| {
        for (0..mat.width) |col| {
            if (mat.m[row][col] != 0) {
                pivot_cols[col] = true;
                pivot_col_to_row[col] = row;
                break;
            }
        }
    }

    // Free columns are those without pivots
    for (0..mat.width) |col| {
        if (!pivot_cols[col]) {
            free_indices[free_idx] = col;
            free_idx += 1;
        }
    }

    std.debug.print("Free indices: {any}\n", .{free_indices[0..free_idx]});

    // extract out the basis vectors and root vector into a matrix
    // free_idx basis vectors + 1 root vector
    const width: usize = free_idx + 1;
    var values = try allocator.alloc(i64, mat.width * (width));
    defer allocator.free(values);

    for (0..mat.width) |col| {
        const out_idx = col * width;

        if (!pivot_cols[col]) {
            values[out_idx] = 0;
            for (0..free_idx) |f| {
                if (free_indices[f] == col) {
                    values[out_idx + f + 1] = 1;
                } else {
                    values[out_idx + f + 1] = 0;
                }
            }
        } else {
            const row = pivot_col_to_row[col].?;
            values[out_idx] = vec.v[row];

            // basis vectors: -mat[row][free_col] for each free column
            for (0..free_idx) |f| {
                const free_col = free_indices[f];
                values[out_idx + f + 1] = -mat.m[row][free_col];
            }
        }
    }

    const out_mat = try Matrix.fromArray(values, width, mat.width, allocator);
    std.debug.print("Basis matrix:\n", .{});
    out_mat.print();

    return out_mat;
}

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(path, allocator, std.Io.Limit.unlimited);
}

fn parseLine(line: []const u8, allocator: std.mem.Allocator) !?*Machine {
    var sections = std.mem.splitScalar(u8, line, ' ');

    var section = sections.next().?;
    if (section.len == 0) return null;

    var goal: u16 = 0;
    var i: u4 = 0;
    for (section) |c| {
        switch (c) {
            '[' => continue,
            ']' => continue,
            '.' => i += 1,
            '#' => {
                goal = goal ^ (ONE << i);
                i += 1;
            },
            else => return error.InvalidCharacter,
        }
    }
    const size = i;

    var buttons = std.ArrayList(u16){};
    defer buttons.deinit(allocator);
    section = sections.next().?;
    while (section[0] == '(') {
        var button: u16 = 0;
        for (section[1..]) |c| {
            switch (c) {
                ')' => continue,
                ',' => continue,
                '0'...'9' + 1 => {
                    i = @as(u4, @intCast(c - '0'));
                    button = button ^ (ONE << i);
                },
                else => return error.InvalidCharacter,
            }
        }
        try buttons.append(allocator, button);
        section = sections.next().?;
    }

    var costs = std.ArrayList(u64){};
    defer costs.deinit(allocator);

    var tokens = std.mem.splitScalar(u8, section[1 .. section.len - 1], ',');
    while (tokens.next()) |token| {
        const cost = try std.fmt.parseInt(u64, token, 10);
        try costs.append(allocator, cost);
    }

    const machine = try allocator.create(Machine);
    machine.* = .{
        .len = size,
        .goal = goal,
        .buttons = try buttons.toOwnedSlice(allocator),
        .costs = try costs.toOwnedSlice(allocator),
    };
    return machine;
}

fn parseFile(contents: []u8, allocator: std.mem.Allocator) ![]*Machine {
    var lines = std.mem.splitScalar(u8, contents, '\n');
    var machines = std.ArrayList(*Machine){};
    defer machines.deinit(allocator);

    while (lines.next()) |line| {
        const machine = try parseLine(line, allocator) orelse continue;
        try machines.append(allocator, machine);
    }

    return try machines.toOwnedSlice(allocator);
}

fn computeCoefBounds(basis: *Matrix, basis_idx: usize) [2]i64 {
    var min_coef: i64 = 0;
    var max_coef: i64 = 1000;

    for (0..basis.height) |j| {
        const r = basis.m[j][0];
        const b = basis.m[j][basis_idx];

        // Only apply bounds if this is the ONLY non-zero basis coefficient in this row
        var other_nonzero = false;
        for (1..basis.width) |k| {
            if (k != basis_idx and basis.m[j][k] != 0) {
                other_nonzero = true;
                break;
            }
        }
        if (other_nonzero) continue;

        if (b > 0) {
            const bound = @divFloor(-r, b);
            min_coef = @max(min_coef, bound);
        } else if (b < 0) {
            const bound = @divFloor(-r, b);
            max_coef = @min(max_coef, bound);
        }
    }

    return .{ min_coef, max_coef };
}

fn generateSolutions(basis: *Matrix, allocator: std.mem.Allocator) !i64 {
    const bases = try allocator.alloc(*Vector, basis.width);
    defer allocator.free(bases);

    for (0..basis.width) |i| {
        const basis_ = try basis.getColVec(i, allocator);
        bases[i] = basis_;
    }

    defer {
        for (0..basis.width) |i| {
            bases[i].deinit(allocator);
        }
    }

    var root = bases[0];

    const orig = try Matrix.fromArray(basis._values, basis.width, basis.height, allocator);
    defer orig.deinit(allocator);

    // generate every combination of coefs
    var ranges = try allocator.alloc([2]usize, basis.width - 1);
    defer allocator.free(ranges);

    for (1..basis.width) |i| {
        const bounds = computeCoefBounds(orig, i);
        const min_coef: usize = if (bounds[0] < 0) 0 else @intCast(bounds[0]);
        const max_coef: usize = if (bounds[1] > 10000) 10000 else @intCast(bounds[1]);

        std.debug.print("Basis {}: coef range [{}, {}]\n", .{ i, min_coef, max_coef });
        ranges[i - 1] = .{ min_coef, max_coef };
    }
    // need to have the root at least once
    var range = try RangeProduct.init(allocator, ranges);
    defer range.deinit();

    const accum_val = try allocator.alloc(i64, root.len);
    defer allocator.free(accum_val);
    var accum = try Vector.fromArray(accum_val, allocator);
    defer accum.deinit(allocator);

    var best: i64 = std.math.maxInt(i64);
    while (range.next()) |r| {
        // generate solution candidate
        // init solution to the root
        for (0..root.len) |i| accum.v[i] = orig.m[i][0];
        // odd linear combinations of the basis vectors
        for (0..basis.width) |base_idx| {
            var base = bases[base_idx];
            for (0..base.len) |i| {
                // init each basis
                base.v[i] = orig.m[i][base_idx];
            }
            if (base_idx == 0) continue;
            const coef: i64 = @intCast(r[base_idx - 1]);
            base.mul(coef);
            accum.addVec(base);
        }
        // check it
        var total: i64 = 0;
        var is_negative = false;
        for (0..accum.len) |i| {
            if (accum.v[i] < 0) {
                is_negative = true;
                break;
            }
            total += accum.v[i];
        }
        if (is_negative) continue;
        if (total > best) continue;
        if (total == best) {
            std.debug.print("Potential Solution: {}\n", .{total});
            std.debug.print("{any}\n", .{r});
            accum.print();
            continue;
        }
        if (total < best) {
            std.debug.print("New best:{}\n", .{total});
            std.debug.print("Solution:\n", .{});
            accum.print();
            best = total;
        }
    }
    if (best == std.math.maxInt(i64)) return error.NoSolution;

    return best;
}

fn solve(machine: *Machine, writer: *std.fs.File.Writer, allocator: std.mem.Allocator) !void {
    const mat = try machine.toMatrix(allocator);
    mat.print();
    defer mat.deinit(allocator);

    const vec = try machine.toVector(allocator);
    vec.print();
    defer vec.deinit(allocator);

    try eliminate(mat, vec);
    const basis = try extractBasisVectors(mat, vec, allocator);
    defer basis.deinit(allocator);

    // if (basis.m[0][0] > 1000000) {
    //     mat.print();
    //     vec.print();
    //     return error.Invalid;
    // }

    try basis.write(&writer.interface);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const contents = try readFile("/Users/benedictclarkson/Documents/advent_of_code_2025/inputs/day_10.txt", allocator);
    defer allocator.free(contents);

    const machines = try parseFile(contents, allocator);
    defer {
        for (machines) |machine| {
            machine.deinit(allocator);
        }
        allocator.free(machines);
    }

    const file = try std.fs.cwd().createFile("matrix.txt", .{});
    defer file.close();

    var buf: [1000000]u8 = undefined;
    var file_writer = file.writer(&buf);
    defer file_writer.interface.flush() catch {};

    for (machines) |machine| {
        try solve(machine, &file_writer, allocator);
    }

    // std.debug.print("Total: {}\n", .{total});
}
