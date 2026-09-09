// TODO: When `std.gpu` is more stable (likely in zig 0.17.0), use that for shaders instead of hlsl.
// Since it compiles to SPIR-V we can use SPIRV-Cross (https://github.com/khronosgroup/spirv-cross) 
// for cross graphics API support.

cbuffer VSParams : register(b0) {
    float4x4 Model;
    float4x4 View;
    float4x4 Proj;
};

struct VSInput {
    float3 Position : ATTRIB0;
    float3 Normal : ATTRIB1;
    float2 UV : ATTRIB2;
};

struct VSOutput {
    float4 Position : SV_POSITION;
    float3 Normal : NORMAL;
    float2 UV : TEXCOORD0;
};

void main(in VSInput VSIn, out VSOutput VSOut) {
    float4 worldPos = mul(Model, float4(VSIn.Position, 1.0));
    VSOut.Position = mul(Proj, mul(View, worldPos));
    VSOut.Normal = normalize(mul((float3x3)Model, VSIn.Normal));
    VSOut.UV = VSIn.UV;
}