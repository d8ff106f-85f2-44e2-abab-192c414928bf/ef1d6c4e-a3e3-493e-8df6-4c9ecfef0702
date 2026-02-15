const std = @import("std");
const meshfile = @embedFile("core_sample_hybrid_CFD.msh");

pub fn main() void {
    std.debug.print("{any}", .{meshfile.len});
}