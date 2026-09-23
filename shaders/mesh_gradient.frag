#version 460 core
#include <flutter/runtime_effect.glsl>

out vec4 fragColor;
// TODO: mesh
void main() {
    vec2 uv = FlutterFragCoord().xy;
    fragColor = vec4(uv, 0.0, 1.0);
}