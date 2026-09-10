Texture2D    Tex : register(t0);
SamplerState Smp : register(s0);

cbuffer LightParams : register(b1, space1) {
    float3 LightDir;
    float  _pad0;
    float3 LightColor;
    float  _pad1;
    float3 AmbientColor;
    float  _pad2;
};

struct PSInput {
    float4 Position : SV_POSITION;
    float3 Normal   : NORMAL;
    float2 UV       : TEXCOORD0;
    float3 WorldPos : TEXCOORD1;
};

float4 main(in PSInput PSIn) : SV_TARGET {
    float3 albedo = Tex.Sample(Smp, PSIn.UV).rgb;
    float3 N = normalize(PSIn.Normal);
    float3 L = normalize(-LightDir);

    float NdotL = max(dot(N, L), 0.0);
    float3 diffuse = albedo * NdotL * LightColor;
    float3 ambient = albedo * AmbientColor;

    return float4(diffuse + ambient, 1.0);
}