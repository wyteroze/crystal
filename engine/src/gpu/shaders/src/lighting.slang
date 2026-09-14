// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

module lighting;

public struct DirectionalLight {
    public float3 dir;
    public float3 color;
    public float3 ambient;
};

public struct PointLight {
    public float3 pos;
    public float3 color;
    public float intensity;
    public float radius;
}

public struct Light {
    public float3 posOrDir;
    public uint kind; // 0 = point, 1 = directional
    public float3 color;
    public float intensity;
    public float radius;
    public float3 _pad; 
}

public float3 shadeLambert(float3 albedo, float3 n, DirectionalLight light) {
    float3 l = normalize(-light.dir);
    float nDotL = max(dot(n, l), 0.0);
    
    float3 diffuse = albedo * nDotL * light.color;
    float3 ambient = albedo * light.ambient;
    
    return diffuse + ambient;
}

public float3 shadePointLight(float3 albedo, float3 n, float3 worldPos, PointLight light) {
    float3 toLight = light.pos - worldPos;
    float dist = length(toLight);
    float3 l = toLight / max(dist, 0.0001);

    float falloff = saturate(1.0 - (dist / max(light.radius, 0.0001)));
    float attenuation = falloff * falloff;

    float nDotL = max(dot(n, l), 0.0);
    return albedo * light.color * light.intensity * nDotL * attenuation;
}

public float3 shadeLights(
    float3 albedo,
    float3 n,
    float3 worldPos,
    StructuredBuffer<Light> lights,
    StructuredBuffer<uint2> lightGrid,
    StructuredBuffer<uint> lightIndexList,
    uint tileIndex
) {
    float3 result = float3(0, 0, 0);

    uint2 gridEntry = lightGrid[tileIndex];
    uint offset = gridEntry.x;
    uint count = gridEntry.y;

    for (uint i = 0; i < count; i++) {
        uint lightIdx = lightIndexList[offset + i];
        Light light = lights[lightIdx];

        if (light.kind == 0) { // Point light
            PointLight pl;
            pl.pos = light.posOrDir;
            pl.color = light.color;
            pl.intensity = light.intensity;
            pl.radius = light.radius;

            result += shadePointLight(albedo, n, worldPos, pl);
        } else { // Directional light
            DirectionalLight dl;
            dl.dir = -light.posOrDir;
            dl.color = light.color * light.intensity;
            dl.ambient = float3(0, 0, 0);

            result += shadeLambert(albedo, n, dl);
        }
    }

    return result;
}