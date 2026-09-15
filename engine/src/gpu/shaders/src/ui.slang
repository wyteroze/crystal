// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

cbuffer vsParams : register(b0) {
    float4x4 ortho;
    float2 pos;
    float2 size;
    float4 color;
};

struct VSInput {
    float3 pos : ATTRIB0;
    float3 normal : ATTRIB1;
    float2 uv : ATTRIB2;
};

struct VaryingsOut {
    float4 pos : SV_POSITION;
    float4 color: COLOR0;
};

[shader("vertex")]
void vertexMain(in VSInput vsIn, out VaryingsOut vsOut) {
    float2 pixelPos = pos + vsIn.pos.xy * size;
    vsOut.pos = mul(ortho, float4(pixelPos, 0.0, 1.0));
    vsOut.color = color;
}

[shader("fragment")]
float4 fragmentMain(in VaryingsOut psIn) : SV_TARGET {
    return psIn.color;
}