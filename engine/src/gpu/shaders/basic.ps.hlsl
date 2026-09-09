Texture2D    Tex : register(t0);
SamplerState Smp : register(s0);

struct PSInput {
    float4 Position : SV_POSITION;
    float3 Normal   : NORMAL;
    float2 UV       : TEXCOORD0;
};

float4 main(in PSInput PSIn) : SV_TARGET {
    return Tex.Sample(Smp, PSIn.UV);
}