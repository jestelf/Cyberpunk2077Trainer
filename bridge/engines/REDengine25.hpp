#pragma once
#include <RED4ext/Callback.hpp>
#include <cstddef>
#include <filesystem>
#include <fstream>

namespace ckred {
inline void Trace25(const char* stage) {
    wchar_t profile[32768]{};
    const auto length = GetEnvironmentVariableW(L"LOCALAPPDATA", profile, 32768);
    if (!length || length >= 32768) return;
    const auto folder = std::filesystem::path(profile) / L"Cyberpunk2077Trainer";
    std::error_code error;
    std::filesystem::create_directories(folder, error);
    if (error) return;
    std::ofstream log(folder / L"bridge-startup.log", std::ios::app);
    SYSTEMTIME now{}; GetSystemTime(&now);
    log << now.wYear << '-' << now.wMonth << '-' << now.wDay << ' '
        << now.wHour << ':' << now.wMinute << ':' << now.wSecond << " UTC " << stage << '\n';
}
using RTTICallback25 = RED4ext::Callback<void (*)(), 64>;
static_assert(sizeof(RTTICallback25) == 0x48);
static_assert(offsetof(RTTICallback25, handler) == 0x40);

inline void QueuePostRegister25(void* system, void (*callback)()) {
    using Register = void (*)(void*, RTTICallback25);
    const auto table = *reinterpret_cast<void***>(system);
    const auto add = reinterpret_cast<Register>(table[0xC8 / sizeof(void*)]);
    add(system, RTTICallback25(callback));
}
}
