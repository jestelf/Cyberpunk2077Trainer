# CET 1.37.1 → experimental Steam 2.5 adaptation

**Русский** · [English](#english)

Это не официальный выпуск CET. Только точный EXE из корневого README. Основа CET: `81d097e249d4f92665df2d46df5c05ed282419c9`; SDK-субмодуль: `a0776d41359fe1ba01705fd97835018c56aee69b`. `cet.patch`, `sdk.patch` и три `Local25*.h` содержат изменения. Сохранены лицензии upstream; применяются к полученному исходному дереву, а не к установленной игре.

Изменения: таблица адресов с проверкой хеша EXE, callback ABI, создание функций RTTI, аргументы загрузки TweakDB, renderer/singleton, расположение GameFramework и ожидание/обновление GameInstance. Четыре неразрешённых адреса SDK и совместимость произвольных сторонних CET-модов не подтверждены. Не используйте эту адаптацию для другой сборки.

Получение и сборка (Git, MSVC 2022, Windows SDK, xmake 3.1+):

```powershell
powershell -ExecutionPolicy Bypass -File ports/cet25/Get-Source.ps1
cd deps/cet25
xmake f -m release
xmake -y
```

Upstream xmake получает свои открытые зависимости. Комплектный ASI построен из этих изменений; перед публичным распространением `tools/clean_pe_paths.py` удаляет CodeView и заменяет абсолютные пути в диагностических строках именами файлов, сохраняя размер и исполняемые секции. Это не побитовая воспроизводимость: версии разрешаемых xmake зависимостей могут отличаться. Не подменяйте комплектный runtime частичной сборкой без проверки.

Отдельный SDK моста: `ports/Get-BridgeSdk.ps1`, upstream `f9ad5334362a8a0815baf58f47615697485feb52` плюс `ports/bridge-sdk.patch`. Он не взаимозаменяем со старым SDK-субмодулем CET.

## English

This is not an official CET release. It targets only the exact EXE in the root README. CET base: `81d097e249d4f92665df2d46df5c05ed282419c9`; SDK submodule: `a0776d41359fe1ba01705fd97835018c56aee69b`. Apply `cet.patch`, `sdk.patch` and three `Local25*.h` additions to the fetched source, not to the installed game. Upstream licenses are preserved.

Changes cover hash-gated addresses, callback ABI, RTTI function construction, TweakDB loading arguments, renderer/singleton access, GameFramework offsets and GameInstance readiness/refresh. Four unresolved SDK addresses and general third-party CET mod compatibility remain unverified. Never use with another game build.

Use the commands above with Git, MSVC 2022/Windows SDK and xmake 3.1+. Upstream xmake fetches its open-source dependencies. The bundled ASI uses these source changes; `tools/clean_pe_paths.py` removes CodeView metadata and shortens absolute diagnostic paths before redistribution, preserving size and executable sections. Builds are not guaranteed bit-identical because xmake dependency resolutions can differ. Do not replace the runtime with a partial build without validation.

The separate bridge SDK is fetched by `ports/Get-BridgeSdk.ps1`: upstream `f9ad5334362a8a0815baf58f47615697485feb52` with `ports/bridge-sdk.patch`. It is not interchangeable with CET's older SDK submodule.
