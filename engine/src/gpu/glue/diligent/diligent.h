// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

#pragma once
#include "../crystal_type_glue.h"

#ifdef __cplusplus
extern "C" {
#endif

// This is a type that we define and zig uses.
struct CrystalDiligentDeviceContext; 
typedef struct CrystalDiligentDeviceContext* CrystalDiligentDeviceHandle;

// Init/deinit
CrystalDiligentDeviceHandle diligent_init();
void diligent_deinit(CrystalDiligentDeviceHandle handle);

// Buffer
CrystalBufferHandle diligent_create_buffer(CrystalDiligentDeviceHandle handle, CrystalBufferDesc desc);
void diligent_update_buffer(CrystalDiligentDeviceHandle handle, CrystalBufferHandle bufH, const char* data, size_t size);
void diligent_destroy_buffer(CrystalDiligentDeviceHandle handle, CrystalBufferHandle bufH);

// Sampler
CrystalSamplerHandle diligent_create_sampler(CrystalDiligentDeviceHandle handle, CrystalSamplerDesc desc);
void diligent_destroy_sampler(CrystalDiligentDeviceHandle handle, CrystalSamplerHandle samH);

// Image
CrystalImageHandle diligent_create_image(CrystalDiligentDeviceHandle handle, CrystalImageDesc desc);
void diligent_destroy_image(CrystalDiligentDeviceHandle handle, CrystalImageHandle imgH);

// Pipeline
CrystalPipelineHandle diligent_create_pipeline(CrystalDiligentDeviceHandle handle, CrystalPipelineDesc desc);
void diligent_destroy_pipeline(CrystalDiligentDeviceHandle handle, CrystalPipelineHandle pipeH);
void diligent_apply_pipeline(CrystalDiligentDeviceHandle handle, CrystalPipelineHandle pipeH);
void diligent_draw_pipeline(CrystalDiligentDeviceHandle handle, CrystalShaderHandle pipeH, uint32_t base, uint32_t count, uint32_t instances);
void diligent_pipeline_apply_bindings(CrystalDiligentDeviceHandle handle, CrystalPipelineHandle pipeH, CrystalBindings bindings);

// Compute pipeline
CrystalComputePipelineHandle diligent_create_compute_pipeline(CrystalDiligentDeviceHandle handle, CrystalComputePipelineDesc desc);
void diligent_destroy_compute_pipeline(CrystalDiligentDeviceHandle handle, CrystalComputePipelineHandle pipeH);
void diligent_apply_compute_pipeline(CrystalDiligentDeviceHandle handle, CrystalComputePipelineHandle pipeH);
void diligent_apply_compute_bindings(CrystalDiligentDeviceHandle handle, CrystalComputePipelineHandle pipeH, CrystalBindings bindings);
void diligent_dispatch_compute(CrystalDiligentDeviceHandle handle, CrystalComputePipelineHandle pipeH, uint32_t groupsX, uint32_t groupsY, uint32_t groupsZ);

// Shader
CrystalShaderHandle diligent_create_shader(CrystalDiligentDeviceHandle handle, CrystalShaderDesc desc);
void diligent_destroy_shader(CrystalDiligentDeviceHandle handle, CrystalShaderHandle shdH);

// Pass
void diligent_begin_pass(CrystalDiligentDeviceHandle handle, CrystalPassDesc desc);
void diligent_end_pass(CrystalDiligentDeviceHandle handle);

// Swapchain
CrystalSwapchainHandle diligent_create_swapchain(CrystalDiligentDeviceHandle handle, CrystalSwapchainDesc desc);
void diligent_resize_swapchain(CrystalDiligentDeviceHandle handle, CrystalSwapchainHandle swapH, uint32_t width, uint32_t height);
void diligent_present_swapchain(CrystalDiligentDeviceHandle handle, CrystalSwapchainHandle swapH, uint32_t sync_interval);
CrystalRenderTargetHandle diligent_get_swapchain_backbuffer(CrystalDiligentDeviceHandle handle, CrystalSwapchainHandle swapH);
void diligent_destroy_swapchain(CrystalDiligentDeviceHandle handle, CrystalSwapchainHandle swapH);

// Misc
CrystalRenderTargetHandle diligent_image_get_rtv(CrystalDiligentDeviceHandle handle, CrystalImageHandle img);
CrystalDepthTargetHandle diligent_image_get_dsv(CrystalDiligentDeviceHandle handle, CrystalImageHandle img);
void diligent_present(CrystalDiligentDeviceHandle handle);
CrystalBackend diligent_query_backend();
CrystalImageHandle diligent_get_depth_buffer(CrystalDiligentDeviceHandle handle);

#ifdef __cplusplus
}
#endif