const std = @import("std");
const gl = @import("gl");

pub const ShaderCreationError = error{
    // generic error
    CreationFailed,
    CompilationFailed,
};

const ShaderType = @import("../shader.zig").ShaderType;

const Shader = @This();

gl_id: gl.uint,
type: ShaderType,

pub fn deinit(self: Shader) void {
    gl.DeleteShader(self.gl_id);
}

// init function loads and compiles shader from file

// possible enhancements:
// - instead of ?*[]u8, use struct with error
// - instead of ?*[]u8 use anytype, if *[]u8 is provided, write the log into it, if struct is provided, write the error into it
pub fn initFromFile(
    alloc: std.mem.Allocator,
    shader_type: ShaderType,
    file_path: []const u8,
    error_log: ?*[]u8,
) !Shader {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_size = (try file.stat()).size;

    const source = try alloc.alloc(u8, file_size);
    defer alloc.free(source);

    _ = try file.readAll(source);

    return initFromSource(
        alloc,
        shader_type,
        source,
        error_log,
    );
}

pub fn initFromSource(
    alloc: std.mem.Allocator,
    shader_type: ShaderType,
    source: []const u8,
    error_log: ?*[]u8,
) !Shader {
    const shader = gl.CreateShader(
        switch (shader_type) {
            .vertex => gl.VERTEX_SHADER,
            .fragment => gl.FRAGMENT_SHADER,
        },
    );
    if (shader == gl.FALSE) {
        return ShaderCreationError.CreationFailed;
    }

    // Compile shader

    // ShaderSource can concatinate different strings, this is why it
    // expects that you'll pass multiple strings, see https://stackoverflow.com/a/22100409
    gl.ShaderSource(shader, 1, @ptrCast(&source), null);
    gl.CompileShader(shader);

    var success: gl.int = undefined;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success);

    if (success == gl.FALSE) {
        // if error_log is provided, write the log into it
        // freeing the code is the caller's responsibility
        if (error_log) |log| {
            const log_content = try getGLShaderCompilationLog(
                alloc,
                shader,
            );
            log.* = log_content;
        }

        return ShaderCreationError.CompilationFailed;
    }
    return Shader{
        .gl_id = shader,
        .type = shader_type,
    };
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
