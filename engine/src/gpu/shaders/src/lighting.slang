module lighting;

public struct DirectionalLight {
    public float3 Direction;
    public float3 Color;
    public float3 Ambient;
};

public float3 shadeLambert(float3 albedo, float3 N, DirectionalLight light) {
    float3 L = normalize(-light.Direction);
    float NdotL = max(dot(N, L), 0.0);
    
    float3 diffuse = albedo * NdotL * light.Color;
    float3 ambient = albedo * light.Ambient;
    
    return diffuse + ambient;
}