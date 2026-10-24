#pragma once
#include <windows.h>
#include <cstring>
#include <RED4ext/RED4ext.hpp>

namespace ckappearance25 {
inline uintptr_t base = 0;
inline bool available = false;
using GenderSetter = void (*)(void*, bool);
inline bool Signature(uintptr_t rva, const char* bytes, size_t length) {
    return std::memcmp(reinterpret_cast<void*>(base + rva), bytes, length) == 0;
}
inline void Lock(volatile char* lock) {
    while (_InterlockedCompareExchange8(lock, -1, 0) != 0) YieldProcessor();
}
inline void Unlock(volatile char* lock) { _InterlockedExchange8(lock, 0); }
struct FinalizedScope {
    unsigned char* state;
    explicit FinalizedScope(unsigned char* value) : state(value) {
        Lock(reinterpret_cast<volatile char*>(state + 0x40));
        state[0x41] = 0;
        Unlock(reinterpret_cast<volatile char*>(state + 0x40));
    }
    ~FinalizedScope() {
        Lock(reinterpret_cast<volatile char*>(state + 0x40));
        state[0x41] = 1;
        Unlock(reinterpret_cast<volatile char*>(state + 0x40));
    }
};
inline bool ChangeState(void* object, bool body, bool male, GenderSetter setter, uintptr_t expectedVtable) {
    if (!object || !setter || *static_cast<uintptr_t*>(object) != expectedVtable) return false;
    auto* state = static_cast<unsigned char*>(object);
    if (state[0x41] != 1 || state[0x42] != 1 || state[0x44] > 1 || state[0x45] > 1) return false;
    if (state[body ? 0x44 : 0x45] == static_cast<unsigned char>(male)) return true;
    {
        FinalizedScope scope(state);
        setter(object, male);
    }
    return state[0x41] == 1 && state[body ? 0x44 : 0x45] == static_cast<unsigned char>(male);
}
inline bool Change(void* object, bool body, bool male) {
    return available && ChangeState(object, body, male,
        reinterpret_cast<GenderSetter>(base + (body ? 0x2d90104 : 0x2d901b4)), base + 0x324eb28);
}
inline void EditGender(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, bool* out, int64_t) {
    RED4ext::Handle<RED4ext::IScriptable> state;
    bool body = false, male = false;
    RED4ext::GetParameter(frame, &state);
    RED4ext::GetParameter(frame, &body);
    RED4ext::GetParameter(frame, &male);
    frame->code++;
    bool result = Change(state.GetPtr(), body, male);
    if (out) *out = result;
}
inline void Register() {
    base = reinterpret_cast<uintptr_t>(GetModuleHandleW(nullptr));
    available = base
        && Signature(0x153087b, "\xc7\x41\x40\x00\x00\x00\x01", 7)
        && Signature(0x2d9012e, "\x40\x38\x73\x41\x75\x0d", 6)
        && Signature(0x2d90134, "\x40\x38\x7b\x44\x74\x07\x40\x88\x7b\x44", 10)
        && Signature(0x2d901de, "\x40\x38\x73\x41\x75\x0d", 6)
        && Signature(0x2d901e4, "\x40\x38\x7b\x45\x74\x07\x40\x88\x7b\x45", 10)
        && Signature(0x75b31f, "\x8a\x43\x41", 3)
        && Signature(0x75b2f3, "\x8a\x43\x42", 3);
    auto* function = RED4ext::CGlobalFunction::Create("CK_AppearanceGender", "CK_AppearanceGender", &EditGender);
    function->flags.isNative = true;
    function->flags.isStatic = true;
    function->AddParam("handle:gameuiICharacterCustomizationState", "state");
    function->AddParam("Bool", "body");
    function->AddParam("Bool", "male");
    function->SetReturnType("Bool");
    RED4ext::CRTTISystem::Get()->RegisterFunction(function);
}
}
