const std = @import("std");
const glfw = @import("zglfw");

const gl = @import("gl");

const zfx = @import("zfx");

const Shader = zfx.gl.shader.Shader;
const ShaderCreationError = zfx.gl.shader.Shader.ShaderCreationError;
const ShaderType = zfx.gl.shader.ShaderType;

const ShaderProgram = zfx.gl.shader.ShaderProgram;
const ShaderProgramCreationError = zfx.gl.shader.ShaderProgram.ShaderProgramCreationError;

const Buffer = zfx.gl.buffer.Buffer;

const alloc = std.heap.page_allocator;

var gl_procs: gl.ProcTable = undefined;

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

    const target_fps = 60;
    const target_frame_time_ns = @divFloor(1_000_000_000, target_fps);

    var timer = try std.time.Timer.start();

    const verticies = [_][6]f32{
        [_]f32{ -0.5, -0.5, 0.0, 1.0, 0.0, 0.0 },
        [_]f32{ 0.5, -0.5, 0.0, 0.0, 1.0, 0.0 },
        [_]f32{ 0.0, 0.5, 0.0, 1.0, 1.0, 0.0 },
    };
    // Byte size of each vertex attribute
    const stride: comptime_int = verticies[0].len * @sizeOf(f32);

    const verts_len: comptime_int = verticies.len * verticies[0].len;
    // Cast "verticies" to a 1D array
    const v_ptr: *const [verts_len]f32 = @ptrCast(&verticies);

    const indices = [_]u32{ 0, 1, 2 };
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
        "src/bin/2-zfx-hello-world/vertex.glsl",
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
        "src/bin/2-zfx-hello-world/fragment.glsl",
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

    var vao: gl.uint = undefined;
    gl.GenVertexArrays(1, @ptrCast(&vao));
    defer gl.DeleteVertexArrays(1, @ptrCast(&vao));

    gl.BindVertexArray(vao);

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
    // layout (location 1) in the vertex shader
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(
        1,
        3,
        gl.FLOAT,
        gl.FALSE,
        stride,
        3 * @sizeOf(f32),
    );

    // Get the location of the uniform variable in the shader program
    // does not requrie binding the shader program
    const location = gl.GetUniformLocation(
        shader_program.gl_id,
        "uTime",
    );
    if (location == -1) {
        @panic("Uniform variable 'uTime' not found in shader program");
    }

    while (!glfw.windowShouldClose(window)) {
        const frame_start = timer.read();

        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        // Clear the screen
        gl.ClearColor(0.0, 0.0, 1.0, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        gl.UseProgram(shader_program.gl_id);
        // uniforms are bound to the shader program,
        // so we set them after binding the program
        const time = glfw.getTime();
        gl.Uniform1d(location, time);

        // Bind the vertex array object, which contains the vertex buffer and its attributes
        gl.BindVertexArray(vao);

        // Draw
        gl.DrawElements(
            gl.TRIANGLES,
            3,
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
