// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

#pragma once
#include "../crystal_type_glue.h"

#ifdef __cplusplus
extern "C" {
#endif

struct CrystalSlangCompilerContext; 
typedef struct CrystalSlangCompilerContext* CrystalSlangCompilerHandle;

typedef struct {
    const void* code_data;
    size_t code_size;
    const char* error_message;
} CrystalSlangCompileResult;

typedef enum {
    CRYSTAL_SLANG_TARGET_HLSL,
    CRYSTAL_SLANG_TARGET_GLSL,
    CRYSTAL_SLANG_TARGET_SPIRV
} CrystalSlangTargetKind;

typedef enum {
    CRYSTAL_SLANG_STAGE_VERTEX,
    CRYSTAL_SLANG_STAGE_FRAGMENT,
    CRYSTAL_SLANG_STAGE_COMPUTE
} CrystalSlangStageKind;

typedef const char* (*CrystalSlangVfsLookupFn)(void* userData, const char* path, size_t* outSize);

CrystalSlangCompilerHandle slang_compiler_create();
void slang_compiler_destroy(CrystalSlangCompilerHandle compiler);

CrystalSlangCompileResult slang_compile_stage(CrystalSlangCompilerHandle compiler, void* vfs, const char* module_name, const char* source, const char* entry_point, CrystalSlangStageKind stage, CrystalSlangTargetKind target);
void slang_free_result(CrystalSlangCompileResult result);

void* slang_vfs_create(CrystalSlangVfsLookupFn lookupFn, void* userData);
void slang_vfs_destroy(void* vfs);

#ifdef __cplusplus
}
#endif