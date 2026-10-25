#include "engines/REDengine.hpp"
#include "engines/REDengine25.hpp"
#include "engines/REDengineBreach25.hpp"
#include "engines/REDengineAppearance25.hpp"

static void Register25() {
    ckred::Trace25("0.3.20 RTTI registration started");
    ckred::Register();
    ckbreach25::Register();
    ckappearance25::Register();
    ckred::Trace25(ckappearance25::available ? "Native appearance gender handler available" : "Native appearance gender handler unavailable; disabled");
    ckred::Trace25("0.3.20 RTTI registration completed");
}

RED4EXT_C_EXPORT bool RED4EXT_CALL Main(RED4ext::v1::PluginHandle handle, RED4ext::v1::EMainReason reason, const RED4ext::v1::Sdk* sdk) {
    if (reason == RED4ext::v1::EMainReason::Load) {
        ckred::Trace25("0.3.20 plugin load started");
        if (!ckred::VerifyBuild("d36e74c47592e9c656ae250078cb40b2be63c782af5bfbeff2280d43e653fab4", 0x6ad55daf, 0x0581b000)) return false;
        ckred::Trace25("0.3.20 exact build verified");
        ckred::Trace25(ckbreach25::Install(handle, sdk) ? "Native breach hooks installed" : "Native breach hooks unavailable; disabled");
        ckred::QueuePostRegister25(RED4ext::CRTTISystem::Get(), Register25);
        ckred::Trace25("0.3.20 callback queued with 64-byte inline buffer");
        ckred::Start(L"\\\\.\\pipe\\Cyberpunk2077CheatKit");
        ckred::Trace25("0.3.20 pipe thread started");
    } else if (reason == RED4ext::v1::EMainReason::Unload) { ckbreach25::Uninstall(handle, sdk); ckred::Stop(); }
    return true;
}
RED4EXT_C_EXPORT void RED4EXT_CALL Query(RED4ext::v1::PluginInfo* info) {
    info->name = L"CheatKit Cyberpunk 2077"; info->author = L"jestelf";
    info->version = RED4EXT_V1_SEMVER(0, 3, 20); info->runtime = RED4EXT_V1_FILEVER(3, 0, 88, 46235);
    info->sdk = RED4EXT_V1_SDK_VERSION_CURRENT;
}
RED4EXT_C_EXPORT uint32_t RED4EXT_CALL Supports() { return RED4EXT_API_VERSION_1; }
