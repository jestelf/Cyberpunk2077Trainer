#pragma once
#include <windows.h>
#include <atomic>
#include <cstring>
#include <RED4ext/RED4ext.hpp>
#include <RED4ext/Scripting/Natives/Generated/game/ui/CharactersChain.hpp>
#include <RED4ext/Scripting/Natives/Generated/game/ui/UnlockableProgram.hpp>

namespace ckbreach25 {
using Tick = void (*)(void*, void*);
using Finish = void (*)(void*);
using SetState = void (*)(void*, int32_t);
inline Tick originalTick = nullptr;
inline Finish originalClose = nullptr;
inline Finish showFinish = nullptr;
inline SetState setState = nullptr, setReason = nullptr;
inline std::atomic<bool> available = false, autoWin = false, freeze = false;
inline std::atomic<uint64_t> configuredAt = 0;
inline std::atomic<uintptr_t> active = 0, requested = 0;
inline uintptr_t base = 0;
constexpr uintptr_t tickRva = 0x2d67cb4, closeRva = 0x2d65d98;

template<class T> inline T& Field(void* object, size_t offset) {
    return *reinterpret_cast<T*>(static_cast<unsigned char*>(object) + offset);
}
inline bool Ready(void* object) {
    if (!Field<uint8_t>(object, 0x1f9) || Field<uint8_t>(object, 0x1fd) || !Field<void*>(object, 0x218)) return false;
    auto& programs = Field<RED4ext::DynArray<RED4ext::game::ui::UnlockableProgram>>(object, 0xf0);
    auto& chains = Field<RED4ext::DynArray<RED4ext::game::ui::CharactersChain>>(object, 0x100);
    return programs.Size() > 0 && programs.Size() <= 64 && programs.Size() <= programs.Capacity() && programs.Data()
        && chains.Size() > 0 && chains.Size() <= 64 && chains.Size() <= chains.Capacity() && chains.Data();
}
inline bool Complete(void* object) {
    if (!Ready(object) || !setState || !setReason || !showFinish) return false;
    auto& programs = Field<RED4ext::DynArray<RED4ext::game::ui::UnlockableProgram>>(object, 0xf0);
    auto& chains = Field<RED4ext::DynArray<RED4ext::game::ui::CharactersChain>>(object, 0x100);
    for (auto& chain : chains) {
        if (chain.rarities.Size() == 0 || chain.rarities.Size() > 128 || chain.ownerId < 0 || static_cast<uint32_t>(chain.ownerId) >= programs.Size()) return false;
    }
    for (auto& program : programs) program.isFulfilled = true;
    for (auto& chain : chains) {
        chain.matchedValues = chain.rarities.Size();
        chain.isFulfilled = true;
        chain.isPossible = true;
    }
    setState(object, 4);
    setReason(object, 4);
    showFinish(object);
    return true;
}
inline void Clear(void* object) {
    uintptr_t expected = reinterpret_cast<uintptr_t>(object);
    active.compare_exchange_strong(expected, 0);
    expected = reinterpret_cast<uintptr_t>(object);
    requested.compare_exchange_strong(expected, 0);
}
inline void OnTick(void* object, void* delta) {
    if (!Ready(object)) { Clear(object); originalTick(object, delta); return; }
    const auto identity = reinterpret_cast<uintptr_t>(object);
    active = identity;
    bool fresh = GetTickCount64() - configuredAt.load() < 2000;
    bool manual = requested.exchange(0) == identity;
    if ((manual || (fresh && autoWin.load())) && Complete(object)) { Clear(object); return; }
    if (fresh && freeze.load()) {
        float zero = 0.0f;
        float* zeroRef = &zero;
        originalTick(object, &zeroRef);
    } else originalTick(object, delta);
    if (!Field<uint8_t>(object, 0x1f9)) Clear(object);
}
inline void OnClose(void* object) { Clear(object); originalClose(object); }
inline void Reset() { autoWin = false; freeze = false; configuredAt = 0; requested = 0; }
inline void Configure(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, bool* out, int64_t) {
    bool automatic = false, paused = false;
    RED4ext::GetParameter(frame, &automatic); RED4ext::GetParameter(frame, &paused); frame->code++;
    autoWin = automatic; freeze = paused; configuredAt = GetTickCount64();
    if (out) *out = available;
}
inline void Request(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, int32_t* out, int64_t) {
    frame->code++;
    auto object = active.load();
    int32_t result = !available ? -1 : object ? 1 : 0;
    if (result == 1) requested = object;
    if (out) *out = result;
}
inline void Cancel(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, void*, int64_t) { frame->code++; Reset(); }
inline void Register() {
    auto rtti = RED4ext::CRTTISystem::Get();
    auto configure = RED4ext::CGlobalFunction::Create("CK_BreachConfigure", "CK_BreachConfigure", &Configure);
    configure->flags.isNative = true; configure->flags.isStatic = true;
    configure->AddParam("Bool", "automatic"); configure->AddParam("Bool", "paused"); configure->SetReturnType("Bool"); rtti->RegisterFunction(configure);
    auto request = RED4ext::CGlobalFunction::Create("CK_BreachComplete", "CK_BreachComplete", &Request);
    request->flags.isNative = true; request->flags.isStatic = true; request->SetReturnType("Int32"); rtti->RegisterFunction(request);
    auto cancel = RED4ext::CGlobalFunction::Create("CK_BreachReset", "CK_BreachReset", &Cancel);
    cancel->flags.isNative = true; cancel->flags.isStatic = true; rtti->RegisterFunction(cancel);
}
inline bool Signature(uintptr_t rva, const char* bytes, size_t length) { return std::memcmp(reinterpret_cast<void*>(base + rva), bytes, length) == 0; }
inline bool Install(RED4ext::v1::PluginHandle handle, const RED4ext::v1::Sdk* sdk) {
    base = reinterpret_cast<uintptr_t>(GetModuleHandleW(nullptr));
    if (!sdk || !sdk->hooking || !base
        || !Signature(tickRva, "\x48\x89\x5c\x24\x08\x57\x48\x83\xec\x60\x80\xb9\xf9\x01\x00\x00\x00", 17)
        || !Signature(closeRva, "\x48\x89\x74\x24\x10\x48\x89\x7c\x24\x18\x55\x41\x56\x41\x57", 15)
        || !Signature(0x2d66168, "\x40\x53\x48\x83\xec\x30\x80\xb9\xfd\x01\x00\x00\x00", 13)
        || !Signature(0x2d67814, "\x48\x83\xec\x38\x48\x8b\x81\x20\x02\x00\x00", 11)
        || !Signature(0x2d67880, "\x48\x83\xec\x38\x48\x8b\x81\x20\x02\x00\x00", 11)) return false;
    setState = reinterpret_cast<SetState>(base + 0x2d67814);
    setReason = reinterpret_cast<SetState>(base + 0x2d67880);
    showFinish = reinterpret_cast<Finish>(base + 0x2d66168);
    if (!sdk->hooking->Attach(handle, reinterpret_cast<void*>(base + closeRva), reinterpret_cast<void*>(&OnClose), reinterpret_cast<void**>(&originalClose))) return false;
    if (!sdk->hooking->Attach(handle, reinterpret_cast<void*>(base + tickRva), reinterpret_cast<void*>(&OnTick), reinterpret_cast<void**>(&originalTick))) {
        sdk->hooking->Detach(handle, reinterpret_cast<void*>(base + closeRva)); return false;
    }
    available = true;
    return true;
}
inline void Uninstall(RED4ext::v1::PluginHandle handle, const RED4ext::v1::Sdk* sdk) {
    Reset();
    if (available.exchange(false) && sdk && sdk->hooking) {
        sdk->hooking->Detach(handle, reinterpret_cast<void*>(base + tickRva));
        sdk->hooking->Detach(handle, reinterpret_cast<void*>(base + closeRva));
    }
    active = 0;
}
}
