const std = @import("std");
const gl = @import("gl");

const Buffer = @This();

pub const BufferType = enum(gl.uint) {
    Vertex = gl.ARRAY_BUFFER,
    Index = gl.ELEMENT_ARRAY_BUFFER,

    pub fn toGL(self: BufferType) gl.uint {
        return @intFromEnum(self);
    }
};

pub const BufferDrawing = enum(gl.uint) {
    // Draw = the data store is modified by app, used by OpenGL
    // for drawing and image specific commands
    StreamDraw = gl.STREAM_DRAW, // write once, read a couple of times
    StaticDraw = gl.STATIC_DRAW, // write once, read many times
    DynamicDraw = gl.DYNAMIC_DRAW, // write many, read many

    // there are also Read and Copy

    pub fn toGL(self: BufferDrawing) gl.uint {
        return @intFromEnum(self);
    }
};

pub const BufferCreationError = error{
    CreationFailed,
};

gl_id: gl.uint,
type: BufferType,

pub fn init(
    buf_type: BufferType,
) !Buffer {
    var buffer_id: gl.uint = 0;
    gl.GenBuffers(1, @ptrCast(&buffer_id));
    if (buffer_id == 0) {
        return BufferCreationError.CreationFailed;
    }

    return Buffer{
        .gl_id = buffer_id,
        .type = buf_type,
    };
}

// takes a slice
pub fn setBufferData(
    self: Buffer,
    items: anytype,
    usage: BufferDrawing,
) void {
    self.bind();
    gl.BufferData(
        self.type.toGL(),
        items.len * @sizeOf(@TypeOf(items[0])),
        items.ptr,
        usage.toGL(),
    );
}

pub fn bind(self: Buffer) void {
    gl.BindBuffer(self.type.toGL(), self.gl_id);
}

pub fn unbind(self: Buffer) void {
    gl.BindBuffer(self.type.toGL(), 0);
}

pub fn deinit(self: *Buffer) void {
    gl.DeleteBuffers(1, @ptrCast(&self.*.gl_id));
}
