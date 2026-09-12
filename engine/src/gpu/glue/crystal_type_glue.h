// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// Types from zig land. (../types.zig).

typedef struct { void* ptr; } CrystalBufferHandle;
typedef struct { void* ptr; } CrystalImageHandle;
typedef struct { void* ptr; } CrystalShaderHandle;
typedef struct { void* ptr; } CrystalPipelineHandle;
typedef struct { void* ptr; } CrystalComputePipelineHandle;
typedef struct { void* ptr; } CrystalSamplerHandle;

typedef enum {
    CRYSTAL_BACKEND_OPENGL,
    CRYSTAL_BACKEND_DIRECT3D11,
    CRYSTAL_BACKEND_DIRECT3D12,
    CRYSTAL_BACKEND_VULKAN
} CrystalBackend;

typedef enum {
    CRYSTAL_RESOURCE_KIND_UNIFORM_BUFFER,
    CRYSTAL_RESOURCE_KIND_STORAGE_BUFFER,
    CRYSTAL_RESOURCE_KIND_TEXTURE,
    CRYSTAL_RESOURCE_KIND_SAMPLER
} CrystalResourceKind;

typedef enum {
    CRYSTAL_SHADER_VISIBILITY_VERTEX,
    CRYSTAL_SHADER_VISIBILITY_FRAGMENT,
    CRYSTAL_SHADER_VISIBILITY_COMPUTE,
    CRYSTAL_SHADER_VISIBILITY_VERTEX_FRAGMENT
} CrystalShaderVisibility;

typedef struct {
    const char* name;
    CrystalResourceKind kind;
    CrystalShaderVisibility visibility;
} CrystalResourceDesc;

typedef struct {
    const char* name;
    CrystalResourceKind kind;
    void* handle_ptr;
} CrystalBoundResource;

typedef enum { 
    CRYSTAL_BUFFER_USAGE_DEFAULT,
    CRYSTAL_BUFFER_USAGE_IMMUTABLE, 
    CRYSTAL_BUFFER_USAGE_DYNAMIC, 
    CRYSTAL_BUFFER_USAGE_STREAM 
} CrystalBufferUsage;

typedef enum { 
    CRYSTAL_BUFFER_TYPE_VERTEX, 
    CRYSTAL_BUFFER_TYPE_INDEX,
    CRYSTAL_BUFFER_TYPE_UNIFORM,
    CRYSTAL_BUFFER_TYPE_STORAGE
} CrystalBufferType;

typedef enum { 
    CRYSTAL_PIXEL_FORMAT_RGBA8, 
    CRYSTAL_PIXEL_FORMAT_RGBA16F, 
    CRYSTAL_PIXEL_FORMAT_D24_S8,
} CrystalPixelFormat;

typedef enum { 
    CRYSTAL_INDEX_TYPE_NONE, 
    CRYSTAL_INDEX_TYPE_UINT16, 
    CRYSTAL_INDEX_TYPE_UINT32 
} CrystalIndexType;

typedef enum { 
    CRYSTAL_WRAP_TYPE_REPEAT, 
    CRYSTAL_WRAP_TYPE_CLAMP 
} CrystalWrapType;

typedef enum { 
    CRYSTAL_FILTER_TYPE_LINEAR, 
    CRYSTAL_FILTER_TYPE_NEAREST 
} CrystalFilterType;

// Descs from zig land. (../desc.zig)

typedef struct {
    const char* name;
    size_t size;
    size_t stride;
    /// DEFAULT: VERTEX
    CrystalBufferType type;
    /// DEFAULT: IMMUTABLE
    CrystalBufferUsage usage;
    /// DEFAULT: NULL
    const char* data;
} CrystalBufferDesc;

typedef struct {
    /// DEFAULT: REPEAT
    CrystalWrapType wrap_u;
    /// DEFAULT: REPEAT
    CrystalWrapType wrap_v;
    /// DEFAULT: LINEAR
    CrystalFilterType mag_filter;
    /// DEFAULT: LINEAR
    CrystalFilterType min_filter;
    /// DEFAULT: LINEAR
    CrystalFilterType mip_filter;
} CrystalSamplerDesc;

typedef struct {
    const char* name;
    uint32_t width; 
    uint32_t height;
    /// DEFAULT: ARGBF32
    CrystalPixelFormat format;
    /// DEFAULT: NULL 
    const char* data;
} CrystalImageDesc;

typedef enum {
    FLOAT2,
    FLOAT3,
    FLOAT4,
    UBYTE4_NORM
} CrystalVertexFormat;

typedef struct {
    int32_t offset;
    CrystalVertexFormat format;
} CrystalVertexAttr;

typedef enum {
    NONE,
    FRONT,
    BACK
} CrystalCullMode;

typedef struct {
    const char* name;
    CrystalShaderHandle shader;
    const CrystalVertexAttr* layout;
    size_t layout_len;
    const CrystalResourceDesc* resources;
    size_t resources_len;
    /// DEFAULT: NONE
    CrystalIndexType index_type;
    /// DEFAULT: NONE
    CrystalCullMode cull_mode;
    /// DEFAULT: FALSE
    bool depth_write;
} CrystalPipelineDesc;

typedef struct {
    const char* name;
    CrystalShaderHandle shader;
    const CrystalResourceDesc* resources;
    size_t resources_len;
} CrystalComputePipelineDesc;

typedef struct {
    uint32_t width; 
    uint32_t height;
    float clear_color[4];
    bool has_clear_color;

    float clear_depth;
    bool has_clear_depth;
} CrystalPassDesc;

typedef struct {
    /// DEFAULT: [NULL, NULL, NULL, NULL]
    CrystalBufferHandle vertex_buffers[4];
    /// DEFAULT: NULL
    CrystalBufferHandle index_buffer;
    const CrystalBoundResource* resources;
    size_t resources_len;
} CrystalBindings;

typedef enum {
    CRYSTAL_SHADER_STAGE_VERTEX,
    CRYSTAL_SHADER_STAGE_FRAGMENT,
    CRYSTAL_SHADER_STAGE_COMPUTE
} CrystalShaderStage;

typedef struct {
    CrystalShaderStage stage;
    const char* name;
    const char* source;
    size_t source_len;
    const char* entrypoint;
} CrystalShaderStageDesc;

typedef struct {
    const CrystalShaderStageDesc* stages;
    size_t stages_len;
} CrystalShaderDesc;