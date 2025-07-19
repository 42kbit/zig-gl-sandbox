#version 430 core
out vec4 FragColor;

uniform double uTime;

// Name should match the output from vertex shader
in vec3 vertexColor;

void main()
{
  // animate color with time
  float red = abs(vertexColor.x * sin(float(uTime)));
  float green = abs(vertexColor.y * sin(float(uTime)));
  float blue = abs(vertexColor.z * sin(float(uTime)));
  vec3 newColor = vec3(red, green, blue);
  FragColor = vec4(newColor, 1.0);
}