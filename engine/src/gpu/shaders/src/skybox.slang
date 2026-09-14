// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

cbuffer vsParams : register(b0) {
    float4x4 invViewProj;
};

TextureCube skyboxTexture : register(t0);
SamplerState skyboxSampler : register(s0);

struct VaryingsOut {
    float4 pos : SV_POSITION;
    float3 viewDir : TEXCOORD0;
};

[shader("vertex")]
void vertexMain(in uint vertexId : SV_VertexID, out VaryingsOut vsOut) {
    float2 uv = float2((vertexId << 1) & 2, vertexId & 2);
    float2 clipPos = uv * 2.0 - 1.0;

    vsOut.pos = float4(clipPos, 1.0, 1.0);

    float4 worldPos = mul(invViewProj, float4(clipPos, 1.0, 1.0));
    vsOut.viewDir = worldPos.xyz / worldPos.w;
}

[shader("fragment")]
float4 fragmentMain(in VaryingsOut psIn) : SV_TARGET {
    float3 dir = normalize(psIn.viewDir);
    return skyboxTexture.Sample(skyboxSampler, dir);
}