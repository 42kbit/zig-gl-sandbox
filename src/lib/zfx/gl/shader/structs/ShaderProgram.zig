const std = @import("std");
const gl = @import("gl");

const Shader = @import("../shader.zig").Shader;

const ShaderProgram = @This();

pub const ShaderProgramCreationError = error{
    CreationFailed,
    LinkageFailed,
};

gl_id: gl.uint,

pub fn init(
    alloc: std.mem.Allocator,
    shaders: []const Shader,
    error_log: ?*[]u8,
) !ShaderProgram {
    const program = gl.CreateProgram();
    if (program == gl.FALSE) {
        return ShaderProgramCreationError.CreationFailed;
    }

    for (shaders) |shader| {
        gl.AttachShader(program, shader.gl_id);
    }

    gl.LinkProgram(program);
    // handle error
    var link_status: gl.int = 0;
    gl.GetProgramiv(program, gl.LINK_STATUS, &link_status);
    if (link_status == gl.FALSE) {
        if (error_log) |log| {
            const log_content = try getProgramLinkLog(alloc, program);
            // caller should free the log
            log.* = log_content;
        }
        return ShaderProgramCreationError.LinkageFailed;
    }

    return ShaderProgram{
        .gl_id = program,
    };
}

pub fn deinit(self: ShaderProgram) !void {
    gl.DeleteProgram(self.gl_id);
}

fn getProgramLinkLog(
    alloc: std.mem.Allocator,
    program: gl.uint,
) ![]u8 {
    var log_length: gl.int = 0;
    gl.GetProgramiv(program, gl.INFO_LOG_LENGTH, &log_length);

    const log: []u8 = try alloc.alloc(u8, @intCast(log_length));
    gl.GetProgramInfoLog(program, log_length, null, log.ptr);

    return log;
}
