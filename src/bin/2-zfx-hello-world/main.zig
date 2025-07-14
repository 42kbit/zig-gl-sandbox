const std = @import("std");
const glfw = @import("zglfw");

const gl = @import("gl");

const zfx = @import("zfx");

var gl_procs: gl.ProcTable = undefined;

const glsl_vertex_shader =
    \\#version 430 core
    \\layout (location = 0) in vec3 aPos;
    \\layout (location = 1) in vec3 aColor;
    \\
    \\out vec3 vertexColor;
    \\
    \\uniform double uTime;
    \\
    \\void main()
    \\{
    \\    vertexColor = aColor;
    \\    // cast 64 bit float to 32 bit float
    \\    float y_pos = aPos.y + sin(float(uTime)) * 0.2; // animate y position with time
    \\    gl_Position = vec4(aPos.x, y_pos, aPos.z, 1.0);
    \\}
    \\
;

const glsl_fragment_shader =
    \\#version 430 core
    \\out vec4 FragColor;
    \\
    \\uniform double uTime;
    \\
    \\// Name should match the output from vertex shader
    \\in vec3 vertexColor;
    \\
    \\void main()
    \\{
    \\  // animate color with time
    \\  float red = abs(vertexColor.x * sin(float(uTime)));
    \\  float green = abs(vertexColor.y * sin(float(uTime)));
    \\  float blue = abs(vertexColor.z * sin(float(uTime)));
    \\  vec3 newColor = vec3(red, green, blue);
    \\  FragColor = vec4(newColor, 1.0);
    \\}
    \\
;

fn compileShaderSingle(
    shader: gl.uint,
    source: []const u8,
) gl.int {
    // ShaderSource can concatinate different strings, this is why it
    // expects that you'll pass multiple strings, see https://stackoverflow.com/a/22100409
    gl.ShaderSource(shader, 1, @ptrCast(&source), null);
    gl.CompileShader(shader);

    var success: gl.int = undefined;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success);
    return success;
}

fn getShaderCompilationLog(
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

fn panicOnShaderCompilationError(
    alloc: std.mem.Allocator,
    shader: gl.uint,
) noreturn {
    const log = getShaderCompilationLog(
        alloc,
        shader,
    ) catch @panic("OOM");
    defer alloc.free(log);

    // print the error log with \n\t
    std.debug.print(
        "Fragment Shader compilation failed\n\t{s}\n",
        .{log},
    );
    @panic("Fragment shader compilation failed");
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

fn panicOnProgramLinkError(
    alloc: std.mem.Allocator,
    program: gl.uint,
) noreturn {
    const log = getProgramLinkLog(alloc, program) catch @panic("OOM");
    defer alloc.free(log);

    std.debug.print(
        "Shader program linking failed\n\t{s}\n",
        .{log},
    );
    @panic("Shader program linking failed");
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
    // Cast "indices" to a 1D array
    const i_ptr: *const [indices_len]u32 = @ptrCast(&indices);

    // create EBO (Element Buffer Object)
    var ebo: gl.uint = undefined;
    gl.GenBuffers(1, @ptrCast(&ebo));
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.BufferData(
        gl.ELEMENT_ARRAY_BUFFER,
        indices_len * @sizeOf(u32),
        i_ptr,
        gl.STATIC_DRAW,
    );
    defer gl.DeleteBuffers(1, @ptrCast(&ebo));

    var vbo: gl.uint = undefined;
    // ptrCast is used to cast *gl.uint to [*]gl.uint
    gl.GenBuffers(1, @ptrCast(&vbo));

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(
        gl.ARRAY_BUFFER,
        verts_len * @sizeOf(f32),
        v_ptr,
        gl.STATIC_DRAW,
    );
    defer gl.DeleteBuffers(1, @ptrCast(&vbo));

    // TODO:
    // - Error handling
    // - Read shaders from file
    const vshader = try zfx.shader.Shader.initFromSource(
        .vertex,
        glsl_vertex_shader,
    );
    defer vshader.deinit();

    const fshader = try zfx.shader.Shader.initFromSource(
        .fragment,
        glsl_fragment_shader,
    );
    defer fshader.deinit();

    // // Compile vertex shader
    // const vertex_shader: gl.uint = gl.CreateShader(gl.VERTEX_SHADER);
    // defer gl.DeleteShader(vertex_shader);

    // const success: gl.int = compileShaderSingle(vertex_shader, glsl_vertex_shader);
    // if (success == gl.FALSE) {
    //     panicOnShaderCompilationError(std.heap.page_allocator, vertex_shader);
    // }

    // // Compile fragment shader
    // const fragment_shader: gl.uint = gl.CreateShader(gl.FRAGMENT_SHADER);
    // defer gl.DeleteShader(fragment_shader);

    // const success_fragment: gl.int = compileShaderSingle(
    //     fragment_shader,
    //     glsl_fragment_shader,
    // );
    // if (success_fragment == gl.FALSE) {
    //     panicOnShaderCompilationError(std.heap.page_allocator, fragment_shader);
    // }

    // Create shader program
    const shader_program: gl.uint = gl.CreateProgram();
    defer gl.DeleteProgram(shader_program);
    gl.AttachShader(shader_program, vshader.gl_shader_id);
    gl.AttachShader(shader_program, fshader.gl_shader_id);
    gl.LinkProgram(shader_program);

    // handle shader program linking errors
    var success_link: gl.int = undefined;
    gl.GetProgramiv(shader_program, gl.LINK_STATUS, &success_link);
    if (success_link == gl.FALSE) {
        panicOnProgramLinkError(std.heap.page_allocator, shader_program);
    }

    var vao: gl.uint = undefined;
    gl.GenVertexArrays(1, @ptrCast(&vao));
    defer gl.DeleteVertexArrays(1, @ptrCast(&vao));

    gl.BindVertexArray(vao);

    // VAO also stores the EBO, so we can bind it here
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);

    // Bind the VBO to which vertex attributes would apply
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
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
        shader_program,
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

        gl.UseProgram(shader_program);
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
