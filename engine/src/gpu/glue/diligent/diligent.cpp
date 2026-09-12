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

#ifdef CRYSTAL_D3D11_BACKEND
#include "DiligentCore/Graphics/GraphicsEngineD3D11/interface/EngineFactoryD3D11.h"
#elif CRYSTAL_D3D12_BACKEND
#include "DiligentCore/Graphics/GraphicsEngineD3D12/interface/EngineFactoryD3D12.h"
#elif CRYSTAL_OPENGL_BACKEND
#include "DiligentCore/Graphics/GraphicsEngineOpenGL/interface/EngineFactoryOpenGL.h"
#elif CRYSTAL_VULKAN_BACKEND
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
struct CrystalDiligentDeviceContext {
    IRenderDevice* device;
    IDeviceContext* context;
    ISwapChain* swapchain;
};

struct CrystalDiligentShader {
    IShader* vs = nullptr;
    IShader* ps = nullptr;
    IShader* cs = nullptr;
};

struct CrystalDiligentPipeline {
    IPipelineState* pso;
    IShaderResourceBinding* srb;
    VALUE_TYPE index_type;
};

struct CrystalDiligentComputePipeline {
    IPipelineState* pso;
    IShaderResourceBinding* srb;
};

// Helpers

static FILTER_TYPE crystalFilterToDiligent(CrystalFilterType filter) {
    switch (filter) {
        case CRYSTAL_FILTER_TYPE_LINEAR:
            return FILTER_TYPE_LINEAR;
        case CRYSTAL_FILTER_TYPE_NEAREST:
            return FILTER_TYPE_POINT;
    }
}

static TEXTURE_ADDRESS_MODE crystalWrapToDiligent(CrystalWrapType wrap) {
    switch (wrap) {
        case CRYSTAL_WRAP_TYPE_CLAMP:
            return TEXTURE_ADDRESS_CLAMP;
        case CRYSTAL_WRAP_TYPE_REPEAT:
            return TEXTURE_ADDRESS_WRAP;
    }
}

static SHADER_TYPE crystalShaderStageToDiligent(CrystalShaderStage stage) {
    switch (stage) {
        case CRYSTAL_SHADER_STAGE_VERTEX:
            return SHADER_TYPE_VERTEX;
        case CRYSTAL_SHADER_STAGE_FRAGMENT:
            return SHADER_TYPE_PIXEL;
        case CRYSTAL_SHADER_STAGE_COMPUTE:
            return SHADER_TYPE_COMPUTE;
    }
}

static SHADER_TYPE crystalVisibilityToDiligent(CrystalShaderVisibility visibility) {
    switch (visibility) {
        case CRYSTAL_SHADER_VISIBILITY_VERTEX:
            return SHADER_TYPE_VERTEX;
        case CRYSTAL_SHADER_VISIBILITY_FRAGMENT:
            return SHADER_TYPE_PIXEL;
        case CRYSTAL_SHADER_VISIBILITY_COMPUTE:
            return SHADER_TYPE_COMPUTE;
        case CRYSTAL_SHADER_VISIBILITY_VERTEX_FRAGMENT:
            return SHADER_TYPE_VERTEX | SHADER_TYPE_PIXEL;
    }
}

static std::vector<ShaderResourceVariableDesc> buildResourceVars(const CrystalResourceDesc* resources, size_t count) {
    std::vector<ShaderResourceVariableDesc> vars;
    vars.reserve(count);
    for (size_t i = 0; i < count; i++) {
        vars.push_back({
            crystalVisibilityToDiligent(resources[i].visibility), 
            resources[i].name, 
            SHADER_RESOURCE_VARIABLE_TYPE_MUTABLE 
        });
    }

    return vars;
}

// Implementation

CrystalDiligentDeviceHandle diligent_init(void* surfaceHandle, uint32_t surfaceSizeX, uint32_t surfaceSizeY) {
    CrystalDiligentDeviceHandle handle = new CrystalDiligentDeviceContext();
    SwapChainDesc SCDesc;
    SCDesc.DepthBufferFormat = TEX_FORMAT_D32_FLOAT;

    IRenderDevice* device;
    IDeviceContext* context;
    ISwapChain* swapchain;

#ifdef CRYSTAL_D3D11_BACKEND
    EngineD3D11CreateInfo EngineCI;
    auto *factoryD3D11 LoadAndGetEngineFactoryD3D11();
    factoryD3D11->CreateDeviceAndContextsD3D11(EngineCI, &device, &context);

    OS_WINDOW Window{surfaceHandle};
    factoryD3D11->CreateSwapChainD3D11(device, context, SCDesc, FullScreenModeDesc{}, Window, &swapchain);
#elif CRYSTAL_D3D12_BACKEND
    EngineD3D12CreateInfo EngineCI;
    auto *factoryD3D12 LoadAndGetEngineFactoryD3D12();
    factoryD3D12->CreateDeviceAndContextsD3D12(EngineCI, &device, &context);

    OS_WINDOW Window{surfaceHandle};
    factoryD3D11->CreateSwapChainD3D12(device, context, SCDesc, FullScreenModeDesc{}, Window, &swapchain);
#elif CRYSTAL_OPENGL_BACKEND
    auto* factoryOpenGL = LoadAndGetEngineFactoryOpenGL();

    EngineGLCreateInfo EngineCI;
    EngineCI.Window = OS_WINDOW{surfaceHandle};

    factoryOpenGL->CreateDeviceAndSwapChainGL(EngineCI, &device, &context, SCDesc, &swapchain);
#elif CRYSTAL_VULKAN_BACKEND
    EngineVkCreateInfo EngineCI;
    auto* factoryVk = LoadAndGetEngineFactoryVk();
    factoryVk->CreateDeviceAndContextsVk(EngineCI, &device, &context);
    
    OS_WINDOW Window{surfaceHandle};
    factoryVk->CreateSwapChainVk(device, context, SCDesc, Window, &swapchain);
    if (!swapchain) {
        std::cerr << "Crystal C++ [FATAL]: Failed to create swapchain \n";
        exit(EXIT_FAILURE);
    }
#endif

    handle->device = device;
    handle->context = context;
    handle->swapchain = swapchain;

    return handle;
}

void diligent_deinit(CrystalDiligentDeviceHandle handle) {
    handle->device->Release();
    handle->context->Flush();
    handle->context->Release();
    handle->swapchain->Release();
    delete handle;
}

CrystalBufferHandle diligent_create_buffer(CrystalDiligentDeviceHandle handle, CrystalBufferDesc desc) {
    BufferDesc BufDesc;
    BufDesc.Name = desc.name;
    switch (desc.type) {
        case CRYSTAL_BUFFER_TYPE_INDEX:
            BufDesc.BindFlags = BIND_INDEX_BUFFER;
            break;
        case CRYSTAL_BUFFER_TYPE_VERTEX:
            BufDesc.BindFlags = BIND_VERTEX_BUFFER;
            break;
        case CRYSTAL_BUFFER_TYPE_UNIFORM:
            BufDesc.BindFlags = BIND_UNIFORM_BUFFER;
            break;
        case CRYSTAL_BUFFER_TYPE_STORAGE:
            BufDesc.BindFlags = BIND_SHADER_RESOURCE | BIND_UNORDERED_ACCESS;
            BufDesc.Mode = BUFFER_MODE_STRUCTURED;
            if (desc.stride == 0) {
                std::cerr << "Crystal C++ [FATAL]: Invalid stride for buffer of type CRYSTAL_BUFFER_TYPE_STORAGE";
                exit(EXIT_FAILURE);
            }
            BufDesc.ElementByteStride = desc.stride;

            break;
    }
    switch (desc.usage) {
        case CRYSTAL_BUFFER_USAGE_DEFAULT:
            BufDesc.Usage = USAGE_DEFAULT;
            break;
        case CRYSTAL_BUFFER_USAGE_IMMUTABLE:
            BufDesc.Usage = USAGE_IMMUTABLE;
            break;
        case CRYSTAL_BUFFER_USAGE_DYNAMIC:
            BufDesc.Usage = USAGE_DYNAMIC;
            BufDesc.CPUAccessFlags = CPU_ACCESS_WRITE;
            break;
        case CRYSTAL_BUFFER_USAGE_STREAM:
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

void diligent_update_buffer(CrystalDiligentDeviceHandle handle, CrystalBufferHandle bufH, const char* data, size_t size) {
    auto buffer = static_cast<IBuffer*>(bufH.ptr);
    auto desc = buffer->GetDesc();

    switch (desc.Usage) {
        case USAGE_DYNAMIC:
        case USAGE_STAGING: {
            MapHelper<uint8_t> MappedData(
                handle->context,
                buffer,
                MAP_WRITE,
                MAP_FLAG_DISCARD
            );

            std::memcpy(MappedData, data, size);
        }
        break;
        case USAGE_IMMUTABLE:
            std::cerr << "Crystal C++: Unable to update immutable buffer\n";
            return;
        default: 
            std::cerr << "Crystal C++ [FATAL]: Unknown buffer usage type\n";
            exit(EXIT_FAILURE); 
    }
}

void diligent_destroy_buffer(CrystalDiligentDeviceHandle handle, CrystalBufferHandle bufH) {
    auto buffer = static_cast<IBuffer*>(bufH.ptr);
    buffer->Release();
}

CrystalSamplerHandle diligent_create_sampler(CrystalDiligentDeviceHandle handle, CrystalSamplerDesc desc) {
    SamplerDesc SamDesc;

    SamDesc.MinFilter = crystalFilterToDiligent(desc.min_filter);
    SamDesc.MagFilter = crystalFilterToDiligent(desc.mag_filter);
    SamDesc.MipFilter = crystalFilterToDiligent(desc.mip_filter);

    SamDesc.AddressU = crystalWrapToDiligent(desc.wrap_u);
    SamDesc.AddressV = crystalWrapToDiligent(desc.wrap_v);

    ISampler* sampler = nullptr;
    handle->device->CreateSampler(SamDesc, &sampler);

    return { .ptr = sampler };
}

void diligent_destroy_sampler(CrystalDiligentDeviceHandle handle, void* samPtr) {
    auto sampler = static_cast<ISampler*>(samPtr);
    sampler->Release();
}

CrystalImageHandle diligent_create_image(CrystalDiligentDeviceHandle handle, CrystalImageDesc desc) {
    TextureDesc TexDesc;
    size_t stride = 0;

    TexDesc.Name = desc.name;
    TexDesc.Type = RESOURCE_DIM_TEX_2D;
    TexDesc.Width = desc.width;
    TexDesc.Height = desc.height;
    switch (desc.format) {
        case CRYSTAL_PIXEL_FORMAT_RGBA8:
            TexDesc.Format = TEX_FORMAT_RGBA8_UNORM_SRGB;
            TexDesc.BindFlags = BIND_SHADER_RESOURCE;
            stride = 4;
            
            break;
        case CRYSTAL_PIXEL_FORMAT_RGBA16F:
            TexDesc.Format = TEX_FORMAT_RGBA16_FLOAT;
            TexDesc.BindFlags = BIND_SHADER_RESOURCE;
            stride = 8;

            break;
        case CRYSTAL_PIXEL_FORMAT_D24_S8:
            TexDesc.Format = Diligent::TEX_FORMAT_D24_UNORM_S8_UINT;
            TexDesc.BindFlags = BIND_DEPTH_STENCIL;
            stride = 4;

            break;
    }
    TexDesc.Usage = USAGE_IMMUTABLE;

    TextureSubResData subres;
    subres.pData = desc.data;
    subres.Stride = desc.width * stride;
    
    TextureData data;
    data.pSubResources = &subres;
    data.NumSubresources = 1;
    
    ITexture* tex = nullptr;
    handle->device->CreateTexture(TexDesc, &data, &tex);
    
    return { .ptr = tex };
}

void diligent_destroy_image(CrystalDiligentDeviceHandle handle, CrystalImageHandle imgH) {
    auto image = static_cast<ITextureView*>(imgH.ptr);
    image->Release();
}

CrystalPipelineHandle diligent_create_pipeline(CrystalDiligentDeviceHandle handle, CrystalPipelineDesc desc) {
    auto* shaderSet = reinterpret_cast<CrystalDiligentShader*>(desc.shader.ptr);

    GraphicsPipelineStateCreateInfo psoCreateInfo;
    auto& psoDesc = psoCreateInfo.PSODesc;
    auto& graphicsPipeline = psoCreateInfo.GraphicsPipeline;

    psoDesc.Name = desc.name;
    psoDesc.PipelineType = PIPELINE_TYPE_GRAPHICS;

    graphicsPipeline.NumRenderTargets = 1;
    graphicsPipeline.RTVFormats[0] = handle->swapchain->GetDesc().ColorBufferFormat;
    graphicsPipeline.DSVFormat = handle->swapchain->GetDesc().DepthBufferFormat;

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

    graphicsPipeline.DepthStencilDesc.DepthEnable = desc.depth_write;
    graphicsPipeline.DepthStencilDesc.DepthWriteEnable = desc.depth_write;

    std::vector<LayoutElement> layoutElems;
    layoutElems.reserve(desc.layout_len);
    for (size_t i = 0; i < desc.layout_len; i++) {
        const CrystalVertexAttr& attr = desc.layout[i];
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

    auto* pipeline = new CrystalDiligentPipeline;
    pipeline->pso = pso;
    switch (desc.index_type) {
        case CRYSTAL_INDEX_TYPE_UINT16:
            pipeline->index_type = VT_INT16;
            break;
        case CRYSTAL_INDEX_TYPE_UINT32:
            pipeline->index_type = VT_UINT32;
            break;
        case CRYSTAL_INDEX_TYPE_NONE:
            std::cerr << "Crystal C++ [FATAL]: Creating a pipeline with index type of CRYSTAL_INDEX_TYPE_NONE is forbidden\n";
            exit(EXIT_FAILURE);
    }
    pso->CreateShaderResourceBinding(&pipeline->srb, true);

    return { .ptr = pipeline };
}

void diligent_destroy_pipeline(CrystalDiligentDeviceHandle handle, CrystalPipelineHandle pipeH) {
    auto pipeline = static_cast<CrystalDiligentPipeline*>(pipeH.ptr);
    pipeline->srb->Release();
    pipeline->pso->Release();
    delete pipeline;
}

void diligent_apply_pipeline(CrystalDiligentDeviceHandle handle, CrystalPipelineHandle pipeH) {
    auto pipeline = static_cast<CrystalDiligentPipeline*>(pipeH.ptr);
    handle->context->SetPipelineState(pipeline->pso);
}

void diligent_draw_pipeline(CrystalDiligentDeviceHandle handle, CrystalShaderHandle pipeH, uint32_t base, uint32_t count, uint32_t instances) {
    auto pipeline = static_cast<CrystalDiligentPipeline*>(pipeH.ptr);

    DrawIndexedAttribs drawAttrs;
    
    drawAttrs.IndexType = pipeline->index_type;
    drawAttrs.NumIndices = count;
    drawAttrs.FirstIndexLocation = base;
    drawAttrs.NumInstances = instances;
    drawAttrs.Flags = DRAW_FLAG_VERIFY_ALL;

    handle->context->DrawIndexed(drawAttrs);
}

void diligent_pipeline_apply_bindings(CrystalDiligentDeviceHandle handle, CrystalPipelineHandle pipeH, CrystalBindings bindings) {
    auto pipeline = static_cast<CrystalDiligentPipeline*>(pipeH.ptr);

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
    }

    for (size_t i = 0; i < bindings.resources_len; i++) {
        const auto& res = bindings.resources[i];

        auto* var = pipeline->srb->GetVariableByName(SHADER_TYPE_VERTEX, res.name);
        if (!var) var = pipeline->srb->GetVariableByName(SHADER_TYPE_PIXEL, res.name);
        if (!var) {
            std::cerr << "Crystal C++: No variable named '" << res.name << "'\n";
            continue;
        }

        switch (res.kind) {
            case CRYSTAL_RESOURCE_KIND_UNIFORM_BUFFER:
            case CRYSTAL_RESOURCE_KIND_STORAGE_BUFFER:
                var->Set(reinterpret_cast<IBuffer*>(res.handle_ptr));
                break;
            case CRYSTAL_RESOURCE_KIND_TEXTURE: {
                auto* tex = reinterpret_cast<ITexture*>(res.handle_ptr);
                var->Set(tex->GetDefaultView(TEXTURE_VIEW_SHADER_RESOURCE));
                break;
            }
            case CRYSTAL_RESOURCE_KIND_SAMPLER:
                var->Set(reinterpret_cast<ISampler*>(res.handle_ptr));
                break;
        }
    }

    handle->context->CommitShaderResources(pipeline->srb, RESOURCE_STATE_TRANSITION_MODE_TRANSITION);
}

CrystalShaderHandle diligent_create_shader(CrystalDiligentDeviceHandle handle, CrystalShaderDesc desc) {
    auto* pair = new CrystalDiligentShader;

    ShaderCreateInfo shaderCI;
    shaderCI.SourceLanguage = SHADER_SOURCE_LANGUAGE_BYTECODE;
    shaderCI.Desc.UseCombinedTextureSamplers = false;

    for (size_t i = 0; i < desc.stages_len; i++) {
        auto stageDesc = desc.stages[i];
        auto stageType = crystalShaderStageToDiligent(stageDesc.stage);

        shaderCI.Desc.ShaderType = stageType;
        shaderCI.Desc.Name = stageDesc.name;
        shaderCI.EntryPoint = stageDesc.entrypoint;
        shaderCI.ByteCode = stageDesc.source;
        shaderCI.ByteCodeSize = stageDesc.source_len;

        IShader* shader = nullptr;
        handle->device->CreateShader(shaderCI, &shader);
        if (!shader) {
            std::cerr << "Crystal C++ [FATAL]: Shader creation failed\n";
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

void diligent_destroy_shader(CrystalDiligentDeviceHandle handle, CrystalShaderHandle shdH) {
    auto shader = reinterpret_cast<CrystalDiligentShader*>(shdH.ptr);
    if (shader->vs) shader->vs->Release();
    if (shader->ps) shader->ps->Release();

    delete shader;
}

CrystalComputePipelineHandle diligent_create_compute_pipeline(CrystalDiligentDeviceHandle handle, CrystalComputePipelineDesc desc) {
    auto* shaderSet = reinterpret_cast<CrystalDiligentShader*>(desc.shader.ptr);
    if (!shaderSet->cs) {
        std::cerr << "Crystal C++ [FATAL]: Compute pipeline created with no compute shader stage\n";
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
        std::cerr << "Crystal C++ [FATAL]: Compute pipeline state creation failed\n";
        exit(EXIT_FAILURE);
    }

    auto* pipeline = new CrystalDiligentComputePipeline;
    pipeline->pso = pso;
    pso->CreateShaderResourceBinding(&pipeline->srb, true);

    return { .ptr = pipeline };
}

void diligent_destroy_compute_pipeline(CrystalDiligentDeviceHandle handle, CrystalComputePipelineHandle pipeH) {
    auto pipeline = static_cast<CrystalDiligentComputePipeline*>(pipeH.ptr);
    pipeline->srb->Release();
    pipeline->pso->Release();
    delete pipeline;
}

void diligent_apply_compute_pipeline(CrystalDiligentDeviceHandle handle, CrystalComputePipelineHandle pipeH) {
    auto pipeline = static_cast<CrystalDiligentComputePipeline*>(pipeH.ptr);
    handle->context->SetPipelineState(pipeline->pso);
}

void diligent_apply_compute_bindings(CrystalDiligentDeviceHandle handle, CrystalComputePipelineHandle pipeH, CrystalBindings bindings) {
    auto* pipeline = static_cast<CrystalDiligentComputePipeline*>(pipeH.ptr);

    for (size_t i = 0; i < bindings.resources_len; i++) {
        auto& res = bindings.resources[i];

        auto* var = pipeline->srb->GetVariableByName(SHADER_TYPE_COMPUTE, res.name);
        if (!var) {
            std::cerr << "Crystal C++: No compute shader variable named '" << res.name << "'\n";
            continue;
        }

        switch (res.kind) {
            case CRYSTAL_RESOURCE_KIND_UNIFORM_BUFFER:
                var->Set(reinterpret_cast<IBuffer*>(res.handle_ptr));
                break;
            case CRYSTAL_RESOURCE_KIND_STORAGE_BUFFER: {
                auto* buf = reinterpret_cast<IBuffer*>(res.handle_ptr);
                var->Set(buf->GetDefaultView(BUFFER_VIEW_UNORDERED_ACCESS));
                break;
            }
            case CRYSTAL_RESOURCE_KIND_TEXTURE: {
                auto* tex = reinterpret_cast<ITexture*>(res.handle_ptr);
                var->Set(tex->GetDefaultView(TEXTURE_VIEW_SHADER_RESOURCE));
                break;
            }
            case CRYSTAL_RESOURCE_KIND_SAMPLER:
                var->Set(reinterpret_cast<ISampler*>(res.handle_ptr));
                break;
        }
    }
    
    handle->context->CommitShaderResources(pipeline->srb, RESOURCE_STATE_TRANSITION_MODE_TRANSITION);
}

void diligent_dispatch_compute(CrystalDiligentDeviceHandle handle, CrystalComputePipelineHandle pipeH, uint32_t groupsX, uint32_t groupsY, uint32_t groupsZ) {
    auto pipeline = static_cast<CrystalDiligentComputePipeline*>(pipeH.ptr);

    DispatchComputeAttribs attrs;
    attrs.ThreadGroupCountX = groupsX;
    attrs.ThreadGroupCountY = groupsY;
    attrs.ThreadGroupCountZ = groupsZ;

    handle->context->DispatchCompute(attrs);
}

void diligent_begin_pass(CrystalDiligentDeviceHandle handle, CrystalPassDesc desc) {
    auto pRTV = handle->swapchain->GetCurrentBackBufferRTV();
    auto pDSV = handle->swapchain->GetDepthBufferDSV();

    handle->context->SetRenderTargets(1, &pRTV, pDSV, RESOURCE_STATE_TRANSITION_MODE_TRANSITION);

    if (desc.has_clear_color) 
        handle->context->ClearRenderTarget(pRTV, desc.clear_color, RESOURCE_STATE_TRANSITION_MODE_TRANSITION);

    if (desc.has_clear_depth) 
        handle->context->ClearDepthStencil(pDSV, CLEAR_DEPTH_FLAG | CLEAR_STENCIL_FLAG, desc.clear_depth, 0, RESOURCE_STATE_TRANSITION_MODE_TRANSITION);
    
    Viewport VP;
    VP.Width = static_cast<float>(desc.width);
    VP.Height = static_cast<float>(desc.height);
    handle->context->SetViewports(1, &VP, desc.width, desc.height);
}

void diligent_end_pass(CrystalDiligentDeviceHandle handle) {
    // No-op for diligent
}

void diligent_present(CrystalDiligentDeviceHandle handle) {
    handle->swapchain->Present();
}

CrystalBackend diligent_query_backend() {
#ifdef CRYSTAL_D3D11_BACKEND
    return CRYSTAL_BACKEND_DIRECT3D11;
#elif CRYSTAL_D3D12_BACKEND
    return CRYSTAL_BACKEND_DIRECT3D12;
#elif CRYSTAL_OPENGL_BACKEND
    return CRYSTAL_BACKEND_OPENGL;
#elif CRYSTAL_VULKAN_BACKEND
    return CRYSTAL_BACKEND_VULKAN;
#endif
}