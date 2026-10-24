#pragma once
#include <Windows.h>
#include <bcrypt.h>
#include <array>
#include <string>
#include <vector>
#include <stdexcept>
#include "Local25Addresses.h"
#pragma comment(lib, "bcrypt.lib")

namespace CETLocal25
{
inline constexpr std::array<unsigned char, 32> ExeHash = {
    0xd3,0x6e,0x74,0xc4,0x75,0x92,0xe9,0xc6,0x56,0xae,0x25,0x00,0x78,0xcb,0x40,0xb2,
    0xbe,0x63,0xc7,0x82,0xaf,0x5b,0xfb,0xef,0xf2,0x28,0x0d,0x43,0xe6,0x53,0xfa,0xb4
};

inline bool VerifyFile(const wchar_t* path)
{
    HANDLE file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, nullptr);
    if (file == INVALID_HANDLE_VALUE) return false;
    BCRYPT_ALG_HANDLE algorithm = nullptr;
    BCRYPT_HASH_HANDLE hash = nullptr;
    std::array<unsigned char, 32> digest{};
    bool valid = BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) >= 0;
    if (valid) valid = BCryptCreateHash(algorithm, &hash, nullptr, 0, nullptr, 0, 0) >= 0;
    std::array<unsigned char, 65536> buffer{};
    DWORD size = 0;
    while (valid)
    {
        if (!ReadFile(file, buffer.data(), static_cast<DWORD>(buffer.size()), &size, nullptr)) { valid = false; break; }
        if (!size) break;
        valid = BCryptHashData(hash, buffer.data(), size, 0) >= 0;
    }
    if (valid) valid = BCryptFinishHash(hash, digest.data(), static_cast<ULONG>(digest.size()), 0) >= 0;
    if (hash) BCryptDestroyHash(hash);
    if (algorithm) BCryptCloseAlgorithmProvider(algorithm, 0);
    CloseHandle(file);
    return valid && digest == ExeHash;
}

inline bool IsVerifiedBuild()
{
    static const bool result = [] {
        const auto base = reinterpret_cast<const unsigned char*>(GetModuleHandleW(nullptr));
        const auto dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(base);
        if (dos->e_magic != IMAGE_DOS_SIGNATURE) return false;
        const auto pe = reinterpret_cast<const IMAGE_NT_HEADERS64*>(base + dos->e_lfanew);
        if (pe->Signature != IMAGE_NT_SIGNATURE || pe->FileHeader.TimeDateStamp != 0x6ad55daf ||
            pe->OptionalHeader.SizeOfImage != 0x0581b000) return false;
        std::array<wchar_t, 32768> path{};
        const auto count = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
        return count > 0 && count < path.size() && VerifyFile(path.data());
    }();
    return result;
}

inline uintptr_t Resolve(uint32_t hash)
{
    size_t lo = 0, hi = std::size(Addresses);
    while (lo < hi)
    {
        const auto mid = lo + (hi - lo) / 2;
        if (Addresses[mid].hash < hash) lo = mid + 1;
        else hi = mid;
    }
    if (lo == std::size(Addresses) || Addresses[lo].hash != hash) return 0;
    return reinterpret_cast<uintptr_t>(GetModuleHandleW(nullptr)) + Addresses[lo].rva;
}
}
