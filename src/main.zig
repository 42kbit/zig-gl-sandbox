const std = @import("std");

extern "glfw" fn glfwGetVersion(major: *c_int, minor: *c_int, rev: *c_int) callconv(.C) void;

pub fn main() !void {
    var major: c_int = undefined;
    var minor: c_int = undefined;
    var rev: c_int = undefined;

    glfwGetVersion(&major, &minor, &rev);
    std.debug.print("Running GLFW {d}.{d}.{d}...!\n", .{ major, minor, rev });
}
