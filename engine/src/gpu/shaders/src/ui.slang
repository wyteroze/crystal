// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

cbuffer vsParams : register(b0) {
    float4x4 ortho;
    float2 pos;
    float2 size;
    float4 color;
    float2 uvPos;
    float2 uvSize;
    uint isText;
    uint isRounded;
    float4 cornerRadii; // top left, top right, bottom left, bottom right
    float4 borderWidths;     // top, bottom, left, right
    float4 borderColor;
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
    float2 localPos : TEXCOORD1;
};

float roundBoxSDF(float2 pos, float2 halfSize, float4 radii) {
    bool isLeft = pos.x < .0;
    bool isTop = pos.y < .0;

    // This just chooses the right radius to use
    float rounding = isLeft
        ? (isTop ? radii.x : radii.z)
        : (isTop ? radii.y : radii.w);

    float2 quadrant = abs(pos) - halfSize + rounding;
    return length(max(quadrant, .0)) + min(max(quadrant.x, quadrant.y), .0) - rounding;
}

float outerEdgeSDF(float2 pos, float2 halfSize, uint isRounded, float4 cornerRadii) {
    if (isRounded != 0) return roundBoxSDF(pos, halfSize, cornerRadii);
    return max(abs(pos.x) - halfSize.x, abs(pos.y) - halfSize.y);
}

void innerBox(
    float2 halfSize,
    float4 borderWidths,
    float4 cornerRadii,
    out float2 innerHalfSize,
    out float2 innerCenter,
    out float4 innerRadii
) {
    innerHalfSize = halfSize - float2(
        (borderWidths.z + borderWidths.w) * .5, // Left + right
        (borderWidths.x + borderWidths.y) * .5
    );
    innerHalfSize = max(innerHalfSize, .0);

    innerCenter = float2(
        (borderWidths.w - borderWidths.z) * .5,
        (borderWidths.y - borderWidths.x) * .5
    );

    innerRadii = max(cornerRadii - float4(
        min(borderWidths.x, borderWidths.z), // Top left
        min(borderWidths.x, borderWidths.w), // Top right
        min(borderWidths.y, borderWidths.z), // Bottom left
        min(borderWidths.y, borderWidths.w) // Bottom right
    ), .0);
}

float borderCoverage(
    float2 localPos,
    float2 halfSize,
    uint isRounded,
    float4 cornerRadii,
    float4 borderwidths,
    float outerDist
) {
    float2 innerHalfSize, innerCenter;
    float4 innerRadii;
    innerBox(halfSize, borderwidths, cornerRadii, innerHalfSize, innerCenter, innerRadii);

    float2 innerLocal = localPos - innerCenter;
    float innerDist = outerEdgeSDF(innerLocal, innerHalfSize, isRounded, innerRadii);

    float bandDist = max(-innerDist, outerDist);
    float aa = fwidth(bandDist) * .5;
    return 1.0 - smoothstep(-aa, aa, bandDist);
}

[shader("vertex")]
void vertexMain(in VSInput vsIn, out VaryingsOut vsOut) {
    float2 pixelPos = pos + vsIn.pos.xy * size;
    vsOut.pos = mul(ortho, float4(pixelPos, .0, 1.0));
    vsOut.color = color;
    vsOut.uv = uvPos + vsIn.uv * uvSize;

    vsOut.localPos = (vsIn.pos.xy - .5) * size;
}

[shader("fragment")]
float4 fragmentMain(in VaryingsOut psIn) : SV_TARGET {
    float4 fillColor;
    
    if (isText != 0) {
        float dist = atlasTexture.Sample(atlasSampler, psIn.uv).r;
        float w = fwidth(dist) * .5;
        float alpha = smoothstep(.5 - w, .5 + w, dist);
        fillColor = float4(psIn.color.rgb, psIn.color.a * alpha);
    } else {
        float4 sampled = atlasTexture.Sample(atlasSampler, psIn.uv);
        fillColor = sampled * psIn.color;
    }

    float2 halfSize = size * .5;
    float outerDist = outerEdgeSDF(psIn.localPos, halfSize, isRounded, cornerRadii);

    float4 resultColor = fillColor;

    if (any(borderWidths > 0.0)) {
        float2 innerHalfSize, innerCenter;
        float4 innerRadii;
        innerBox(halfSize, borderWidths, cornerRadii, innerHalfSize, innerCenter, innerRadii);

        float2 innerLocal = psIn.localPos - innerCenter;
        float innerDist = outerEdgeSDF(innerLocal, innerHalfSize, isRounded, innerRadii);
        float innerAA = fwidth(innerDist) * .5;
        float toBorder = smoothstep(-innerAA, innerAA, innerDist);
        resultColor = lerp(fillColor, borderColor, toBorder * borderColor.a);
    }

    float outerAA = fwidth(outerDist) * .5;
    float outerAlpha = 1.0 - smoothstep(-outerAA, outerAA, outerDist);
    resultColor.a *= outerAlpha;

    return resultColor;
}