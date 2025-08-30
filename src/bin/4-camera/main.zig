const std = @import("std");
const glfw = @import("zglfw");

const gl = @import("gl");

const zm = @import("zm");

const zfx = @import("zfx/lib.zig");

const Shader = zfx.gl.shader.Shader;
const ShaderCreationError = zfx.gl.shader.Shader.ShaderCreationError;
const ShaderType = zfx.gl.shader.ShaderType;

const ShaderProgram = zfx.gl.shader.ShaderProgram;
const ShaderProgramCreationError = zfx.gl.shader.ShaderProgram.ShaderProgramCreationError;

const Buffer = zfx.gl.buffer.Buffer;

const VAO = zfx.gl.vao.VAO;

const alloc = std.heap.page_allocator;

var gl_procs: gl.ProcTable = undefined;

const Texture2D = struct {
    data: []const u8,
    width: gl.sizei,
    height: gl.sizei,

    // alloc: std.mem.Allocator,

    // when not []const u8 but []u8
    // pub fn initRaw(
    //     tex_alloc: std.mem.Allocator,
    //     width: gl.sizei,
    //     height: gl.sizei,
    //     data_source: []const u8,
    // ) !Texture2D {
    //     var tex = Texture2D{
    //         .data = undefined,
    //         .width = width,
    //         .height = height,
    //         .alloc = alloc,
    //     };

    //     tex.data = try tex_alloc.alloc(
    //         u8,
    //         @intCast(width * height),
    //     );

    //     std.mem.copyForwards(u8, tex.data, data_source);

    //     return tex;
    // }

    // pub fn deinit(self: *Texture2D) void {
    //     self.alloc.free(self.data);
    // }
};

const triangle = Texture2D{
    .height = 2,
    .width = 2,
    // rgba from bottom-left
    .data = &texture_data,
};

const texture_data = [_]u8{ 255, 0, 0, 0, 255, 255, 0, 0, 0, 255, 0, 0, 0, 0, 255, 0 };

fn resize_callback(window: *glfw.Window, width: c_int, height: c_int) callconv(.C) void {
    _ = window;
    gl.Viewport(0, 0, width, height);
}

pub fn main() !void {
    var major: i32 = 0;
    var minor: i32 = 0;
    var rev: i32 = 0;

    glfw.getVersion(&major, &minor, &rev);
    std.debug.print("GLFW {}.{}.{}\n", .{ major, minor, rev });

    //Example of something that fails with GLFW_NOT_INITIALIZED - but will continue with execution
    //var monitor: ?*glfw.Monitor = glfw.getPrimaryMonitor();

    try glfw.init();
    defer glfw.terminate();
    std.debug.print("GLFW Init Succeeded.\n", .{});

    const WindowDimensions = struct {
        width: c_int,
        height: c_int,
    };

    const window_dimensions: WindowDimensions = .{
        .width = 800,
        .height = 600,
    };

    const window: *glfw.Window = try glfw.createWindow(
        window_dimensions.width,
        window_dimensions.height,
        "Hello World",
        null,
        null,
    );
    defer glfw.destroyWindow(window);

    glfw.makeContextCurrent(window);

    if (!gl_procs.init(glfw.getProcAddress)) {
        @panic("could not get glproc");
    }
    gl.makeProcTableCurrent(&gl_procs);

    const version = gl.GetString(gl.VERSION) orelse "unknown";
    std.debug.print("OpenGL version: {s}\n", .{version});

    _ = glfw.setWindowSizeCallback(window, resize_callback);

    const target_fps = 60;
    const target_frame_time_ns = @divFloor(1_000_000_000, target_fps);

    var timer = try std.time.Timer.start();

    const verticies = [_][5]f32{
        // x, y, z, s, t
        [_]f32{ -1.0, -1.0, 0.0, 0.0, 0.0 }, // bottom left corner
        [_]f32{ -1.0, 1.0, 0.0, 0.0, 1.0 }, // top left corner
        [_]f32{ 1.0, 1.0, 0.0, 1.0, 1.0 }, // top right corner
        [_]f32{ 1.0, -1.0, 0.0, 1.0, 0.0 },
    };
    // Byte size of each vertex attribute
    const stride: comptime_int = verticies[0].len * @sizeOf(f32);

    const verts_len: comptime_int = verticies.len * verticies[0].len;
    // Cast "verticies" to a 1D array
    const v_ptr: *const [verts_len]f32 = @ptrCast(&verticies);

    const indices = [_]u32{ 0, 1, 2, 0, 2, 3 };
    const indices_len: comptime_int = indices.len;

    var ebo = try Buffer.init(.Index);
    ebo.bind();
    ebo.setBufferData(
        indices[0..indices_len],
        .StaticDraw,
    );
    defer ebo.deinit();

    var vbo = try Buffer.init(.Vertex);
    vbo.bind();
    vbo.setBufferData(
        v_ptr[0..verts_len],
        .StaticDraw,
    );
    defer vbo.deinit();

    var vshader_err: []u8 = undefined;
    const vshader = Shader.initFromFile(
        alloc,
        .vertex,
        "src/bin/4-camera/vertex.glsl",
        &vshader_err,
    ) catch |err| switch (err) {
        ShaderCreationError.CompilationFailed => {
            std.debug.print("Vertex Shader creation failed:\n\t{s}\n", .{vshader_err});
            alloc.free(vshader_err); // free error log
            return err;
        },
        else => return err,
    };
    defer vshader.deinit();

    var fshader_err: []u8 = undefined;
    const fshader = Shader.initFromFile(
        alloc,
        .fragment,
        "src/bin/4-camera/fragment.glsl",
        &fshader_err,
    ) catch |err| switch (err) {
        ShaderCreationError.CompilationFailed => {
            std.debug.print("Vertex Shader creation failed:\n\t{s}\n", .{fshader_err});
            alloc.free(fshader_err);
            return err;
        },
        else => return err,
    };
    // process error if any
    defer fshader.deinit();

    var shader_program_err: []u8 = undefined;
    const shader_program = ShaderProgram.init(
        alloc,
        &[_]Shader{ vshader, fshader },
        &shader_program_err,
    ) catch |err| switch (err) {
        ShaderProgramCreationError.LinkageFailed => {
            std.debug.print("Shader Program linking failed:\n\t{s}\n", .{shader_program_err});
            alloc.free(shader_program_err);
            return err;
        },
        else => return err,
    };

    var tex_id: gl.uint = undefined;
    gl.GenTextures(1, @ptrCast(&tex_id));
    defer gl.DeleteTextures(1, @ptrCast(&tex_id));

    // activate zeroth texture
    gl.ActiveTexture(gl.TEXTURE0);
    // bind this texture to global context and slot 0
    gl.BindTexture(gl.TEXTURE_2D, tex_id);

    // How the texture() function in GLSL should handle the texture interpolation (texture filtering)
    // In this case since the texture is only 2 by 2 pixels and a triangle is much more than that
    // We really only need the MAG_FILTER (magnifiying image), but we still set
    // MIN (minifying image) just for my sanity
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    // populate currently bound texture with data
    gl.TexImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        triangle.width,
        triangle.height,
        0,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        &texture_data,
    );

    // Generate Mipmaps for the texture
    gl.GenerateMipmap(gl.TEXTURE_2D);

    // since texture is currently bound, it can be used in a graphics pipeline

    var vao = try VAO.init();
    defer vao.deinit();

    vao.bind();

    // VAO also stores the EBO, so we can bind it here
    ebo.bind();

    // Bind the VBO to which vertex attributes would apply
    vbo.bind();
    // Enable vertex attribute array "layout (location 0)" in the vertex shader

    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(
        0, // Attribute location (location 0)
        3, // number of components per vertex attribute 3 floats
        gl.FLOAT, // type of each component (f32)
        gl.FALSE, // for non-integer data types, this should be false
        stride, // size of each vertex attribute in bytes (3 floats)
        0, // offset where the data starts in the buffer
    );

    // texture coords
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(
        1,
        2,
        gl.FLOAT,
        gl.FALSE,
        stride,
        3 * @sizeOf(f32),
    );

    gl.UseProgram(shader_program.gl_id);

    const tex_location = gl.GetUniformLocation(
        shader_program.gl_id,
        "texture0",
    );
    if (tex_location == -1) {
        @panic("Texture position not found");
    }
    // pass the currently bound texture 0
    gl.Uniform1i(tex_location, 0);

    const u_proj_location = gl.GetUniformLocation(
        shader_program.gl_id,
        "uProjection",
    );
    if (u_proj_location == -1) {
        @panic("uProjection not found in shader");
    }

    const u_view_location = gl.GetUniformLocation(
        shader_program.gl_id,
        "uView",
    );
    if (u_view_location == -1) {
        @panic("uView not found in shader");
    }

    const u_model_location = gl.GetUniformLocation(
        shader_program.gl_id,
        "uModel",
    );
    if (u_model_location == -1) {
        @panic("uModel not found in shader");
    }
    var camera_position = zm.Vec3f{
        0,
        0,
        3,
    };

    while (!glfw.windowShouldClose(window)) {
        const frame_start = timer.read();

        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        // Clear the screen
        gl.ClearColor(0.0, 0.0, 1.0, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        gl.UseProgram(shader_program.gl_id);

        var window_width: c_int = undefined;
        var window_height: c_int = undefined;
        glfw.getWindowSize(window, &window_width, &window_height);

        const projection = zm.Mat4f.perspective(
            std.math.degreesToRadians(45.0),
            @divFloor(
                @as(f32, @floatFromInt(window_width)),
                @as(f32, @floatFromInt(window_height)),
            ),
            0.1,
            100,
        );

        // since opengl is right handed, and Z coordinate is flipped after projection matrix multiplication
        // The "forward" vector is flipped, e.g to transform
        const camera_target = camera_position + zm.Vec3f{ 0, 0, -1 };
        const camera_forward = zm.vec.normalize(camera_target - camera_position);
        const camera_right = zm.vec.normalize(
            zm.vec.cross(camera_forward, zm.Vec3f{ 0, 1, 0 }),
        );
        const camera_up = zm.vec.cross(camera_right, camera_forward);

        if (glfw.getKey(window, glfw.KeyD) == glfw.Press) {
            camera_position += zm.vec.scale(camera_right, 0.01);
        }
        if (glfw.getKey(window, glfw.KeyA) == glfw.Press) {
            camera_position -= zm.vec.scale(camera_right, 0.01);
        }
        if (glfw.getKey(window, glfw.KeyW) == glfw.Press) {
            camera_position += zm.vec.scale(camera_forward, 0.01);
        }
        if (glfw.getKey(window, glfw.KeyS) == glfw.Press) {
            camera_position -= zm.vec.scale(camera_forward, 0.01);
        }
        if (glfw.getKey(window, glfw.KeySpace) == glfw.Press) {
            camera_position += zm.vec.scale(camera_up, 0.01);
        }
        if (glfw.getKey(window, glfw.KeyLeftShift) == glfw.Press) {
            camera_position -= zm.vec.scale(camera_up, 0.01);
        }
        const view = zm.Mat4f.lookAt(
            camera_position,
            camera_position + camera_forward,
            zm.Vec3f{ 0, 1, 0 },
        );

        // move the rotate the cube and move it a bit forward
        const model = zm.Mat4f.identity()
            .multiply(zm.Mat4f.translation(0, 0, 0))
            .multiply(zm.Mat4f.rotation(
                zm.Vec3f{ 1, 0, 0 },
                std.math.degreesToRadians(-45),
            )).multiply(zm.Mat4f.scaling(0.75, 0.75, 1));

        gl.UniformMatrix4fv(
            u_proj_location,
            1,
            gl.TRUE, // alternatively you can transpose matrix by calling .transpose() on Mat4 (CPU side)
            @ptrCast(&projection),
        );

        gl.UniformMatrix4fv(
            u_view_location,
            1,
            gl.TRUE, // alternatively you can transpose matrix by calling .transpose() on Mat4 (CPU side)
            @ptrCast(&view),
        );

        gl.UniformMatrix4fv(
            u_model_location,
            1,
            gl.TRUE, // alternatively you can transpose matrix by calling .transpose() on Mat4 (CPU side)
            @ptrCast(&model),
        );

        // Bind the vertex array object, which contains the vertex buffer and its attributes
        gl.BindVertexArray(vao.gl_id);

        // Draw a screen quad
        gl.DrawElements(
            gl.TRIANGLES,
            6,
            gl.UNSIGNED_INT,
            0,
        );

        // Rate limit
        const frame_end = timer.read();
        const elapsed = frame_end - frame_start;

        if (elapsed < target_frame_time_ns) {
            std.time.sleep(target_frame_time_ns - elapsed);
        }

        glfw.pollEvents();
        glfw.swapBuffers(window);
    }
}
