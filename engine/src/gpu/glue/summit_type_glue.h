// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// Types from zig land. (../types.zig).

typedef struct { void* ptr; } SummitBufferHandle;
typedef struct { void* ptr; } SummitImageHandle;
typedef struct { void* ptr; } SummitRenderTargetHandle;
typedef struct { void* ptr; } SummitDepthTargetHandle;
typedef struct { void* ptr; } SummitShaderHandle;
typedef struct { void* ptr; } SummitPipelineHandle;
typedef struct { void* ptr; } SummitComputePipelineHandle;
typedef struct { void* ptr; } SummitSamplerHandle;
typedef struct { void* ptr; } SummitSwapchainHandle;

typedef enum {
    SUMMIT_BACKEND_OPENGL,
    SUMMIT_BACKEND_DIRECT3D11,
    SUMMIT_BACKEND_DIRECT3D12,
    SUMMIT_BACKEND_VULKAN
} SummitBackend;

typedef enum {
    SUMMIT_RESOURCE_KIND_UNIFORM_BUFFER,
    SUMMIT_RESOURCE_KIND_STORAGE_BUFFER,
    SUMMIT_RESOURCE_KIND_STORAGE_BUFFER_RW,
    SUMMIT_RESOURCE_KIND_TEXTURE,
    SUMMIT_RESOURCE_KIND_SAMPLER
} SummitResourceKind;

typedef enum {
    SUMMIT_SHADER_VISIBILITY_VERTEX,
    SUMMIT_SHADER_VISIBILITY_FRAGMENT,
    SUMMIT_SHADER_VISIBILITY_COMPUTE,
    SUMMIT_SHADER_VISIBILITY_VERTEX_FRAGMENT
} SummitShaderVisibility;

typedef struct {
    const char* name;
    SummitResourceKind kind;
    SummitShaderVisibility visibility;
} SummitResourceDesc;

typedef struct {
    const char* name;
    SummitResourceKind kind;
    void* handle_ptr;
} SummitBoundResource;

typedef enum { 
    SUMMIT_BUFFER_USAGE_DEFAULT,
    SUMMIT_BUFFER_USAGE_IMMUTABLE, 
    SUMMIT_BUFFER_USAGE_DYNAMIC, 
    SUMMIT_BUFFER_USAGE_STREAM 
} SummitBufferUsage;

typedef enum { 
    SUMMIT_BUFFER_TYPE_VERTEX, 
    SUMMIT_BUFFER_TYPE_INDEX,
    SUMMIT_BUFFER_TYPE_UNIFORM,
    SUMMIT_BUFFER_TYPE_STORAGE
} SummitBufferType;

typedef enum { 
    SUMMIT_PIXEL_FORMAT_RGBA8, 
    SUMMIT_PIXEL_FORMAT_RGBA16F, 
    SUMMIT_PIXEL_FORMAT_D24_S8,
    SUMMIT_PIXEL_FORMAT_D32,
    SUMMIT_PIXEL_FORMAT_R8_UNORM,
    SUMMIT_PIXEL_FORMAT_BGRA8
} SummitPixelFormat;

typedef enum { 
    SUMMIT_INDEX_TYPE_NONE, 
    SUMMIT_INDEX_TYPE_UINT16, 
    SUMMIT_INDEX_TYPE_UINT32 
} SummitIndexType;

typedef enum { 
    SUMMIT_WRAP_TYPE_REPEAT, 
    SUMMIT_WRAP_TYPE_CLAMP 
} SummitWrapType;

typedef enum { 
    SUMMIT_FILTER_TYPE_LINEAR, 
    SUMMIT_FILTER_TYPE_NEAREST 
} SummitFilterType;

// Descs from zig land. (../desc.zig)

typedef struct {
    const char* name;
    size_t size;
    size_t stride;
    /// DEFAULT: VERTEX
    SummitBufferType type;
    /// DEFAULT: IMMUTABLE
    SummitBufferUsage usage;
    /// DEFAULT: NULL
    const char* data;
} SummitBufferDesc;

typedef struct {
    /// DEFAULT: REPEAT
    SummitWrapType wrap_u;
    /// DEFAULT: REPEAT
    SummitWrapType wrap_v;
    /// DEFAULT: LINEAR
    SummitFilterType mag_filter;
    /// DEFAULT: LINEAR
    SummitFilterType min_filter;
    /// DEFAULT: LINEAR
    SummitFilterType mip_filter;
} SummitSamplerDesc;

typedef struct {
    const char* name;
    uint32_t width; 
    uint32_t height;
    /// DEFAULT: ARGBF32
    SummitPixelFormat format;
    /// DEFAULT: NULL 
    const char* data;
    bool is_cubemap;
    bool is_render_target;
} SummitImageDesc;

typedef enum {
    FLOAT2,
    FLOAT3,
    FLOAT4,
    UBYTE4_NORM
} SummitVertexFormat;

typedef struct {
    int32_t offset;
    SummitVertexFormat format;
} SummitVertexAttr;

typedef enum {
    NONE,
    FRONT,
    BACK
} SummitCullMode;

typedef struct {
    bool red;
    bool green;
    bool blue;
    bool alpha;
} SummitColorWriteMask;

typedef enum {
    SUMMIT_COMPARISON_FUNC_LESS,
    SUMMIT_COMPARISON_FUNC_LESS_EQUAL,
    SUMMIT_COMPARISON_FUNC_GREATER,
    SUMMIT_COMPARISON_FUNC_GREATER_EQUAL,
    SUMMIT_COMPARISON_FUNC_ALWAYS,
    SUMMIT_COMPARISON_FUNC_NEVER,
    SUMMIT_COMPARISON_FUNC_EQUAL,
    SUMMIT_COMPARISON_FUNC_NOT_EQUAL,
} SummitCompareFunc;

typedef struct {
    const char* name;
    SummitShaderHandle shader;
    const SummitVertexAttr* layout;
    size_t layout_len;
    const SummitResourceDesc* resources;
    size_t resources_len;
    /// DEFAULT: NONE
    SummitIndexType index_type;
    /// DEFAULT: NONE
    SummitCullMode cull_mode;
    /// DEFAULT: FALSE
    bool depth_write;
    SummitColorWriteMask color_write_mask;
    bool alpha_blend_enabled;

    SummitPixelFormat depth_format;
    bool has_depth_format;
    SummitPixelFormat color_format;
    bool has_color_format;
    SummitCompareFunc comparison_func;
} SummitPipelineDesc;

typedef struct {
    const char* name;
    SummitShaderHandle shader;
    const SummitResourceDesc* resources;
    size_t resources_len;
} SummitComputePipelineDesc;

typedef struct {
    uint32_t width; 
    uint32_t height;
    float clear_color[4];
    bool has_clear_color;

    bool has_clear_depth;
    float clear_depth;

    bool has_depth_target;
    SummitDepthTargetHandle depth_target;

    bool has_color_target;
    SummitRenderTargetHandle color_target;
} SummitPassDesc;

typedef struct {
    /// DEFAULT: [NULL, NULL, NULL, NULL]
    SummitBufferHandle vertex_buffers[4];
    /// DEFAULT: NULL
    SummitBufferHandle index_buffer;
    const SummitBoundResource* resources;
    size_t resources_len;
} SummitBindings;

typedef enum {
    SUMMIT_SHADER_STAGE_VERTEX,
    SUMMIT_SHADER_STAGE_FRAGMENT,
    SUMMIT_SHADER_STAGE_COMPUTE
} SummitShaderStage;

typedef struct {
    SummitShaderStage stage;
    const char* name;
    const char* source;
    size_t source_len;
    const char* entrypoint;
} SummitShaderStageDesc;

typedef struct {
    const SummitShaderStageDesc* stages;
    size_t stages_len;
} SummitShaderDesc;

typedef struct {
    void* surface_handle;
    uint32_t size[2];
} SummitSwapchainDesc;