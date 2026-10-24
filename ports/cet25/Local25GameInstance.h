#pragma once
#include <RED4ext/GameEngine.hpp>

namespace CETLocal25 {
static_assert(offsetof(RED4ext::CGameEngine, framework) == 0x348);
static_assert(offsetof(RED4ext::CGameEngine::CGameFramework, gameInstance) == 0x10);
static_assert(sizeof(RED4ext::CGameEngine) == 0x390);

template<class Engine>
auto ReadGameInstance(Engine* engine) -> decltype(engine->framework->gameInstance) {
    if (!engine || !engine->framework) return nullptr;
    return engine->framework->gameInstance;
}

inline RED4ext::GameInstance* TryGetGameInstance() {
    return ReadGameInstance(RED4ext::CGameEngine::Get());
}
}
