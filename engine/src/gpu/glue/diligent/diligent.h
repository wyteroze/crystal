// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

#pragma once
#include "../summit_type_glue.h"

#ifdef __cplusplus
extern "C" {
#endif

// This is a type that we define and zig uses.
struct SummitDiligentDeviceContext; 
typedef struct SummitDiligentDeviceContext* SummitDiligentDeviceHandle;

// Init/deinit
SummitDiligentDeviceHandle diligent_init();
void diligent_deinit(SummitDiligentDeviceHandle handle);

// Buffer
SummitBufferHandle diligent_create_buffer(SummitDiligentDeviceHandle handle, SummitBufferDesc desc);
void diligent_update_buffer(SummitDiligentDeviceHandle handle, SummitBufferHandle bufH, const char* data, size_t size);
void diligent_destroy_buffer(SummitDiligentDeviceHandle handle, SummitBufferHandle bufH);

// Sampler
SummitSamplerHandle diligent_create_sampler(SummitDiligentDeviceHandle handle, SummitSamplerDesc desc);
void diligent_destroy_sampler(SummitDiligentDeviceHandle handle, SummitSamplerHandle samH);

// Image
SummitImageHandle diligent_create_image(SummitDiligentDeviceHandle handle, SummitImageDesc desc);
void diligent_destroy_image(SummitDiligentDeviceHandle handle, SummitImageHandle imgH);

// Pipeline
SummitPipelineHandle diligent_create_pipeline(SummitDiligentDeviceHandle handle, SummitPipelineDesc desc);
void diligent_destroy_pipeline(SummitDiligentDeviceHandle handle, SummitPipelineHandle pipeH);
void diligent_apply_pipeline(SummitDiligentDeviceHandle handle, SummitPipelineHandle pipeH);
void diligent_draw_pipeline(SummitDiligentDeviceHandle handle, SummitShaderHandle pipeH, uint32_t base, uint32_t count, uint32_t instances);
void diligent_pipeline_apply_bindings(SummitDiligentDeviceHandle handle, SummitPipelineHandle pipeH, SummitBindings bindings);

// Compute pipeline
SummitComputePipelineHandle diligent_create_compute_pipeline(SummitDiligentDeviceHandle handle, SummitComputePipelineDesc desc);
void diligent_destroy_compute_pipeline(SummitDiligentDeviceHandle handle, SummitComputePipelineHandle pipeH);
void diligent_apply_compute_pipeline(SummitDiligentDeviceHandle handle, SummitComputePipelineHandle pipeH);
void diligent_apply_compute_bindings(SummitDiligentDeviceHandle handle, SummitComputePipelineHandle pipeH, SummitBindings bindings);
void diligent_dispatch_compute(SummitDiligentDeviceHandle handle, SummitComputePipelineHandle pipeH, uint32_t groupsX, uint32_t groupsY, uint32_t groupsZ);

// Shader
SummitShaderHandle diligent_create_shader(SummitDiligentDeviceHandle handle, SummitShaderDesc desc);
void diligent_destroy_shader(SummitDiligentDeviceHandle handle, SummitShaderHandle shdH);

// Pass
void diligent_begin_pass(SummitDiligentDeviceHandle handle, SummitPassDesc desc);
void diligent_end_pass(SummitDiligentDeviceHandle handle);

// Swapchain
SummitSwapchainHandle diligent_create_swapchain(SummitDiligentDeviceHandle handle, SummitSwapchainDesc desc);
void diligent_resize_swapchain(SummitDiligentDeviceHandle handle, SummitSwapchainHandle swapH, uint32_t width, uint32_t height);
void diligent_present_swapchain(SummitDiligentDeviceHandle handle, SummitSwapchainHandle swapH, uint32_t sync_interval);
SummitRenderTargetHandle diligent_get_swapchain_backbuffer(SummitDiligentDeviceHandle handle, SummitSwapchainHandle swapH);
void diligent_destroy_swapchain(SummitDiligentDeviceHandle handle, SummitSwapchainHandle swapH);

// Misc
SummitRenderTargetHandle diligent_image_get_rtv(SummitDiligentDeviceHandle handle, SummitImageHandle img);
SummitDepthTargetHandle diligent_image_get_dsv(SummitDiligentDeviceHandle handle, SummitImageHandle img);
void diligent_present(SummitDiligentDeviceHandle handle);
SummitBackend diligent_query_backend();
SummitImageHandle diligent_get_depth_buffer(SummitDiligentDeviceHandle handle);

#ifdef __cplusplus
}
#endif