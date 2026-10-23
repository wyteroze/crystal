// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

#include "diligent.h"
#include "DiligentCore/Graphics/GraphicsEngine/interface/Buffer.h"
#include "DiligentCore/Graphics/GraphicsEngine/interface/DeviceContext.h"
#include "DiligentCore/Graphics/GraphicsEngine/interface/GraphicsTypes.h"
#include "DiligentCore/Graphics/GraphicsEngine/interface/InputLayout.h"
#include "DiligentCore/Graphics/GraphicsEngine/interface/PipelineState.h"
#include "DiligentCore/Graphics/GraphicsEngine/interface/RenderDevice.h"
#include "DiligentCore/Graphics/GraphicsEngine/interface/Sampler.h"
#include "DiligentCore/Graphics/GraphicsEngine/interface/Shader.h"
#include "DiligentCore/Graphics/GraphicsEngine/interface/ShaderResourceBinding.h"
#include "DiligentCore/Graphics/GraphicsEngine/interface/SwapChain.h"
#include "DiligentCore/Graphics/GraphicsEngine/interface/Texture.h"
#include "DiligentCore/Graphics/GraphicsEngine/interface/TextureView.h"
#include "DiligentCore/Graphics/GraphicsTools/interface/MapHelper.hpp"
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <vector>

#ifdef SUMMIT_D3D11_BACKEND
#include "DiligentCore/Graphics/GraphicsEngineD3D11/interface/EngineFactoryD3D11.h"
#elif SUMMIT_D3D12_BACKEND
#include "DiligentCore/Graphics/GraphicsEngineD3D12/interface/EngineFactoryD3D12.h"
#elif SUMMIT_OPENGL_BACKEND
#include "DiligentCore/Graphics/GraphicsEngineOpenGL/interface/EngineFactoryOpenGL.h"
#elif SUMMIT_VULKAN_BACKEND
#include "DiligentCore/Graphics/GraphicsEngineVulkan/interface/EngineFactoryVk.h"
#endif


#ifdef PLATFORM_MACOS
#include "DiligentCore/Platforms/Apple/interface/MacOSNativeWindow.h"
#define OS_WINDOW MacOSNativeWindow
#elif PLATFORM_WIN32
#include "DiligentCore/Platforms/Win32/interface/Win32NativeWindow.h"
#define OS_WINDOW Win32NativeWindow
#endif

using namespace Diligent;
struct SummitDiligentDeviceContext {
    IRenderDevice* device;
    IDeviceContext* context;
    IEngineFactory* factory;
};

struct SummitDiligentShader {
    IShader* vs = nullptr;
    IShader* ps = nullptr;
    IShader* cs = nullptr;
};

struct SummitDiligentPipeline {
    IPipelineState* pso;
    IShaderResourceBinding* srb;
    VALUE_TYPE index_type;
    bool has_index_buffer = false;
};

struct SummitDiligentComputePipeline {
    IPipelineState* pso;
    IShaderResourceBinding* srb;
};

// Helpers

static FILTER_TYPE summitFilterToDiligent(SummitFilterType filter) {
    switch (filter) {
        case SUMMIT_FILTER_TYPE_LINEAR:
            return FILTER_TYPE_LINEAR;
        case SUMMIT_FILTER_TYPE_NEAREST:
            return FILTER_TYPE_POINT;
    }
}

static TEXTURE_ADDRESS_MODE summitWrapToDiligent(SummitWrapType wrap) {
    switch (wrap) {
        case SUMMIT_WRAP_TYPE_CLAMP:
            return TEXTURE_ADDRESS_CLAMP;
        case SUMMIT_WRAP_TYPE_REPEAT:
            return TEXTURE_ADDRESS_WRAP;
    }
}

static SHADER_TYPE summitShaderStageToDiligent(SummitShaderStage stage) {
    switch (stage) {
        case SUMMIT_SHADER_STAGE_VERTEX:
            return SHADER_TYPE_VERTEX;
        case SUMMIT_SHADER_STAGE_FRAGMENT:
            return SHADER_TYPE_PIXEL;
        case SUMMIT_SHADER_STAGE_COMPUTE:
            return SHADER_TYPE_COMPUTE;
    }
}

static SHADER_TYPE summitVisibilityToDiligent(SummitShaderVisibility visibility) {
    switch (visibility) {
        case SUMMIT_SHADER_VISIBILITY_VERTEX:
            return SHADER_TYPE_VERTEX;
        case SUMMIT_SHADER_VISIBILITY_FRAGMENT:
            return SHADER_TYPE_PIXEL;
        case SUMMIT_SHADER_VISIBILITY_COMPUTE:
            return SHADER_TYPE_COMPUTE;
        case SUMMIT_SHADER_VISIBILITY_VERTEX_FRAGMENT:
            return SHADER_TYPE_VERTEX | SHADER_TYPE_PIXEL;
    }
}

static TEXTURE_FORMAT summitPixelFormatToDiligent(SummitPixelFormat format) {
    switch (format) {
        case SUMMIT_PIXEL_FORMAT_RGBA8:
            return TEX_FORMAT_RGBA8_UNORM_SRGB;
        case SUMMIT_PIXEL_FORMAT_RGBA16F:
            return TEX_FORMAT_RGBA16_FLOAT;
        case SUMMIT_PIXEL_FORMAT_D24_S8:
            return TEX_FORMAT_D24_UNORM_S8_UINT;
        case SUMMIT_PIXEL_FORMAT_D32:
            return TEX_FORMAT_D32_FLOAT;
        case SUMMIT_PIXEL_FORMAT_R8_UNORM:
            return TEX_FORMAT_R8_UNORM;
        case SUMMIT_PIXEL_FORMAT_BGRA8:
            return TEX_FORMAT_BGRA8_UNORM_SRGB;
    }
}

static COMPARISON_FUNCTION summitComparisonFuncToDiligent(SummitCompareFunc func) {
    switch (func) {
        case SUMMIT_COMPARISON_FUNC_LESS:
            return COMPARISON_FUNC_LESS;
        case SUMMIT_COMPARISON_FUNC_LESS_EQUAL:
            return COMPARISON_FUNC_LESS_EQUAL;
        case SUMMIT_COMPARISON_FUNC_GREATER:
            return COMPARISON_FUNC_GREATER;
        case SUMMIT_COMPARISON_FUNC_GREATER_EQUAL:
            return COMPARISON_FUNC_GREATER_EQUAL;
        case SUMMIT_COMPARISON_FUNC_ALWAYS:
            return COMPARISON_FUNC_ALWAYS;
        case SUMMIT_COMPARISON_FUNC_NEVER:
            return COMPARISON_FUNC_NEVER;
        case SUMMIT_COMPARISON_FUNC_EQUAL:
            return COMPARISON_FUNC_EQUAL;
        case SUMMIT_COMPARISON_FUNC_NOT_EQUAL:
            return COMPARISON_FUNC_NOT_EQUAL;
    }
}

static std::vector<ShaderResourceVariableDesc> buildResourceVars(const SummitResourceDesc* resources, size_t count) {
    std::vector<ShaderResourceVariableDesc> vars;
    vars.reserve(count);
    for (size_t i = 0; i < count; i++) {
        vars.push_back({
            summitVisibilityToDiligent(resources[i].visibility), 
            resources[i].name, 
            SHADER_RESOURCE_VARIABLE_TYPE_DYNAMIC
        });
    }

    return vars;
}

// Implementation

SummitDiligentDeviceHandle diligent_init() {
    SetDebugMessageCallback([](DEBUG_MESSAGE_SEVERITY sev, const Char* msg, const Char*, const Char*, int) {
        std::cerr << "[Diligent] " << msg << "\n";
    });

    SummitDiligentDeviceHandle handle = new SummitDiligentDeviceContext();

    IRenderDevice* device;
    IDeviceContext* context;
    IEngineFactory* factory;

#ifdef SUMMIT_D3D11_BACKEND
    EngineD3D11CreateInfo EngineCI;
    auto *factoryD3D11 = LoadAndGetEngineFactoryD3D11();
    factoryD3D11->CreateDeviceAndContextsD3D11(EngineCI, &device, &context);
    factory = factoryD3D11;
#elif SUMMIT_D3D12_BACKEND
    EngineD3D12CreateInfo EngineCI;
    auto *factoryD3D12 = LoadAndGetEngineFactoryD3D12();
    factoryD3D12->CreateDeviceAndContextsD3D12(EngineCI, &device, &context);
    factory = factoryD3D12;
#elif SUMMIT_OPENGL_BACKEND
    auto* factoryOpenGL = LoadAndGetEngineFactoryOpenGL();

    EngineGLCreateInfo EngineCI;
    EngineCI.Window = OS_WINDOW{surfaceHandle};

    factoryOpenGL->CreateDeviceAndSwapChainGL(EngineCI, &device, &context, SCDesc, &swapchain);
    factory = factoryOpenGL;
#elif SUMMIT_VULKAN_BACKEND
    EngineVkCreateInfo EngineCI;
    EngineCI.EnableValidation = true;
    EngineCI.SetValidationLevel(VALIDATION_LEVEL_2);

    auto* factoryVk = LoadAndGetEngineFactoryVk();
    factoryVk->CreateDeviceAndContextsVk(EngineCI, &device, &context);
    factory = factoryVk;
#endif

    handle->device = device;
    handle->context = context;
    handle->factory = factory;

    return handle;
}

void diligent_deinit(SummitDiligentDeviceHandle handle) {
    handle->context->Flush();
    handle->context->WaitForIdle();
    handle->context->Release();
    handle->device->Release();
    delete handle;
}

SummitBufferHandle diligent_create_buffer(SummitDiligentDeviceHandle handle, SummitBufferDesc desc) {
    BufferDesc BufDesc;
    BufDesc.Name = desc.name;
    switch (desc.type) {
        case SUMMIT_BUFFER_TYPE_INDEX:
            BufDesc.BindFlags = BIND_INDEX_BUFFER;
            break;
        case SUMMIT_BUFFER_TYPE_VERTEX:
            BufDesc.BindFlags = BIND_VERTEX_BUFFER;
            break;
        case SUMMIT_BUFFER_TYPE_UNIFORM:
            BufDesc.BindFlags = BIND_UNIFORM_BUFFER;
            break;
        case SUMMIT_BUFFER_TYPE_STORAGE:
            BufDesc.BindFlags = BIND_SHADER_RESOURCE | BIND_UNORDERED_ACCESS;
            BufDesc.Mode = BUFFER_MODE_STRUCTURED;
            if (desc.stride == 0) {
                std::cerr << "Summit C++ [FATAL]: Invalid stride for buffer of type SUMMIT_BUFFER_TYPE_STORAGE";
                exit(EXIT_FAILURE);
            }
            BufDesc.ElementByteStride = desc.stride;

            break;
    }
    switch (desc.usage) {
        case SUMMIT_BUFFER_USAGE_DEFAULT:
            BufDesc.Usage = USAGE_DEFAULT;
            break;
        case SUMMIT_BUFFER_USAGE_IMMUTABLE:
            BufDesc.Usage = USAGE_IMMUTABLE;
            break;
        case SUMMIT_BUFFER_USAGE_DYNAMIC:
            BufDesc.Usage = USAGE_DYNAMIC;
            BufDesc.CPUAccessFlags = CPU_ACCESS_WRITE;
            break;
        case SUMMIT_BUFFER_USAGE_STREAM:
            BufDesc.Usage = USAGE_STAGING;
            BufDesc.CPUAccessFlags = CPU_ACCESS_READ;
            break;
    }
    BufDesc.Size = desc.size;

    IBuffer* buffer = nullptr;
    BufferData data;
    data.pData = desc.data;
    data.DataSize = desc.size;

    handle->device->CreateBuffer(BufDesc, &data, &buffer);

    return { .ptr = buffer };
}

void diligent_update_buffer(SummitDiligentDeviceHandle handle, SummitBufferHandle bufH, const char* data, size_t size) {
    auto buffer = static_cast<IBuffer*>(bufH.ptr);
    auto desc = buffer->GetDesc();

    switch (desc.Usage) {
        case USAGE_DEFAULT: {
            handle->context->UpdateBuffer(buffer, 0, size, data, RESOURCE_STATE_TRANSITION_MODE_TRANSITION);
            break;
        }
        case USAGE_DYNAMIC:
        case USAGE_STAGING: {
            MapHelper<uint8_t> MappedData(handle->context, buffer, MAP_WRITE, MAP_FLAG_DISCARD);
            std::memcpy(MappedData, data, size);
            break;
        }
        case USAGE_IMMUTABLE:
            std::cerr << "Summit C++: Unable to update immutable buffer\n";
            return;
        default: 
            std::cerr << "Summit C++ [FATAL]: Unknown buffer usage type\n";
            exit(EXIT_FAILURE); 
    }
}

void diligent_destroy_buffer(SummitDiligentDeviceHandle handle, SummitBufferHandle bufH) {
    auto buffer = static_cast<IBuffer*>(bufH.ptr);
    buffer->Release();
}

SummitSamplerHandle diligent_create_sampler(SummitDiligentDeviceHandle handle, SummitSamplerDesc desc) {
    SamplerDesc SamDesc;

    SamDesc.MinFilter = summitFilterToDiligent(desc.min_filter);
    SamDesc.MagFilter = summitFilterToDiligent(desc.mag_filter);
    SamDesc.MipFilter = summitFilterToDiligent(desc.mip_filter);

    SamDesc.AddressU = summitWrapToDiligent(desc.wrap_u);
    SamDesc.AddressV = summitWrapToDiligent(desc.wrap_v);

    ISampler* sampler = nullptr;
    handle->device->CreateSampler(SamDesc, &sampler);

    return { .ptr = sampler };
}

void diligent_destroy_sampler(SummitDiligentDeviceHandle handle, SummitSamplerHandle samH) {
    auto sampler = static_cast<ISampler*>(samH.ptr);
    sampler->Release();
}

SummitImageHandle diligent_create_image(SummitDiligentDeviceHandle handle, SummitImageDesc desc) {
    TextureDesc TexDesc;
    TexDesc.Name = desc.name;
    TexDesc.Type = desc.is_cubemap ? RESOURCE_DIM_TEX_CUBE : RESOURCE_DIM_TEX_2D;
    TexDesc.ArraySize = desc.is_cubemap ? 6 : 1;
    TexDesc.Width = desc.width;
    TexDesc.Height = desc.height;
    TexDesc.MipLevels = 1;
    TexDesc.Format = summitPixelFormatToDiligent(desc.format);
    
    std::cerr << "is_cubemap=" << desc.is_cubemap << " width=" << desc.width << "\n";

    size_t stride = 0;
    bool isDepth = false;
    switch (desc.format) {
        case SUMMIT_PIXEL_FORMAT_BGRA8:
        case SUMMIT_PIXEL_FORMAT_RGBA8:
            TexDesc.BindFlags = BIND_SHADER_RESOURCE;
            stride = 4;
            
            break;
        case SUMMIT_PIXEL_FORMAT_RGBA16F:
            TexDesc.BindFlags = BIND_SHADER_RESOURCE;
            stride = 8;

            break;
        case SUMMIT_PIXEL_FORMAT_D24_S8:
            TexDesc.BindFlags = BIND_DEPTH_STENCIL | BIND_SHADER_RESOURCE;
            stride = 4;
            isDepth = true;

            break;
        case SUMMIT_PIXEL_FORMAT_D32:
            TexDesc.BindFlags = BIND_DEPTH_STENCIL | BIND_SHADER_RESOURCE;
            stride = 4;
            isDepth = true;
            break;
        case SUMMIT_PIXEL_FORMAT_R8_UNORM:
            TexDesc.BindFlags = BIND_SHADER_RESOURCE;
            stride = 1;
            break;
    }

    if (desc.is_render_target) TexDesc.BindFlags |= BIND_RENDER_TARGET;

    ITexture* tex = nullptr;
    if (isDepth || desc.is_render_target) {
        TexDesc.Usage = USAGE_DEFAULT;
        handle->device->CreateTexture(TexDesc, nullptr, &tex);
    } else if (desc.is_cubemap) {
        TexDesc.Usage = USAGE_IMMUTABLE;

        TextureSubResData subres[6];
        const size_t faceSize = desc.width * desc.height * stride;
        for (uint32_t face = 0; face < 6; face++) {
            subres[face].pData = static_cast<const char*>(desc.data) + face * faceSize;
            subres[face].Stride = desc.width * stride;
        }

        TextureData data;
        data.pSubResources = subres;
        data.NumSubresources = 6;

        handle->device->CreateTexture(TexDesc, &data, &tex);
    } else {
        TexDesc.Usage = USAGE_IMMUTABLE;

        TextureSubResData subres;
        subres.pData = desc.data;
        subres.Stride = desc.width * stride;
        
        TextureData data;
        data.pSubResources = &subres;
        data.NumSubresources = 1;
        
        handle->device->CreateTexture(TexDesc, &data, &tex);
    }

    if (!tex) {
        std::cerr << "Summit C++ [FATAL]: Texture creation failed for '" << desc.name << "'\n";
        exit(EXIT_FAILURE);
    }
    
    return { .ptr = tex };
}

void diligent_destroy_image(SummitDiligentDeviceHandle handle, SummitImageHandle imgH) {
    auto image = static_cast<ITexture*>(imgH.ptr);
    image->Release();
}

SummitPipelineHandle diligent_create_pipeline(SummitDiligentDeviceHandle handle, SummitPipelineDesc desc) {
    auto* shaderSet = reinterpret_cast<SummitDiligentShader*>(desc.shader.ptr);

    GraphicsPipelineStateCreateInfo psoCreateInfo;
    auto& psoDesc = psoCreateInfo.PSODesc;
    auto& graphicsPipeline = psoCreateInfo.GraphicsPipeline;

    psoDesc.Name = desc.name;
    psoDesc.PipelineType = PIPELINE_TYPE_GRAPHICS;

    switch (desc.cull_mode) {
        case NONE:
            graphicsPipeline.RasterizerDesc.CullMode = CULL_MODE_NONE;
            break;
        case FRONT:
            graphicsPipeline.RasterizerDesc.CullMode = CULL_MODE_FRONT;
            break;
        case BACK:
            graphicsPipeline.RasterizerDesc.CullMode = CULL_MODE_BACK;
            break;
    }

    auto writeMask = COLOR_MASK_NONE;
    if (desc.color_write_mask.red) writeMask |= COLOR_MASK_RED;
    if (desc.color_write_mask.green) writeMask |= COLOR_MASK_GREEN;
    if (desc.color_write_mask.blue) writeMask |= COLOR_MASK_BLUE;
    if (desc.color_write_mask.alpha) writeMask |= COLOR_MASK_ALPHA;
    graphicsPipeline.BlendDesc.RenderTargets[0].RenderTargetWriteMask = writeMask;
    graphicsPipeline.DepthStencilDesc.DepthFunc = summitComparisonFuncToDiligent(desc.comparison_func);

    if (desc.has_depth_format) {
        graphicsPipeline.DSVFormat = summitPixelFormatToDiligent(desc.depth_format);
        graphicsPipeline.DepthStencilDesc.DepthEnable = desc.depth_write;
        graphicsPipeline.DepthStencilDesc.DepthWriteEnable = desc.depth_write;
    } else {
        graphicsPipeline.DSVFormat = TEX_FORMAT_UNKNOWN;
        graphicsPipeline.DepthStencilDesc.DepthEnable = false;
        graphicsPipeline.DepthStencilDesc.DepthEnable = false;
    }

    if (desc.has_color_format) {
        graphicsPipeline.NumRenderTargets = 1;
        graphicsPipeline.RTVFormats[0] = summitPixelFormatToDiligent(desc.color_format);
    } else {
        graphicsPipeline.NumRenderTargets = 0;
        graphicsPipeline.RTVFormats[0] = TEX_FORMAT_UNKNOWN;
    }

    if (desc.alpha_blend_enabled) {
        auto& rt0 = psoCreateInfo.GraphicsPipeline.BlendDesc.RenderTargets[0];
        rt0.BlendEnable = desc.alpha_blend_enabled;
        rt0.SrcBlend = BLEND_FACTOR_SRC_ALPHA;
        rt0.DestBlend = BLEND_FACTOR_INV_SRC_ALPHA;
        rt0.SrcBlendAlpha = BLEND_FACTOR_SRC_ALPHA;
        rt0.DestBlendAlpha = BLEND_FACTOR_INV_SRC_ALPHA;
    }

    std::vector<LayoutElement> layoutElems;
    layoutElems.reserve(desc.layout_len);
    for (size_t i = 0; i < desc.layout_len; i++) {
        const SummitVertexAttr& attr = desc.layout[i];
        Uint8 numComponents = 0;
        switch (attr.format) {
            case FLOAT2:
                numComponents = 2;
                break;
            case FLOAT3:
                numComponents = 3;
                break;
            case FLOAT4:
            case UBYTE4_NORM:
                numComponents = 4;
                break;
        }
        VALUE_TYPE valueType = attr.format == UBYTE4_NORM ? VT_UINT8 : VT_FLOAT32;
        bool isNormalized = attr.format == UBYTE4_NORM;

        layoutElems.push_back(LayoutElement{
            static_cast<uint32_t>(i), 0, numComponents, valueType, isNormalized,
            static_cast<uint32_t>(attr.offset), LAYOUT_ELEMENT_AUTO_STRIDE
        });
    }

    graphicsPipeline.InputLayout.LayoutElements = layoutElems.data();
    graphicsPipeline.InputLayout.NumElements = static_cast<uint32_t>(layoutElems.size());

    psoCreateInfo.pVS = shaderSet->vs;
    psoCreateInfo.pPS = shaderSet->ps;

    auto vars = buildResourceVars(desc.resources, desc.resources_len);
    psoCreateInfo.PSODesc.ResourceLayout.Variables = vars.data();
    psoCreateInfo.PSODesc.ResourceLayout.NumVariables = static_cast<uint32_t>(vars.size());

    IPipelineState* pso = nullptr;
    handle->device->CreateGraphicsPipelineState(psoCreateInfo, &pso);
    if (!pso) {
        std::cerr << "Summit C++ [FATAL]: Pipeline creation failed for '" << desc.name << "'\n";
        exit(EXIT_FAILURE);
    }

    auto* pipeline = new SummitDiligentPipeline;
    pipeline->pso = pso;
    switch (desc.index_type) {
        case SUMMIT_INDEX_TYPE_UINT16:
            pipeline->index_type = VT_INT16;
            break;
        case SUMMIT_INDEX_TYPE_UINT32:
            pipeline->index_type = VT_UINT32;
            break;
        case SUMMIT_INDEX_TYPE_NONE:
            std::cerr << "Summit C++ [FATAL]: Creating a pipeline with index type of SUMMIT_INDEX_TYPE_NONE is forbidden\n";
            exit(EXIT_FAILURE);
    }
    pso->CreateShaderResourceBinding(&pipeline->srb, true);

    return { .ptr = pipeline };
}

void diligent_destroy_pipeline(SummitDiligentDeviceHandle handle, SummitPipelineHandle pipeH) {
    auto pipeline = static_cast<SummitDiligentPipeline*>(pipeH.ptr);
    pipeline->srb->Release();
    pipeline->pso->Release();
    delete pipeline;
}

void diligent_apply_pipeline(SummitDiligentDeviceHandle handle, SummitPipelineHandle pipeH) {
    auto pipeline = static_cast<SummitDiligentPipeline*>(pipeH.ptr);
    handle->context->SetPipelineState(pipeline->pso);
}

void diligent_draw_pipeline(SummitDiligentDeviceHandle handle, SummitShaderHandle pipeH, uint32_t base, uint32_t count, uint32_t instances) {
    auto pipeline = static_cast<SummitDiligentPipeline*>(pipeH.ptr);

    if (pipeline->has_index_buffer) {
        DrawIndexedAttribs drawAttrs;
        
        drawAttrs.IndexType = pipeline->index_type;
        drawAttrs.NumIndices = count;
        drawAttrs.FirstIndexLocation = base;
        drawAttrs.NumInstances = instances;
        drawAttrs.Flags = DRAW_FLAG_VERIFY_ALL;
    
        handle->context->DrawIndexed(drawAttrs);
    } else {
        DrawAttribs drawAttrs;
        drawAttrs.NumVertices = count;
        drawAttrs.StartVertexLocation = base;
        drawAttrs.NumInstances = instances;
        drawAttrs.Flags = DRAW_FLAG_VERIFY_ALL;
        handle->context->Draw(drawAttrs);
    }
}

void diligent_pipeline_apply_bindings(SummitDiligentDeviceHandle handle, SummitPipelineHandle pipeH, SummitBindings bindings) {
    auto pipeline = static_cast<SummitDiligentPipeline*>(pipeH.ptr);

    IBuffer* vbufs[4] = {};
    Uint64 offsets[4] = {};
    Uint32 numBuffers = 0;
    for (int i = 0; i < 4; i++) {
        if (bindings.vertex_buffers[i].ptr != nullptr) {
            vbufs[numBuffers] = reinterpret_cast<IBuffer*>(bindings.vertex_buffers[i].ptr);
            numBuffers++;
        }
    }

    handle->context->SetVertexBuffers(0, numBuffers, vbufs, offsets, RESOURCE_STATE_TRANSITION_MODE_TRANSITION, SET_VERTEX_BUFFERS_FLAG_RESET);

    if (bindings.index_buffer.ptr != nullptr) {
        handle->context->SetIndexBuffer(reinterpret_cast<IBuffer*>(bindings.index_buffer.ptr), 0, RESOURCE_STATE_TRANSITION_MODE_TRANSITION);
        pipeline->has_index_buffer = true;
    }
    
    for (size_t i = 0; i < bindings.resources_len; i++) {
        const auto& res = bindings.resources[i];

        auto* var = pipeline->srb->GetVariableByName(SHADER_TYPE_VERTEX, res.name);
        if (!var) var = pipeline->srb->GetVariableByName(SHADER_TYPE_PIXEL, res.name);
        if (!var) {
            std::cerr << "Summit C++: No variable named '" << res.name << "'\n";
            continue;
        }

        switch (res.kind) {
            case SUMMIT_RESOURCE_KIND_UNIFORM_BUFFER:
                var->Set(reinterpret_cast<IBuffer*>(res.handle_ptr));
                break;
            case SUMMIT_RESOURCE_KIND_STORAGE_BUFFER: {
                auto* buf = reinterpret_cast<IBuffer*>(res.handle_ptr);
                var->Set(buf->GetDefaultView(BUFFER_VIEW_SHADER_RESOURCE));
                break;
            }
            case SUMMIT_RESOURCE_KIND_STORAGE_BUFFER_RW: {
                auto* buf = reinterpret_cast<IBuffer*>(res.handle_ptr);
                var->Set(buf->GetDefaultView(BUFFER_VIEW_UNORDERED_ACCESS));
                break;
            }
            case SUMMIT_RESOURCE_KIND_TEXTURE: {
                auto* tex = reinterpret_cast<ITexture*>(res.handle_ptr);
                var->Set(tex->GetDefaultView(TEXTURE_VIEW_SHADER_RESOURCE));
                break;
            }
            case SUMMIT_RESOURCE_KIND_SAMPLER:
                var->Set(reinterpret_cast<ISampler*>(res.handle_ptr));
                break;
        }
    }

    handle->context->CommitShaderResources(pipeline->srb, RESOURCE_STATE_TRANSITION_MODE_TRANSITION);
}

SummitShaderHandle diligent_create_shader(SummitDiligentDeviceHandle handle, SummitShaderDesc desc) {
    auto* pair = new SummitDiligentShader;

    ShaderCreateInfo shaderCI;
    shaderCI.SourceLanguage = SHADER_SOURCE_LANGUAGE_BYTECODE;
    shaderCI.Desc.UseCombinedTextureSamplers = false;

    for (size_t i = 0; i < desc.stages_len; i++) {
        auto stageDesc = desc.stages[i];
        auto stageType = summitShaderStageToDiligent(stageDesc.stage);

        shaderCI.Desc.ShaderType = stageType;
        shaderCI.Desc.Name = stageDesc.name;
        shaderCI.EntryPoint = stageDesc.entrypoint;
        shaderCI.ByteCode = stageDesc.source;
        shaderCI.ByteCodeSize = stageDesc.source_len;

        IShader* shader = nullptr;
        handle->device->CreateShader(shaderCI, &shader);
        if (!shader) {
            std::cerr << "Summit C++ [FATAL]: Shader creation failed\n";
            exit(EXIT_FAILURE);
        }

        if (stageType == SHADER_TYPE_VERTEX) {
            pair->vs = shader;
        } else if (stageType == SHADER_TYPE_PIXEL) {
            pair->ps = shader;
        } else if (stageType == SHADER_TYPE_COMPUTE) {
            pair->cs = shader;
        }
    }

    return { .ptr = pair };
}

void diligent_destroy_shader(SummitDiligentDeviceHandle handle, SummitShaderHandle shdH) {
    auto shader = reinterpret_cast<SummitDiligentShader*>(shdH.ptr);
    if (shader->vs) shader->vs->Release();
    if (shader->ps) shader->ps->Release();

    delete shader;
}

SummitComputePipelineHandle diligent_create_compute_pipeline(SummitDiligentDeviceHandle handle, SummitComputePipelineDesc desc) {
    auto* shaderSet = reinterpret_cast<SummitDiligentShader*>(desc.shader.ptr);
    if (!shaderSet->cs) {
        std::cerr << "Summit C++ [FATAL]: Compute pipeline created with no compute shader stage\n";
        exit(EXIT_FAILURE);
    }

    ComputePipelineStateCreateInfo psoCreateInfo;
    PipelineStateDesc& psoDesc = psoCreateInfo.PSODesc;

    psoDesc.Name = desc.name;
    psoDesc.PipelineType = PIPELINE_TYPE_COMPUTE;

    auto vars = buildResourceVars(desc.resources, desc.resources_len);
    psoDesc.ResourceLayout.Variables = vars.data();
    psoDesc.ResourceLayout.NumVariables = static_cast<uint32_t>(vars.size());

    psoCreateInfo.pCS = shaderSet->cs;

    IPipelineState* pso = nullptr;
    handle->device->CreateComputePipelineState(psoCreateInfo, &pso);
    if (!pso) {
        std::cerr << "Summit C++ [FATAL]: Compute pipeline state creation failed\n";
        exit(EXIT_FAILURE);
    }

    auto* pipeline = new SummitDiligentComputePipeline;
    pipeline->pso = pso;
    pso->CreateShaderResourceBinding(&pipeline->srb, true);

    return { .ptr = pipeline };
}

void diligent_destroy_compute_pipeline(SummitDiligentDeviceHandle handle, SummitComputePipelineHandle pipeH) {
    auto pipeline = static_cast<SummitDiligentComputePipeline*>(pipeH.ptr);
    pipeline->srb->Release();
    pipeline->pso->Release();
    delete pipeline;
}

void diligent_apply_compute_pipeline(SummitDiligentDeviceHandle handle, SummitComputePipelineHandle pipeH) {
    auto pipeline = static_cast<SummitDiligentComputePipeline*>(pipeH.ptr);
    handle->context->SetPipelineState(pipeline->pso);
}

void diligent_apply_compute_bindings(SummitDiligentDeviceHandle handle, SummitComputePipelineHandle pipeH, SummitBindings bindings) {
    auto* pipeline = static_cast<SummitDiligentComputePipeline*>(pipeH.ptr);

    for (size_t i = 0; i < bindings.resources_len; i++) {
        auto& res = bindings.resources[i];

        auto* var = pipeline->srb->GetVariableByName(SHADER_TYPE_COMPUTE, res.name);
        if (!var) {
            std::cerr << "Summit C++: No compute shader variable named '" << res.name << "'\n";
            continue;
        }

        switch (res.kind) {
            case SUMMIT_RESOURCE_KIND_UNIFORM_BUFFER:
                var->Set(reinterpret_cast<IBuffer*>(res.handle_ptr));
                break;
            case SUMMIT_RESOURCE_KIND_STORAGE_BUFFER: {
                auto* buf = reinterpret_cast<IBuffer*>(res.handle_ptr);
                var->Set(buf->GetDefaultView(BUFFER_VIEW_SHADER_RESOURCE));
                break;
            }
            case SUMMIT_RESOURCE_KIND_STORAGE_BUFFER_RW: {
                auto* buf = reinterpret_cast<IBuffer*>(res.handle_ptr);
                var->Set(buf->GetDefaultView(BUFFER_VIEW_UNORDERED_ACCESS));
                break;
            }
            case SUMMIT_RESOURCE_KIND_TEXTURE: {
                auto* tex = reinterpret_cast<ITexture*>(res.handle_ptr);
                var->Set(tex->GetDefaultView(TEXTURE_VIEW_SHADER_RESOURCE));
                break;
            }
            case SUMMIT_RESOURCE_KIND_SAMPLER:
                var->Set(reinterpret_cast<ISampler*>(res.handle_ptr));
                break;
        }
    }
    
    handle->context->CommitShaderResources(pipeline->srb, RESOURCE_STATE_TRANSITION_MODE_TRANSITION);
}

void diligent_dispatch_compute(SummitDiligentDeviceHandle handle, SummitComputePipelineHandle pipeH, uint32_t groupsX, uint32_t groupsY, uint32_t groupsZ) {
    auto pipeline = static_cast<SummitDiligentComputePipeline*>(pipeH.ptr);

    DispatchComputeAttribs attrs;
    attrs.ThreadGroupCountX = groupsX;
    attrs.ThreadGroupCountY = groupsY;
    attrs.ThreadGroupCountZ = groupsZ;

    handle->context->DispatchCompute(attrs);
}

void diligent_begin_pass(SummitDiligentDeviceHandle handle, SummitPassDesc desc) {
    ITextureView* pRTV = desc.has_color_target ? reinterpret_cast<ITextureView*>(desc.color_target.ptr) : nullptr;
    ITextureView* pDSV = desc.has_depth_target ? reinterpret_cast<ITextureView*>(desc.depth_target.ptr) : nullptr;

    handle->context->SetRenderTargets(pRTV ? 1 : 0, pRTV ? &pRTV : nullptr, pDSV, RESOURCE_STATE_TRANSITION_MODE_TRANSITION);

    if (pRTV && desc.has_clear_color) 
        handle->context->ClearRenderTarget(pRTV, desc.clear_color, RESOURCE_STATE_TRANSITION_MODE_TRANSITION);

    if (pDSV && desc.has_clear_depth) 
        handle->context->ClearDepthStencil(pDSV, CLEAR_DEPTH_FLAG | CLEAR_STENCIL_FLAG, desc.clear_depth, 0, RESOURCE_STATE_TRANSITION_MODE_TRANSITION);
    
    Viewport VP;
    VP.Width = static_cast<float>(desc.width);
    VP.Height = static_cast<float>(desc.height);
    handle->context->SetViewports(1, &VP, desc.width, desc.height);
}

SummitSwapchainHandle diligent_create_swapchain(SummitDiligentDeviceHandle handle, SummitSwapchainDesc desc) {
    OS_WINDOW window{desc.surface_handle};
    
    ISwapChain* swapchain = nullptr;
    SwapChainDesc SCDesc;
    SCDesc.DepthBufferFormat = TEX_FORMAT_UNKNOWN;
    SCDesc.Width = desc.size[0];
    SCDesc.Height = desc.size[1];
    
#ifdef SUMMIT_D3D11_BACKEND
    auto factoryD3D11 = reinterpret_cast<IEngineFactoryD3D11*>(handle->factory);
    factoryD3D11->CreateSwapChainD3D11(handle->device, handle->context, SCDesc, FullScreenModeDesc{}, Window, &swapchain);
#elif SUMMIT_D3D12_BACKEND
    auto factoryD3D12 = reinterpret_cast<IEngineFactoryD3D12*>(handle->factory);
    factoryD3D12->CreateSwapChainD3D12(handle->device, handle->context, SCDesc, FullScreenModeDesc{}, Window, &swapchain);
#elif SUMMIT_OPENGL_BACKEND
    std::cerr << "OpenGL support is temporarily broken, sorry\n";
    exit(EXIT_FAILURE);
#elif SUMMIT_VULKAN_BACKEND
    auto factoryVk = reinterpret_cast<IEngineFactoryVk*>(handle->factory);
    factoryVk->CreateSwapChainVk(handle->device, handle->context, SCDesc, window, &swapchain);
#endif

    if (!swapchain) {
        std::cerr << "Failed to create swapchain\n";
        exit(EXIT_FAILURE);
    }

    return { .ptr = swapchain };
}

void diligent_resize_swapchain(SummitDiligentDeviceHandle handle, SummitSwapchainHandle swapH, uint32_t width, uint32_t height) {
    if (width == 0 || height == 0) return;
    handle->context->SetRenderTargets(0, nullptr, nullptr, RESOURCE_STATE_TRANSITION_MODE_NONE);

    auto swapchain = reinterpret_cast<ISwapChain*>(swapH.ptr);
    swapchain->Resize(width, height);
}

void diligent_present_swapchain(SummitDiligentDeviceHandle handle, SummitSwapchainHandle swapH, uint32_t sync_interval) {
    auto swapchain = reinterpret_cast<ISwapChain*>(swapH.ptr);
    swapchain->Present(sync_interval);
}

SummitRenderTargetHandle diligent_get_swapchain_backbuffer(SummitDiligentDeviceHandle handle, SummitSwapchainHandle swapH) {
    auto swapchain = reinterpret_cast<ISwapChain*>(swapH.ptr);
    auto backbuffer = swapchain->GetCurrentBackBufferRTV();

    return { .ptr = backbuffer };
}

void diligent_destroy_swapchain(SummitDiligentDeviceHandle handle, SummitSwapchainHandle swapH) {
    handle->context->SetRenderTargets(0, nullptr, nullptr, RESOURCE_STATE_TRANSITION_MODE_NONE);
    handle->context->Flush();
    handle->context->WaitForIdle();

    auto swapchain = reinterpret_cast<ISwapChain*>(swapH.ptr);
    swapchain->Release();
}

SummitRenderTargetHandle diligent_image_get_rtv(SummitDiligentDeviceHandle handle, SummitImageHandle img) {
    auto* tex = reinterpret_cast<ITexture*>(img.ptr);
    auto* view = tex->GetDefaultView(TEXTURE_VIEW_RENDER_TARGET);
    if (!view) {
        std::cerr << "[FATAL]: image was not created with is_render_target\n";
        exit(EXIT_FAILURE);
    }

    return { .ptr = view };
}

SummitDepthTargetHandle diligent_image_get_dsv(SummitDiligentDeviceHandle handle, SummitImageHandle img) {
    auto* tex = reinterpret_cast<ITexture*>(img.ptr);
    auto* view = tex->GetDefaultView(TEXTURE_VIEW_DEPTH_STENCIL);
    if (!view) {
        std::cerr << "[FATAL]: image has no DEPTH_STENCIL view\n";
        exit(EXIT_FAILURE);
    }

    return { .ptr = view };
}

SummitBackend diligent_query_backend() {
#ifdef SUMMIT_D3D11_BACKEND
    return SUMMIT_BACKEND_DIRECT3D11;
#elif SUMMIT_D3D12_BACKEND
    return SUMMIT_BACKEND_DIRECT3D12;
#elif SUMMIT_OPENGL_BACKEND
    return SUMMIT_BACKEND_OPENGL;
#elif SUMMIT_VULKAN_BACKEND
    return SUMMIT_BACKEND_VULKAN;
#endif
}