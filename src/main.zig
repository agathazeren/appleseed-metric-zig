const std = @import("std");
const debug = std.debug;
const testing = std.testing;
const math = std.math;

/// A node in the trust graph. This must be initialized to its default value
/// before each time `appleseed` is called. After `appleseed` is called the
/// trust (accumulated energy) of the node is in the `trust` field.
pub const Node = struct {
    trust: f32 = 0.0,

    // This is `next' instead of `last' so that there does not need to be a null.
    next_upkeep: Iter = 0,

    incoming: f32 = 0.0,
    incoming_next: f32 = 0.0,

    outgoing_weights_discovered: bool = false,
    outgoing_weight: f32 = 0.0,

    fn validate(self: *const Node) !void {
        if (self.*.next_upkeep == 0 and self.trust != 0.0) unreachable;
    }

    const Upkeep = struct {
        i: Iter,
        source: *Node,
        max: *f32,
        params: *const Params,
    };

    fn upkeep(self: *Node, u: Upkeep) void {
        debug.assert(self.*.next_upkeep == u.i);

        // this must be at the top of the funciton, not the bottom, to ensure
        // recusion terminates.
        self.*.next_upkeep = u.i + 1;

        if (self != u.source) {
            // accumulate
            var accumulate = self.*.incoming_next * (1.0 - u.params.spreading_factor);
            if (accumulate > u.max.*) u.max.* = accumulate;
            self.trust += accumulate;
        }

        // bump incoming
        self.*.incoming = self.*.incoming_next;
        self.*.incoming_next = 0.0;

        // Backpropagate
        if (self != u.source) {
            u.source.maybeUpkeep(u);
            propagate(Trust{ .source = self, .dest = u.source, .weight = 1.0 }, u.params);
        }
    }

    fn maybeUpkeep(self: *Node, u: Upkeep) void {
        if (timeTo(self.*.next_upkeep, u.i)) {
            self.upkeep(u);
        }
    }
};

/// An edge in the trust graph.
pub const Trust = struct {
    source: *Node,
    dest: *Node,
    weight: f32,

    fn validate(self: *const Trust) !void {
        try self.source.validate();
        try self.dest.validate();
    }
};

/// The parameters of the function. Resonable default values, determined
/// experimentally by the origional paper are provided as default values.
pub const Params = struct {
    initial_energy: f32 = 200.0,
    spreading_factor: f32 = 0.85,
    threshold: f32 = 0.01,

    fn validate(self: *const Params) !void {
        if (self.initial_energy <= 0) return error.InitialEnergyOutOfRange;
        if (self.spreading_factor < 0 or self.spreading_factor > 1) return error.SpreadingFactorOutOfRange;
        if (self.threshold <= 0) return error.ThresholdOutOfRange;
    }
};

pub const AppleseedError = error{
    /// The spreading factor must be in the range [0, 1).
    SpreadingFactorOutOfRange,

    /// The initial energy must be positive.
    InitialEnergyOutOfRange,

    /// The threshold must be positive.
    ThresholdOutOfRange,
};

const Iter = u16;

/// The appleseed algorithm. Requires exclusive access to all of the nodes
/// present in the trust graph, including the source, as well as nonexclusive
/// access to the edges of the trust graph as well as the parameters. All of the
/// `Node`s present in the trust graph must be initalized to the default
/// value. If any are not, this is undefined behavior. The values of `params`
/// are validated before use, and an error union is returned, so domain checking
/// for `params` is not required. After the function returns, the `trust` field
/// of each of the nodes will have the trust value.
pub fn appleseed(source: *Node, edges: []const Trust, params: *const Params) AppleseedError!void {
    try params.validate();

    source.*.trust = 0.0;
    source.*.incoming_next = params.initial_energy;

    try initializeOutgoingWeights(source, edges);

    var max: f32 = math.inf(f32);

    var i: Iter = 0;
    while (max > params.threshold or i < 3) : (i += 1) {
        max = -math.inf(f32);

        for (edges) |edge| {
            try edge.validate();

            for ([_]*Node{ edge.source, edge.dest }) |node| {
                node.maybeUpkeep(.{
                    .i = i,
                    .source = source,
                    .params = params,
                    .max = &max,
                });
            }

            propagate(edge, params);
        }
    }
}

fn propagate(trust: Trust, params: *const Params) void {
    var total_energy_to_distribute = trust.source.*.incoming * params.spreading_factor;
    var edge_fraction = trust.weight / trust.source.*.outgoing_weight;
    var energy = total_energy_to_distribute * edge_fraction;
    trust.dest.*.incoming_next += energy;
}

fn initializeOutgoingWeights(source: *Node, edges: []const Trust) !void {
    for (edges) |edge| {

        // Forwardpropagate
        edge.source.outgoing_weight += edge.weight;

        // Backpropagate
        for ([_]*Node{ edge.source, edge.dest }) |node| {
            if (node == source) continue;
            if (!node.*.outgoing_weights_discovered) {
                node.*.outgoing_weight += 1.0;
                node.*.outgoing_weights_discovered = true;
            }
        }
    }
}

fn timeTo(next: Iter, i: Iter) bool {
    if (next < i) unreachable;
    if (next > i) return false;
    if (next == i) return true;
    unreachable;
}

test "instantiation" {
    var a = Node{};
    var b = Node{};
    var c = Node{};
    var d = Node{};
    var x = Node{};
    var y = Node{};

    const trusts = [_]Trust{
        .{ .source = &a, .dest = &b, .weight = 0.80 },
        .{ .source = &a, .dest = &c, .weight = 0.80 },
        .{ .source = &b, .dest = &d, .weight = 0.80 },
        .{ .source = &x, .dest = &y, .weight = 0.80 },
    };

    try appleseed(&a, &trusts, &Params{});

    try testing.expect(b.trust > 0.0); // nodes b-d recived trust
    try testing.expect(c.trust > 0.0);
    try testing.expect(d.trust > 0.0);
    try testing.expect(a.trust == 0.0); // the source does not
    try testing.expect(x.trust == 0.0); // x, y are unconnected
    try testing.expect(y.trust == 0.0);
}

test "simple one hop, same weights" {
    var a = Node{};
    var b = Node{};
    var c = Node{};
    var d = Node{};

    const trusts = [_]Trust{
        .{ .source = &a, .dest = &b, .weight = 0.80 },
        .{ .source = &b, .dest = &c, .weight = 0.80 },
        .{ .source = &b, .dest = &d, .weight = 0.80 },
    };

    try appleseed(&a, &trusts, &Params{});
    try testing.expect(b.trust > 0.0);
    try testing.expect(b.trust > c.trust);
    try testing.expect(b.trust > d.trust);
}

test "simple one hop, lower weight" {
    var a = Node{};
    var b = Node{};
    var c = Node{};
    var d = Node{};

    const trusts = [_]Trust{
        .{ .source = &a, .dest = &b, .weight = 0.80 },
        .{ .source = &b, .dest = &c, .weight = 0.80 },
        .{ .source = &b, .dest = &d, .weight = 0.40 },
    };

    try appleseed(&a, &trusts, &Params{});
    try testing.expect(b.trust > 0.0);
    try testing.expect(b.trust > c.trust);
    try testing.expect(b.trust > d.trust);
    try testing.expect(c.trust > d.trust);
}

test "two trustees" {
    var a = Node{};
    var b = Node{};
    var c = Node{};
    var d = Node{};
    var e = Node{};

    const trusts = [_]Trust{
        .{ .source = &a, .dest = &b, .weight = 0.80 },
        .{ .source = &a, .dest = &c, .weight = 0.80 },
        .{ .source = &b, .dest = &d, .weight = 0.80 },
        .{ .source = &b, .dest = &e, .weight = 0.80 },
        .{ .source = &c, .dest = &d, .weight = 0.80 },
    };

    try appleseed(&a, &trusts, &Params{});
    try testing.expect(d.trust > e.trust);
}
