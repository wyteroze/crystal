@vs vs

layout(binding=0) uniform vs_params {
    mat4 model;
    mat4 view;
    mat4 proj;
};

in vec3 position;
in vec3 normal;
in vec2 uv;
out vec3 vnormal;
out vec2 vuv;

void main() {
    gl_Position = proj * view * model * vec4(position, 1.0);
    vnormal = normalize(mat3(model) * normal);
    vuv = uv;
}
@end

@fs fs
layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler smp;
in vec3 vnormal;
in vec2 vuv;
out vec4 frag_color;

void main() {
    frag_color = texture(sampler2D(tex, smp), vuv);
}
@end

@program basic vs fs
