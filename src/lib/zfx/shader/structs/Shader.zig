const std = @import("std");
const gl = @import("gl");

// TODO: more verbose error handling
pub const ShaderCreationError = error{
    // generic error
    ShaderCreationFailed,
    ShaderCompilationFailed,
};

const ShaderType = @import("../shader.zig").ShaderType;

const Shader = @This();

gl_shader_id: gl.uint,
type: ShaderType,

pub fn deinit(self: Shader) void {
    gl.DeleteShader(self.gl_shader_id);
}

pub fn initFromFile(
    alloc: std.mem.Allocator,
    shader_type: ShaderType,
    file_path: []const u8,
) !Shader {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_size = try file.stat().size;

    const source = try alloc.alloc(u8, file_size);
    defer alloc.free(source);

    _ = try file.readAll(source);

    return initFromSource(shader_type, source);
}

pub fn initFromSource(
    shader_type: ShaderType,
    source: []const u8,
) ShaderCreationError!Shader {
    const shader = gl.CreateShader(
        switch (shader_type) {
            .vertex => gl.VERTEX_SHADER,
            .fragment => gl.FRAGMENT_SHADER,
        },
    );
    if (shader == gl.FALSE) {
        return error.ShaderCreationFailed;
    }

    // Compile shader

    // ShaderSource can concatinate different strings, this is why it
    // expects that you'll pass multiple strings, see https://stackoverflow.com/a/22100409
    gl.ShaderSource(shader, 1, @ptrCast(&source), null);
    gl.CompileShader(shader);

    var success: gl.int = undefined;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success);

    if (success == gl.FALSE) {
        return error.ShaderCompilationFailed;
    }
    return Shader{
        .gl_shader_id = shader,
        .type = shader_type,
    };
}

pub fn getShaderCompilationLog(
    shader: Shader,
    alloc: std.mem.Allocator,
) ![]u8 {
    return try getGLShaderCompilationLog(alloc, shader.gl_shader_id);
}

fn getGLShaderCompilationLog(
    alloc: std.mem.Allocator,
    shader: gl.uint,
) ![]u8 {
    // get error log length
    var log_length: gl.int = 0;
    gl.GetShaderiv(
        shader,
        gl.INFO_LOG_LENGTH,
        &log_length,
    );

    // allocate log_length
    const log: []u8 = try alloc.alloc(
        u8,
        @intCast(log_length),
    );

    // write log length into a buffer
    gl.GetShaderInfoLog(
        shader,
        log_length,
        null,
        log.ptr,
    );

    return log;
}
