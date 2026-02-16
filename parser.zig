const std = @import("std");

fn findSection(comptime kw: []const u8, str: []const u8) ![]const u8 {
    var start: usize = 0;
    const open = "$" ++ kw;
    const close = "$End" ++ kw;
    for (str, 0..) |c, i| {
        if (c == '$' and str[i..].len >= open.len) {
            if (std.mem.eql(u8, str[i..][0..open.len], open)) {
                start = i + open.len;
                break;
            }
        }
    }
    if (start < open.len) return error.SectionNotFound;
    for (str[start..], start..) |c, i| {
        if (c == '$' and str[i..].len >= close.len) {
            if (std.mem.eql(u8, str[i..][0..close.len], close)) {
                return str[start..i];
            }
        }
    }
    return error.SectionMalformed;
}

pub fn main() !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    const alloc = arena.allocator();
 
    const file_content = try std.fs.cwd().readFileAlloc(alloc, "core_sample_hybrid_CFD.msh", 1024 * 1024 * 1024);
    const node_section = try findSection("Nodes", file_content);
    const elem_section = try findSection("Elements", file_content);



    const ParseState = enum {
        head, body, skip, stop
    };



    var node_line_iterator = std.mem.tokenizeAny(u8, node_section, "\r\n");
    const node_meta = node_line_iterator.next() orelse return error.Unexpected;

    var node_meta_iterator = std.mem.tokenizeScalar(u8, node_meta, ' ');
    _ = node_meta_iterator.next() orelse return error.Unexpected; // owners
    const node_tot = try std.fmt.parseUnsigned(u32, node_meta_iterator.next() orelse return error.Unexpected, 10);
    const node_min = try std.fmt.parseUnsigned(u32, node_meta_iterator.next() orelse return error.Unexpected, 10);
    const node_max = try std.fmt.parseUnsigned(u32, node_meta_iterator.next() orelse return error.Unexpected, 10);

    std.debug.print("nodes: {d} {d} {d}\n", .{ node_tot, node_min, node_max });

    const node_lut_buf: []SparseIndex = try alloc.alloc(SparseIndex, node_max - node_min + 1);
    const node_id_buf: []u32 = try alloc.alloc(u32, node_tot);
    const node_x_buf: []f32 = try alloc.alloc(f32, node_tot);
    const node_y_buf: []f32 = try alloc.alloc(f32, node_tot);
    const node_z_buf: []f32 = try alloc.alloc(f32, node_tot);
    var nodes: Nodes = .{
        .min = node_min,
        .max = node_max,
        .cap = node_tot,
        .len = 0,
        .lut = node_lut_buf,
        .id = node_id_buf,
        .x = node_x_buf,
        .y = node_y_buf,
        .z = node_z_buf,
    };
    @memset(node_lut_buf, .dead);

    {
        var index_iter = node_line_iterator;
        var coord_iter = index_iter;
        var body_count: u32 = 0;
        var skip_count: u32 = 0;
        parse: switch(ParseState.head) {
            .head => {
                const line = index_iter.next() orelse continue :parse .stop;
                var it = std.mem.tokenizeScalar(u8, line, ' ');

                const owner_dim = it.next().?; // null should be unreachable
                const owner_tag = it.next() orelse return error.NodeHeadMalformed;
                const node_type = it.next() orelse return error.NodeHeadMalformed;
                const node_size = it.next() orelse return error.NodeHeadMalformed;

                const dim = try std.fmt.parseUnsigned(u32, owner_dim, 10);
                const typ = try std.fmt.parseUnsigned(u32, node_type, 10);
                const num = try std.fmt.parseUnsigned(u32, node_size, 10);
                _ = owner_tag;

                if (dim != 3 or typ != 0) {
                    skip_count = num * 2;
                    continue :parse .skip;
                }

                body_count = num;
                coord_iter = index_iter;
                for (0..body_count) |_| {
                    _ = coord_iter.next() orelse return error.NodeBodyMalformed;
                }

                continue :parse .body;
            },
            .body => {
                if (body_count <= 0) {
                    index_iter = coord_iter;
                    continue :parse .head;
                }
                const index_line = index_iter.next() orelse return error.NodeBodyMalformed;
                const coord_line = coord_iter.next() orelse return error.NodeBodyMalformed;
                var it = std.mem.tokenizeScalar(u8, coord_line, ' ');
                const x = try std.fmt.parseFloat(f32, it.next() orelse return error.NodeBodyMalformed);
                const y = try std.fmt.parseFloat(f32, it.next() orelse return error.NodeBodyMalformed);
                const z = try std.fmt.parseFloat(f32, it.next() orelse return error.NodeBodyMalformed);
                const n = try std.fmt.parseUnsigned(u32, index_line, 10);
                try nodes.set(n, x, y, z);
                body_count -= 1;
                continue :parse .body;
            },
            .skip => {
                if (skip_count <= 0) continue :parse .head;
                _ = index_iter.next() orelse continue :parse .stop;
                skip_count -= 1;
                continue :parse .skip;
            },
            .stop => {},
        }
    }

    std.debug.print("node count: {any}\n", .{nodes.len});

    for (0..10) |i| {
        std.debug.print("index: {any}, coord: {any} {any} {any}\n", .{nodes.id[i], nodes.x[i], nodes.y[i], nodes.z[i]});
    }

    std.debug.print("...\n", .{});

    for (nodes.len - 1 - 10 .. nodes.len) |i| {
        std.debug.print("index: {any}, coord: {any} {any} {any}\n", .{nodes.id[i], nodes.x[i], nodes.y[i], nodes.z[i]});
    }



    var elem_line_iterator = std.mem.tokenizeAny(u8, elem_section, "\r\n");
    const elem_meta = elem_line_iterator.next() orelse return error.Unexpected;

    var elem_meta_iterator = std.mem.tokenizeScalar(u8, elem_meta, ' ');
    _ = elem_meta_iterator.next() orelse return error.Unexpected;
    
    const elem_tot = try std.fmt.parseUnsigned(u32, elem_meta_iterator.next() orelse return error.Unexpected, 10);
    const elem_min = try std.fmt.parseUnsigned(u32, elem_meta_iterator.next() orelse return error.Unexpected, 10);
    const elem_max = try std.fmt.parseUnsigned(u32, elem_meta_iterator.next() orelse return error.Unexpected, 10);
    
    std.debug.print("elems: {d} {d} {d}\n", .{ elem_tot, elem_min, elem_max });

    const elem_lut_buf: []SparseIndex = try alloc.alloc(SparseIndex, elem_max - elem_min + 1);
    const elem_id_buf: []u32 = try alloc.alloc(u32, elem_tot);
    const elem_v_buf: [][4]u32 = try alloc.alloc([4]u32, elem_tot);
    var elems: Elems = .{
        .min = elem_min,
        .max = elem_max,
        .cap = elem_tot,
        .len = 0,
        .lut = elem_lut_buf,
        .id = elem_id_buf,
        .v = elem_v_buf,
    };
    @memset(elem_lut_buf, .dead);

    {
        var index_iter = elem_line_iterator;
        var body_count: u32 = 0;
        var skip_count: u32 = 0;
        var head_count: u32 = 0;
        parse: switch(ParseState.head) {
            .head => {
                const line = index_iter.next() orelse continue :parse .stop;
                var it = std.mem.tokenizeScalar(u8, line, ' ');
                head_count += 1;
                // std.debug.print("head: {any}\n", .{head_count});
                const owner_dim = it.next().?; // null should be unreachable
                const owner_tag = it.next() orelse return error.ElemHeadMalformed;
                const elem_type = it.next() orelse return error.ElemHeadMalformed;
                const elem_size = it.next() orelse return error.ElemHeadMalformed;

                const dim = try std.fmt.parseUnsigned(u32, owner_dim, 10);
                const typ = try std.fmt.parseUnsigned(u32, elem_type, 10);
                const num = try std.fmt.parseUnsigned(u32, elem_size, 10);
                _ = owner_tag;

                if (dim != 3 or typ != 4) {
                    skip_count = num;
                    continue :parse .skip;
                }

                body_count = num;
                continue :parse .body;
            },
            .body => {
                if (body_count <= 0) {
                    continue :parse .head;
                }
                const index_line = index_iter.next() orelse return error.ElemBodyMalformed;
                var it = std.mem.tokenizeScalar(u8, index_line, ' ');
                const n = try std.fmt.parseUnsigned(u32, it.next() orelse return error.ElemBodyMalformed, 10);
                const a = try std.fmt.parseUnsigned(u32, it.next() orelse return error.ElemBodyMalformed, 10);
                const b = try std.fmt.parseUnsigned(u32, it.next() orelse return error.ElemBodyMalformed, 10);
                const c = try std.fmt.parseUnsigned(u32, it.next() orelse return error.ElemBodyMalformed, 10);
                const d = try std.fmt.parseUnsigned(u32, it.next() orelse return error.ElemBodyMalformed, 10);
                try elems.set(n, .{ a, b, c, d });
                body_count -= 1;
                continue :parse .body;
            },
            .skip => {
                if (skip_count <= 0) continue :parse .head;
                _ = index_iter.next() orelse continue :parse .stop;
                skip_count -= 1;
                continue :parse .skip;
            },
            .stop => {},
        }
    }

    std.debug.print("elem count: {any}\n", .{elems.len});

    for (0..10) |i| {
        std.debug.print("index: {any}, verts: {any}\n", .{elems.id[i], elems.v[i]});
    }

    std.debug.print("...\n", .{});

    for (elems.len - 1 - 10 .. elems.len) |i| {
        std.debug.print("index: {any}, verts: {any}\n", .{elems.id[i], elems.v[i]});
    }

}

const SparseIndex = enum(u32) {
    dead = 0,
    _,
    fn denseIndex(this: SparseIndex) ?u32 {
        if (this == .dead) return null;
        return @intFromEnum(this) - 1;
    }
    fn fromOffset(n: u32) SparseIndex {
        return @enumFromInt(n + 1);
    }
};

const Elems = struct {
    min: u32,
    max: u32,
    cap: u32,
    len: u32,
    lut: []SparseIndex, // MUST ZERO INIT! This allows you to set arbitrary ids
    id: []u32,
    v: [][4]u32,

    fn where(this: Elems, id: u32) !?u32 {
        if (id < this.min or id > this.max) return error.OutOfBounds;
        return this.lut[id - this.min].denseIndex();
    }

    fn kill(this: *Elems, id: u32) !bool {
        const denseIndex = (try this.where(id)) orelse return false;
        if (denseIndex == this.len - 1) {
            this.lut[id - this.min] = .dead;
        } else {
            const last = this.len - 1;
            const last_id = this.id[last];
            const last_v = this.v[last];
            this.v[denseIndex] = last_v;
            this.id[denseIndex] = last_id;
            this.lut[id - this.min] = .dead;
            this.lut[last_id - this.min] = .fromOffset(denseIndex);
        }
        this.len -= 1;
        return true;
    }

    fn get(this: Elems, id: u32) ?[4]u32 {
        const denseIndex = (this.where(id) catch return null) orelse return null;
        return this.v[denseIndex];
    }

    fn set(this: *Elems, id: u32, v: [4]u32) !void {
        const denseIndex = (try this.where(id)) orelse n: {
            if (this.len >= this.cap) return error.OutOfSpace;
            const n = this.len;
            this.lut[id - this.min] = .fromOffset(n);
            this.len += 1;
            break :n n;
        };
        this.id[denseIndex] = id;
        this.v[denseIndex] = v;
    }
};

const Nodes = struct {
    min: u32,
    max: u32,
    cap: u32,
    len: u32,
    lut: []SparseIndex, // MUST ZERO INIT! This allows you to set arbitrary ids
    id: []u32,
    x: []f32,
    y: []f32,
    z: []f32,

    fn where(this: Nodes, id: u32) !?u32 {
        if (id < this.min or id > this.max) return error.OutOfBounds;
        return this.lut[id - this.min].denseIndex();
    }

    fn kill(this: *Nodes, id: u32) !bool {
        const denseIndex = (try this.where(id)) orelse return false;
        if (denseIndex == this.len - 1) {
            this.lut[id - this.min] = .dead;
        } else {
            const last = this.len - 1;
            const last_id = this.id[last];
            const last_x = this.x[last];
            const last_y = this.y[last];
            const last_z = this.z[last];
            this.x[denseIndex] = last_x;
            this.y[denseIndex] = last_y;
            this.z[denseIndex] = last_z;
            this.id[denseIndex] = last_id;
            this.lut[id - this.min] = .dead;
            this.lut[last_id - this.min] = .fromOffset(denseIndex);
        }
        this.len -= 1;
        return true;
    }

    fn get(this: Nodes, id: u32) ?[3]f32 {
        const denseIndex = (this.where(id) catch return null) orelse return null;
        return .{
            this.x[denseIndex],
            this.y[denseIndex],
            this.z[denseIndex],
        };
    }

    fn set(this: *Nodes, id: u32, x: f32, y: f32, z: f32) !void {
        const denseIndex = (try this.where(id)) orelse n: {
            if (this.len >= this.cap) return error.OutOfSpace;
            const n = this.len;
            this.lut[id - this.min] = .fromOffset(n);
            this.len += 1;
            break :n n;
        };
        this.id[denseIndex] = id;
        this.x[denseIndex] = x;
        this.y[denseIndex] = y;
        this.z[denseIndex] = z;
    }
};

test Nodes {
    var lut_buf: [10]SparseIndex = @splat(std.mem.zeroes(SparseIndex));
    var id_buf: [10]u32 = undefined;
    var x_buf: [10]f32 = undefined;
    var y_buf: [10]f32 = undefined;
    var z_buf: [10]f32 = undefined;
    var nodes: Nodes = .{
        .min = 1,
        .max = 10,
        .cap = 10,
        .len = 0,
        .lut = &lut_buf,
        .id = &id_buf,
        .x = &x_buf,
        .y = &y_buf,
        .z = &z_buf,
    };
    try nodes.set(3, 0.1, 0.2, 0.3);
    try nodes.set(9, 0.4, 0.5, 0.6);
    try nodes.set(6, 0.7, 0.8, 0.9);
    const n3 = nodes.get(3) orelse return error.Unexpected;
    var n9 = nodes.get(9) orelse return error.Unexpected;
    var n6 = nodes.get(6) orelse return error.Unexpected;
    const p6 = try nodes.where(6) orelse return error.Unexpected;
    try std.testing.expect(n3[0] == 0.1 and n3[1] == 0.2 and n3[2] == 0.3);
    try std.testing.expect(n9[0] == 0.4 and n9[1] == 0.5 and n9[2] == 0.6);
    try std.testing.expect(n6[0] == 0.7 and n6[1] == 0.8 and n6[2] == 0.9);
    try std.testing.expect(try nodes.kill(3) == true);
    try std.testing.expect(nodes.get(3) == null);
    try std.testing.expect(try nodes.kill(3) == false);
    n9 = nodes.get(9) orelse return error.Unexpected;
    n6 = nodes.get(6) orelse return error.Unexpected;
    try std.testing.expect(n9[0] == 0.4 and n9[1] == 0.5 and n9[2] == 0.6);
    try std.testing.expect(n6[0] == 0.7 and n6[1] == 0.8 and n6[2] == 0.9);
    try std.testing.expect(p6 != try nodes.where(6) orelse return error.Unexpected);
    nodes.set(11, 0, 0, 0) catch |e| switch(e) { else => return };
    return error.Unexpected;
}
