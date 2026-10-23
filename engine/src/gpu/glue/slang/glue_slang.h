// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

#pragma once
#include "../summit_type_glue.h"

#ifdef __cplusplus
extern "C" {
#endif

struct SummitSlangCompilerContext; 
typedef struct SummitSlangCompilerContext* SummitSlangCompilerHandle;

typedef struct {
    const void* code_data;
    size_t code_size;
    const char* error_message;
} SummitSlangCompileResult;

typedef enum {
    SUMMIT_SLANG_TARGET_HLSL,
    SUMMIT_SLANG_TARGET_GLSL,
    SUMMIT_SLANG_TARGET_SPIRV
} SummitSlangTargetKind;

typedef enum {
    SUMMIT_SLANG_STAGE_VERTEX,
    SUMMIT_SLANG_STAGE_FRAGMENT,
    SUMMIT_SLANG_STAGE_COMPUTE
} SummitSlangStageKind;

typedef const char* (*SummitSlangVfsLookupFn)(void* userData, const char* path, size_t* outSize);

SummitSlangCompilerHandle slang_compiler_create();
void slang_compiler_destroy(SummitSlangCompilerHandle compiler);

SummitSlangCompileResult slang_compile_stage(SummitSlangCompilerHandle compiler, void* vfs, const char* module_name, const char* source, const char* entry_point, SummitSlangStageKind stage, SummitSlangTargetKind target);
void slang_free_result(SummitSlangCompileResult result);

void* slang_vfs_create(SummitSlangVfsLookupFn lookupFn, void* userData);
void slang_vfs_destroy(void* vfs);

#ifdef __cplusplus
}
#endif