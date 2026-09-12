// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

#include "slang.h"
#include <slang.h>
#include <slang-com-ptr.h>
#include <string>
#include <vector>

using Slang::ComPtr;

static SlangCompileTarget toSlangFormat(CrystalSlangTargetKind kind) {
    switch (kind) {
        case CRYSTAL_SLANG_TARGET_HLSL: return SLANG_HLSL;
        case CRYSTAL_SLANG_TARGET_GLSL: return SLANG_GLSL;
        case CRYSTAL_SLANG_TARGET_SPIRV: return SLANG_SPIRV;
    }

    return SLANG_HLSL;
}

static const char* profileForTarget(CrystalSlangTargetKind kind) {
    switch (kind) {
        case CRYSTAL_SLANG_TARGET_HLSL: return "sm_6_0";
        case CRYSTAL_SLANG_TARGET_GLSL: return "glsl_450";
        case CRYSTAL_SLANG_TARGET_SPIRV: return "sm_6_0";
    }

    return "sm_6_0";
}

// Compiler

struct CrystalSlangCompilerContext {
    ComPtr<slang::IGlobalSession> globalSession;
};

CrystalSlangCompilerHandle slang_compiler_create() {
    CrystalSlangCompilerHandle compiler = new CrystalSlangCompilerContext();
    slang::createGlobalSession(compiler->globalSession.writeRef());

    return compiler;
}

void slang_compiler_destroy(CrystalSlangCompilerHandle compiler) {
    delete static_cast<CrystalSlangCompilerContext*>(compiler);
}

CrystalSlangCompileResult slang_compile_stage(CrystalSlangCompilerHandle compiler, void* vfs, const char* module_name, const char* source, const char* entry_point, CrystalSlangStageKind stage, CrystalSlangTargetKind target) {
    CrystalSlangCompileResult result = {};

    slang::TargetDesc targetDesc = {};
    targetDesc.format = toSlangFormat(target);
    targetDesc.profile = compiler->globalSession->findProfile(profileForTarget(target));

    slang::SessionDesc sessionDesc = {};
    sessionDesc.targets = &targetDesc;
    sessionDesc.targetCount = 1;
    sessionDesc.fileSystem = static_cast<ISlangFileSystem*>(vfs);

    ComPtr<slang::ISession> session;
    compiler->globalSession->createSession(sessionDesc, session.writeRef());

    ComPtr<slang::IBlob> diagnostics;
    auto fileName = std::string(module_name) + ".slang";

    slang::IModule* module = session->loadModuleFromSourceString(module_name, fileName.c_str(), source, diagnostics.writeRef());

    if (!module) {
        result.error_message = strdup(diagnostics ? (const char*)diagnostics->getBufferPointer() : "unknown module load error");
        return result;
    }

    ComPtr<slang::IEntryPoint> entrypointObj;
    module->findEntryPointByName(entry_point, entrypointObj.writeRef());
    if (!entrypointObj) {
        result.error_message = strdup("entry point not found");
        return result;
    }

    slang::IComponentType* components[] = { module, entrypointObj };
    ComPtr<slang::IComponentType> program;
    session->createCompositeComponentType(components, 2, program.writeRef(), diagnostics.writeRef());

    ComPtr<slang::IComponentType> linkedProgram;
    program->link(linkedProgram.writeRef(), diagnostics.writeRef());
    if (!linkedProgram) {
        result.error_message = strdup(diagnostics ? (const char*)diagnostics->getBufferPointer() : "link failed");
        return result;
    }

    ComPtr<slang::IBlob> code;
    linkedProgram->getEntryPointCode(0, 0, code.writeRef(), diagnostics.writeRef());
    if (!code) {
        result.error_message = strdup(diagnostics ? (const char*)diagnostics->getBufferPointer() : "codegen failed");
        return result;
    }

    size_t size = code->getBufferSize();
    void* dataCopy = malloc(size);
    memcpy(dataCopy, code->getBufferPointer(), size);

    result.code_data = dataCopy;
    result.code_size = size;
    return result;
}

void slang_free_result(CrystalSlangCompileResult result) {
    if (result.code_data) free(const_cast<void*>(result.code_data));
    if (result.error_message) free(const_cast<char*>(const_cast<char*>(result.error_message)));
}

// VFS

class RawBlob : public ISlangBlob {
public:
    RawBlob(const void* data, size_t size) : m_refCount(1) {
        m_data.resize(size);
        memcpy(m_data.data(), data, size);
    }

    SLANG_NO_THROW SlangResult SLANG_MCALL queryInterface(SlangUUID const& uuid, void** outObject) override {
        if (uuid == ISlangUnknown::getTypeGuid() || uuid == ISlangBlob::getTypeGuid()) {
            *outObject = static_cast<ISlangBlob*>(this);
            addRef();
            return SLANG_OK;
        }
        return SLANG_E_NO_INTERFACE;
    }
    SLANG_NO_THROW uint32_t SLANG_MCALL addRef() override { return ++m_refCount; }
    SLANG_NO_THROW uint32_t SLANG_MCALL release() override {
        uint32_t r = --m_refCount;
        if (r == 0) delete this;
        return r;
    }

    SLANG_NO_THROW void const* SLANG_MCALL getBufferPointer() override { return m_data.data(); }
    SLANG_NO_THROW size_t SLANG_MCALL getBufferSize() override { return m_data.size(); }

private:
    std::vector<uint8_t> m_data;
    uint32_t m_refCount;
};

class EmbeddedFS : public ISlangFileSystem {
public:
    EmbeddedFS(CrystalSlangVfsLookupFn lookupFn, void* userdata)
        : m_lookupFn(lookupFn), m_userdata(userdata), m_refcount(1) {}

    SLANG_NO_THROW SlangResult SLANG_MCALL queryInterface(SlangUUID const& uuid, void** outObject) override {
        if (uuid == ISlangUnknown::getTypeGuid() || uuid == ISlangFileSystem::getTypeGuid()) {
            *outObject = static_cast<ISlangFileSystem*>(this);
            addRef();

            return SLANG_OK;
        }

        return SLANG_E_NO_INTERFACE;
    }

    SLANG_NO_THROW uint32_t SLANG_MCALL addRef() override { return ++m_refcount; }
    SLANG_NO_THROW uint32_t SLANG_MCALL release() override {
        uint32_t r = --m_refcount;
        if (r == 0) delete this;
        return r;
    }

    SLANG_NO_THROW void* SLANG_MCALL castAs(const SlangUUID& guid) override { return nullptr; }

    SLANG_NO_THROW SlangResult SLANG_MCALL loadFile(
        char const* path, ISlangBlob** outBlob
    ) override {
        size_t size = 0;
        const char* data = m_lookupFn(m_userdata, path, &size);
        if (!data) return SLANG_E_NOT_FOUND;

        *outBlob = new RawBlob(data, size);
        return SLANG_OK;
    }
private:
    CrystalSlangVfsLookupFn m_lookupFn;
    void* m_userdata;
    uint32_t m_refcount;
};

void* slang_vfs_create(CrystalSlangVfsLookupFn lookupFn, void* userData) {
    return new EmbeddedFS(lookupFn, userData);
}

void slang_vfs_destroy(void* vfs) {
    static_cast<EmbeddedFS*>(vfs)->release();
}
