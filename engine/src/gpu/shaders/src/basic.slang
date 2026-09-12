import lighting;

cbuffer VSParams : register(b0) {
    float4x4 Model;
    float4x4 View;
    float4x4 Proj;
};

Texture2D    Tex : register(t0);
SamplerState Smp : register(s0);

cbuffer LightParams : register(b1, space1) {
    DirectionalLight Light;
};

struct VSInput {
    float3 Position : ATTRIB0;
    float3 Normal : ATTRIB1;
    float2 UV : ATTRIB2;
};

struct VaryingsOut {
    float4 Position : SV_POSITION;
    float3 Normal : NORMAL;
    float2 UV : TEXCOORD0;
    float3 WorldPos : TEXCOORD1;
};

[shader("vertex")]
void vertexMain(in VSInput VSIn, out VaryingsOut VSOut) {
    float4 worldPos = mul(Model, float4(VSIn.Position, 1.0));
    VSOut.Position = mul(Proj, mul(View, worldPos));
    VSOut.Normal = normalize(mul((float3x3)Model, VSIn.Normal));
    VSOut.UV = VSIn.UV;
    VSOut.WorldPos = worldPos.xyz;
}

[shader("fragment")]
float4 fragmentMain(in VaryingsOut PSIn) : SV_TARGET {
    float3 albedo = Tex.Sample(Smp, PSIn.UV).rgb;
    float3 N = normalize(PSIn.Normal);
    float3 result = shadeLambert(albedo, N, Light);
    
    return float4(result, 1.0);
}