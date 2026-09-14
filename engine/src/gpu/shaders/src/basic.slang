// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

import lighting;

#define TILE_SIZE 16

cbuffer vsParams : register(b0) {
    float4x4 model;
    float4x4 view;
    float4x4 proj;
};

Texture2D texture : register(t0);
SamplerState sampler : register(s0);

cbuffer lightParams : register(b1) {
    float3 ambient;
    uint2 screenSize;
    uint2 tileCount;
};

StructuredBuffer<Light> lights : register(t1);
StructuredBuffer<uint2> lightGrid : register(t2);
StructuredBuffer<uint> lightIndexList : register(t3);

struct VSInput {
    float3 pos : ATTRIB0;
    float3 normal : ATTRIB1;
    float2 uv : ATTRIB2;
};

struct VaryingsOut {
    float4 pos : SV_POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
    float3 worldPos : TEXCOORD1;
};

[shader("vertex")]
void vertexMain(in VSInput vsIn, out VaryingsOut vsOut) {
    float4 worldPos = mul(model, float4(vsIn.pos, 1.0));
    vsOut.pos = mul(proj, mul(view, worldPos));
    vsOut.normal = normalize(mul((float3x3)model, vsIn.normal));
    vsOut.uv = vsIn.uv;
    vsOut.worldPos = worldPos.xyz;
}

[shader("fragment")]
float4 fragmentMain(in VaryingsOut psIn) : SV_TARGET {
    float3 albedo = texture.Sample(sampler, psIn.uv).rgb;
    float3 n = normalize(psIn.normal);

    uint2 tileCoord = uint2(psIn.pos.xy) / TILE_SIZE;
    uint tileIndex = tileCoord.y * tileCount.x + tileCoord.x;

    float3 result = albedo * ambient;
    result += shadeLights(albedo, n, psIn.worldPos, lights, lightGrid, lightIndexList, tileIndex);

    return float4(result, 1.0);
}