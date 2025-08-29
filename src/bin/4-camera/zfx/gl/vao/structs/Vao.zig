const std = @import("std");
const gl = @import("gl");

const VAO = @This();

gl_id: gl.uint,

pub fn init() !VAO {
    var gl_id: gl.uint = undefined;
    gl.GenVertexArrays(1, @ptrCast(&gl_id));

    return VAO{
        .gl_id = gl_id,
    };
}

pub fn deinit(self: *VAO) void {
    gl.DeleteVertexArrays(1, @ptrCast(&self.*.gl_id));
}

pub fn bind(self: VAO) void {
    gl.BindVertexArray(self.gl_id);
}
