#version 430 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;

out vec3 vertexColor;

uniform double uTime;

void main()
{
    vertexColor = aColor;
    // cast 64 bit float to 32 bit float
    float y_pos = aPos.y + sin(float(uTime)) * 0.2; // animate y position with time
    gl_Position = vec4(aPos.x, y_pos, aPos.z, 1.0);
}
