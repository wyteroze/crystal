// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

cbuffer vsParams : register(b0) {
    float4x4 ortho;
    float2 pos;
    float2 size;
    float4 color;
    float2 uvPos;
    float2 uvSize;
    uint isText;
};

Texture2D atlasTexture : register(t0);
SamplerState atlasSampler : register(s0);

struct VSInput {
    float3 pos : ATTRIB0;
    float3 normal : ATTRIB1;
    float2 uv : ATTRIB2;
};

struct VaryingsOut {
    float4 pos : SV_POSITION;
    float4 color: COLOR0;
    float2 uv : TEXCOORD0;
};

[shader("vertex")]
void vertexMain(in VSInput vsIn, out VaryingsOut vsOut) {
    float2 pixelPos = pos + vsIn.pos.xy * size;
    vsOut.pos = mul(ortho, float4(pixelPos, 0.0, 1.0));
    vsOut.color = color;
    vsOut.uv = uvPos + vsIn.uv * uvSize;
}

[shader("fragment")]
float4 fragmentMain(in VaryingsOut psIn) : SV_TARGET {
    if (isText != 0) {
        float alpha = atlasTexture.Sample(atlasSampler, psIn.uv).r;
        return float4(psIn.color.rgb, psIn.color.a * alpha);
    } else {
        float4 sampled = atlasTexture.Sample(atlasSampler, psIn.uv);
        return sampled * psIn.color;
    }
}