// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

cbuffer VSParams: register(b0) {
    float4x4 model;
    float4x4 view;
    float4x4 proj;
};

struct VSInput {
    float3 pos : ATTRIB0;
    float3 normal : ATTRIB1;
    float2 uv : ATTRIB2;
};

struct VaryingsOut {
    float4 pos : SV_POSITION;
};

[shader("vertex")]
void vertexMain(in VSInput vsIn, out VaryingsOut vsOut) {
    float4 worldPos = mul(model, float4(vsIn.pos, 1.0));
    vsOut.pos = mul(proj, mul(view, worldPos));
}

[shader("fragment")]
float4 fragmentMain(in VaryingsOut psIn) : SV_TARGET {
    return float4(1, 1, 1, 1);
}