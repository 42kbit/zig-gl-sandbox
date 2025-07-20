#version 430 core
out vec4 FragColor;

uniform double uTime;

// Name should match the output from vertex shader
in vec3 vertexColor;
in vec2 texCoords;

uniform sampler2D texture0;

void main()
{
  // animate color with time
  float red = abs(vertexColor.x * sin(float(uTime)));
  float green = abs(vertexColor.y * sin(float(uTime)));
  float blue = abs(vertexColor.z * sin(float(uTime)));
  vec4 newColor = vec4(red, green, blue, 0.0);

  FragColor = mix(texture(texture0, texCoords), newColor, 0.2);
}