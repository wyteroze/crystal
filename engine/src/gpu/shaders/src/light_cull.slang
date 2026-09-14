// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

import lighting;

#define TILE_SIZE 16
#define MAX_LIGHTS_PER_TILE 256
#define NDC_DEPTH_IS_ZERO_TO_ONE 1

cbuffer cullParams : register(b0) {
    float4x4 invProj;
    float4x4 view;
    uint2 screenSize;
    uint2 tileCount;
    uint lightCount;
};

Texture2D depthTexture : register(t0);
StructuredBuffer<Light> lights : register(t1);

RWStructuredBuffer<uint2> lightGrid : register(u0);
RWStructuredBuffer<uint> lightIndexList : register(u1);

groupshared uint groupMinDepthUint;
groupshared uint groupMaxDepthUint;
groupshared uint groupLightCount;
groupshared uint groupLightIndices[MAX_LIGHTS_PER_TILE];
groupshared float4 groupFrustumPlanes[4];

float3 viewPosFromDepth(float2 uv, float depth) {
#if NDC_DEPTH_IS_ZERO_TO_ONE
    float ndcZ = depth;
#else
    float ndcZ = depth * 2.0 - 1.0;
#endif
    float4 clip = float4(uv * 2.0 - 1.0, ndcZ, 1.0);
    clip.y = -clip.y;

    float4 viewPos = mul(invProj, clip);
    return viewPos.xyz / viewPos.w;
}

[shader("compute")]
[numthreads(TILE_SIZE, TILE_SIZE, 1)]
void computeMain(
    uint3 groupId : SV_GroupID,
    uint3 groupThreadId : SV_GroupThreadID,
    uint3 dispatchId : SV_DispatchThreadID
) {
    uint tileIndex = groupId.y * tileCount.x + groupId.x;
    uint threadIndexInGroup = groupThreadId.y * TILE_SIZE + groupThreadId.x;

    if (threadIndexInGroup == 0) {
        groupMinDepthUint = 0xFFFFFFFF;
        groupMaxDepthUint = 0;
        groupLightCount = 0;
    }
    GroupMemoryBarrierWithGroupSync();

    uint2 pixelCoord = dispatchId.xy;
    float depth = 1.0;
    if (pixelCoord.x < screenSize.x && pixelCoord.y < screenSize.y) {
        depth = depthTexture.Load(int3(pixelCoord, 0)).r;
    }

    uint depthUint = asuint(depth);
    if (depth < 1.0) {
        InterlockedMin(groupMinDepthUint, depthUint);
        InterlockedMax(groupMaxDepthUint, depthUint);
    }
    GroupMemoryBarrierWithGroupSync();

    float minDepth = asfloat(groupMinDepthUint);
    float maxDepth = asfloat(groupMaxDepthUint);
    if (groupMinDepthUint > groupMaxDepthUint) {
        // Nothing rendered into this tile
        minDepth = 0.0;
        maxDepth = 1.0;
    }

    // If we're the first thread, we build the frustrum planes and view depth bounds
    if (threadIndexInGroup == 0) {
        float2 tileMinUv = float2(groupId.xy) * TILE_SIZE / float2(screenSize);
        float2 tileMaxUv = float2(groupId.xy + 1) * TILE_SIZE / float2(screenSize);

        float3 corners[4];
        corners[0] = viewPosFromDepth(float2(tileMinUv.x, tileMinUv.y), 0.0);
        corners[1] = viewPosFromDepth(float2(tileMaxUv.x, tileMinUv.y), 0.0);
        corners[2] = viewPosFromDepth(float2(tileMinUv.x, tileMaxUv.y), 0.0);
        corners[3] = viewPosFromDepth(float2(tileMaxUv.x, tileMaxUv.y), 0.0);

        groupFrustumPlanes[0] = float4(normalize(cross(corners[2], corners[0])), 0.0); // Left
        groupFrustumPlanes[1] = float4(normalize(cross(corners[1], corners[3])), 0.0); // Right
        groupFrustumPlanes[2] = float4(normalize(cross(corners[0], corners[1])), 0.0); // Top
        groupFrustumPlanes[3] = float4(normalize(cross(corners[3], corners[2])), 0.0); // Bottom

        float2 tileCenterUv = (float2(groupId.xy) + 0.5) * TILE_SIZE / float2(screenSize);
        float minViewZ = viewPosFromDepth(tileCenterUv, minDepth).z;
        float maxViewZ = viewPosFromDepth(tileCenterUv, maxDepth).z;
        groupFrustumPlanes[3].w = max(minViewZ, maxViewZ);
        groupFrustumPlanes[2].w = min(minViewZ, maxViewZ);
    }
    GroupMemoryBarrierWithGroupSync();

    float tileNearZ = groupFrustumPlanes[3].w;
    float tileFarZ = groupFrustumPlanes[2].w;

    uint threadsPerGroup = TILE_SIZE * TILE_SIZE;
        for (uint i = threadIndexInGroup; i < lightCount; i += threadsPerGroup) {
        Light light = lights[i];

        if (light.kind == 1) { // Directional light (they always affect every tile)
            uint slot;
            InterlockedAdd(groupLightCount, 1, slot);
            if (slot < MAX_LIGHTS_PER_TILE) groupLightIndices[slot] = i;
            continue;
        }

        float3 viewPos = mul(view, float4(light.posOrDir, 1.0)).xyz;
        float radius = light.radius;

        bool inside = true;
        for (uint p = 0; p < 4; p++) {
            if (dot(groupFrustumPlanes[p].xyz, viewPos) < -radius) {
                inside = false;
                break;
            }
        }

        if (inside && viewPos.z + radius >= tileFarZ && viewPos.z - radius <= tileNearZ) {
            uint slot;
            InterlockedAdd(groupLightCount, 1, slot);
            if (slot < MAX_LIGHTS_PER_TILE) groupLightIndices[slot] = i;
        }
    }
    GroupMemoryBarrierWithGroupSync();

    if (threadIndexInGroup == 0) {
        uint count = min(groupLightCount, MAX_LIGHTS_PER_TILE);
        uint offset = tileIndex * MAX_LIGHTS_PER_TILE;
        lightGrid[tileIndex] = uint2(offset, count);
    }
    GroupMemoryBarrierWithGroupSync();

    uint clampedCount = min(groupLightCount, MAX_LIGHTS_PER_TILE);
    for (uint j = threadIndexInGroup; j < clampedCount; j += threadsPerGroup) {
        uint offset = tileIndex * MAX_LIGHTS_PER_TILE;
        lightIndexList[offset + j] = groupLightIndices[j];
    }
}