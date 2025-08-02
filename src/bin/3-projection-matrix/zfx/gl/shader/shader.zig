const std = @import("std");
const gl = @import("gl");

// Shader
pub const Shader = @import("structs/Shader.zig");
// Shader Program, bound to pipeline
pub const ShaderProgram = @import("structs/ShaderProgram.zig");
pub const ShaderType = enum {
    vertex,
    fragment,
};
