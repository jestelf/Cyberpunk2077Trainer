#pragma once
#include <windows.h>
#include <bcrypt.h>
#include <RED4ext/RED4ext.hpp>
#include <atomic>
#include <condition_variable>
#include <fstream>
#include <mutex>
#include <string>
#include <thread>
#pragma comment(lib, "bcrypt.lib")
#pragma comment(lib, "user32.lib")

namespace ckred {
struct Request {
    uint64_t id = 0;
    std::string command, answer;
    enum Phase { Idle, Queued, Dispatched, Replied } phase = Idle;
};
inline std::mutex gate;
inline std::condition_variable changed;
inline Request request;
inline std::atomic<bool> stopping = false;
inline std::thread worker;
inline bool resetNeeded = true;
inline uint64_t nextId = 0;
inline HANDLE activePipe = INVALID_HANDLE_VALUE;

inline bool VerifyBuild(const char* expectedHash, DWORD stamp, DWORD image) {
    auto module = reinterpret_cast<const unsigned char*>(GetModuleHandleW(nullptr));
    if (!module) return false;
    auto dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(module);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) return false;
    auto nt = reinterpret_cast<const IMAGE_NT_HEADERS64*>(module + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE || nt->FileHeader.TimeDateStamp != stamp ||
        nt->OptionalHeader.SizeOfImage != image) return false;
    wchar_t path[32768];
    if (!GetModuleFileNameW(nullptr, path, 32768)) return false;
    HANDLE file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING, 0, nullptr);
    if (file == INVALID_HANDLE_VALUE) return false;
    BCRYPT_ALG_HANDLE alg = nullptr;
    BCRYPT_HASH_HANDLE hash = nullptr;
    bool success = false;
    if (BCryptOpenAlgorithmProvider(&alg, BCRYPT_SHA256_ALGORITHM, nullptr, 0) == 0 &&
        BCryptCreateHash(alg, &hash, nullptr, 0, nullptr, 0, 0) == 0) {
        unsigned char buffer[65536], digest[32]; DWORD read = 0; bool valid = true;
        for (;;) {
            if (!ReadFile(file, buffer, sizeof(buffer), &read, nullptr)) { valid = false; break; }
            if (!read) break;
            if (BCryptHashData(hash, buffer, read, 0) != 0) { valid = false; break; }
        }
        if (valid && BCryptFinishHash(hash, digest, 32, 0) == 0) {
            const char* hex = "0123456789abcdef"; std::string actual;
            for (auto byte : digest) { actual += hex[byte >> 4]; actual += hex[byte & 15]; }
            success = actual == expectedHash;
        }
    }
    if (hash) BCryptDestroyHash(hash);
    if (alg) BCryptCloseAlgorithmProvider(alg, 0);
    CloseHandle(file);
    return success;
}

inline bool Io(HANDLE pipe, bool write, void* data, DWORD size, DWORD& count, DWORD timeout) {
    OVERLAPPED ov{}; ov.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (!ov.hEvent) return false;
    BOOL ok = write ? WriteFile(pipe, data, size, &count, &ov) : ReadFile(pipe, data, size, &count, &ov);
    if (!ok && GetLastError() == ERROR_IO_PENDING) {
        auto waited = WaitForSingleObject(ov.hEvent, timeout);
        if (waited == WAIT_OBJECT_0) ok = GetOverlappedResult(pipe, &ov, &count, FALSE);
        else { CancelIoEx(pipe, &ov); GetOverlappedResult(pipe, &ov, &count, TRUE); ok = FALSE; }
    }
    CloseHandle(ov.hEvent);
    return ok != FALSE;
}

inline void Serve(const wchar_t* name) {
    HANDLE pipe = CreateNamedPipeW(name, PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED | FILE_FLAG_FIRST_PIPE_INSTANCE,
            PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS, 1, 65536, 65536, 0, nullptr);
    if (pipe == INVALID_HANDLE_VALUE) return;
    { std::lock_guard lock(gate); activePipe = pipe; }
    while (!stopping) {
        OVERLAPPED ov{}; ov.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
        if (!ov.hEvent) break;
        BOOL connected = ConnectNamedPipe(pipe, &ov);
        if (!connected) {
            auto error = GetLastError();
            if (error == ERROR_PIPE_CONNECTED) connected = TRUE;
            else if (error == ERROR_IO_PENDING) {
                while (!stopping && WaitForSingleObject(ov.hEvent, 200) == WAIT_TIMEOUT) {}
                DWORD count = 0;
                if (stopping) CancelIoEx(pipe, &ov);
                connected = GetOverlappedResult(pipe, &ov, &count, TRUE);
            }
        }
        CloseHandle(ov.hEvent);
        if (connected && !stopping) {
            { std::lock_guard lock(gate); resetNeeded = true; request = {}; }
            while (!stopping) {
                char input[8192]; DWORD count = 0;
                if (!Io(pipe, false, input, sizeof(input), count, 4000) || !count) break;
                std::string command(input, count), answer;
                if (command.find_first_of("\r\n\0", 0, 3) != std::string::npos) break;
                {
                    std::unique_lock lock(gate);
                    request = {}; request.id = ++nextId; request.command = command; request.phase = Request::Queued;
                    if (!changed.wait_for(lock, std::chrono::seconds(3), [] { return stopping || request.phase == Request::Replied; })) {
                        answer = request.phase == Request::Queued ? "err E_TIMEOUT_CANCELLED" : "err E_TIMEOUT_UNKNOWN";
                        request = {}; resetNeeded = true;
                    } else { answer = request.answer; request = {}; }
                }
                if (stopping) break;
                if (!Io(pipe, true, answer.data(), static_cast<DWORD>(answer.size()), count, 1000)) break;
                if (answer.rfind("err E_TIMEOUT", 0) == 0) break;
            }
        }
        { std::lock_guard lock(gate); resetNeeded = true; request = {}; }
        DisconnectNamedPipe(pipe);
    }
    { std::lock_guard lock(gate); activePipe = INVALID_HANDLE_VALUE; }
    CloseHandle(pipe);
}

inline std::string Take() {
    std::string value;
    { std::lock_guard lock(gate);
      if (resetNeeded) { value = "0|reset"; resetNeeded = false; }
      else if (request.phase == Request::Queued) { request.phase = Request::Dispatched; value = std::to_string(request.id) + "|" + request.command; }
    }
    return value;
}
inline void Complete(const std::string& text) {
    auto separator = text.find('|');
    if (separator == std::string::npos) return;
    uint64_t id = 0; try { id = std::stoull(text.substr(0, separator)); } catch (...) { return; }
    std::lock_guard lock(gate);
    if (request.phase != Request::Dispatched || request.id != id) return;
    request.answer = text.substr(separator + 1); request.phase = Request::Replied; changed.notify_one();
}
inline void Poll(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, RED4ext::CString* out, int64_t) {
    frame->code++; auto value = Take();
    if (out) *out = RED4ext::CString(value.c_str());
}
inline void Reply(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, void*, int64_t) {
    RED4ext::CString value; RED4ext::GetParameter(frame, &value); frame->code++;
    Complete(value.c_str());
}
inline void Key(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, bool* out, int64_t) {
    int32_t key = 0; RED4ext::GetParameter(frame, &key); frame->code++;
    DWORD pid = 0; GetWindowThreadProcessId(GetForegroundWindow(), &pid);
    if (out) *out = key > 0 && key < 256 && pid == GetCurrentProcessId() && (GetAsyncKeyState(key) & 0x8000) != 0;
}

inline void InjectKey(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, bool* out, int64_t) {
    int32_t scan = 0, mode = 0; RED4ext::GetParameter(frame, &scan); RED4ext::GetParameter(frame, &mode); frame->code++;
    DWORD pid = 0; GetWindowThreadProcessId(GetForegroundWindow(), &pid);
    bool sent = false;
    if (scan > 0 && scan < 0x80 && pid == GetCurrentProcessId()) {
        INPUT input{}; input.type = INPUT_KEYBOARD; input.ki.wScan = static_cast<WORD>(scan);
        input.ki.dwFlags = KEYEVENTF_SCANCODE | ((mode & 1) ? KEYEVENTF_EXTENDEDKEY : 0) | ((mode & 2) ? KEYEVENTF_KEYUP : 0);
        sent = SendInput(1, &input, sizeof(INPUT)) == 1;
    }
    if (out) *out = sent;
}
inline void Register() {
    auto rtti = RED4ext::CRTTISystem::Get();
    auto poll = RED4ext::CGlobalFunction::Create("CK_Poll", "CK_Poll", &Poll);
    poll->flags.isNative = true; poll->flags.isStatic = true;
    poll->SetReturnType("String"); rtti->RegisterFunction(poll);
    auto reply = RED4ext::CGlobalFunction::Create("CK_Reply", "CK_Reply", &Reply);
    reply->flags.isNative = true; reply->flags.isStatic = true;
    reply->AddParam("String", "value"); rtti->RegisterFunction(reply);
    auto key = RED4ext::CGlobalFunction::Create("CK_Key", "CK_Key", &Key);
    key->flags.isNative = true; key->flags.isStatic = true;
    key->AddParam("Int32", "key"); key->SetReturnType("Bool"); rtti->RegisterFunction(key);
    auto inject = RED4ext::CGlobalFunction::Create("CK_InjectKey", "CK_InjectKey", &InjectKey);
    inject->flags.isNative = true; inject->flags.isStatic = true;
    inject->AddParam("Int32", "scan"); inject->AddParam("Int32", "mode"); inject->SetReturnType("Bool"); rtti->RegisterFunction(inject);
}
inline void Start(const wchar_t* pipe) { stopping = false; worker = std::thread(Serve, pipe); }
inline void Stop() {
    stopping = true; changed.notify_all();
    { std::lock_guard lock(gate); if (activePipe != INVALID_HANDLE_VALUE) CancelIoEx(activePipe, nullptr); }
    if (worker.joinable()) worker.join();
}
}
