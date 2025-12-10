import cvxpy as cp
import numpy as np


def parse_file(path):
    with open(path, "r") as f:
        for line in f.read().split("\n"):
            if not line:
                continue
            binary_goal, *raw_vecs, goal = line.split(" ")

            binary_goal = [1 if b == "#" else 0 for b in binary_goal[1:-1]]
            binary_goal = np.array(binary_goal)
            goal = np.array([int(i) for i in goal[1:-1].split(",")])
            raw_vecs = [
                np.array([int(i) for i in vec[1:-1].split(",")]) for vec in raw_vecs
            ]

            vecs = []
            for vec in raw_vecs:
                binary = np.zeros(len(goal), dtype=np.int64)
                binary[vec] = 1
                vecs.append(binary)

            mat = np.vstack(vecs).T

            yield binary_goal, mat, goal


def size(val):
    out = 0
    while val > 0:
        out += val & 1
        val = val >> 1
    return out


def to_binary(arr):
    out = arr.dot(2 ** np.arange(len(arr))[::-1])
    out = int(out)
    return out


def solve_1(mat, goal):
    best = 1_000_000_000
    rows = [to_binary(row) for row in mat.T]
    num_cols = len(rows)
    goal_binary = to_binary(goal)

    for i in range(1 << num_cols):
        out = 0
        for j, row in enumerate(rows):
            if (i >> j) & 1 == 1:
                out ^= row
        if out == goal_binary:
            total = size(i)
            if total < best:
                best = total

    if best == 1_000_000_000:
        raise ValueError("No solution found")
    return best


def solve_2(mat, goal):
    dim = mat.shape[1]
    x = cp.Variable(dim, integer=True)

    constraints = [mat @ x == goal, x >= 0]
    prob = cp.Problem(cp.Minimize(cp.sum(x)), constraints)
    prob.solve()

    if prob.status != "optimal":
        raise ValueError

    solution = np.round(x.value).astype(int)

    if not np.allclose(mat @ solution, goal):
        print(mat)
        print(goal)
        print(solution)
        print(mat @ solution)
        raise ValueError()
    return solution.sum()


if __name__ == "__main__":
    part_1_total = 0
    part_2_total = 0
    for binary_goal, mat, goal in parse_file("inputs/day_10.txt"):
        part_1_total += solve_1(mat, binary_goal)
        part_2_total += solve_2(mat, goal)
    print(part_1_total)
    print(part_2_total)
