# Verification / Проверки — 0.3.20

**Русский** · [English](#english)

На 25.10.2026 владелец подтвердил, что основные существующие функции работают, а устаревшие пометки «не проверено» уже не соответствуют опыту использования. Они заменены описаниями с сохранением конкретных ограничений. Последний отчёт касается далёких приземлений телепорта и медленного штатного автодрайва. Новые изменения 0.3.20 ещё ожидают обратной связи в игре.

Локально: C#/C++, 14 REDscript — 0 ошибок/предупреждений; 297 проверок LuaJIT-диспетчера; 28 контроллера перемещения, включая дальние маршруты, неверный этаж, далёкую безопасную площадку и движение маркера; 16 ультра автодрайва, включая единицы скорости, маршрут, изменение предела, отключение/восстановление и исключение чужого ИИ/такси/сцен; каталог из собственной игры — страницы/дубли/ошибки/кеш; 7 проверок полного пакета установщика; RU/EN. Игровые API, физика и стриминг имитируются. Предыдущие проверки транспорта, полиции и геометрии сохранены в истории исследования.

Публичная подготовка: отдельное чистое дерево, сборка C#/C++, сканирование EXE/DLL, предпросмотр RU/EN, отсутствие игровых картинок/архивов и личных путей. Каталог читается из собственной игры и сохраняется локально; новое живое чтение ещё ожидает проверки владельцем. В PE зависимостей удалены диагностические пути и CodeView без изменения исполняемых секций. Патчи CET и обоих SDK проверены применением к точным исходникам upstream. CET остаётся экспериментальной адаптацией для точного EXE. Игра не запускалась.

## English

On 2026-10-25 the owner confirmed the main existing features work and obsolete untested labels no longer reflect their experience. They were replaced with useful descriptions while retaining concrete limits. Latest reports concern distant teleport landings and slow native autodrive. New 0.3.20 changes still await gameplay feedback.

Local checks: C#/C++; 14 REDscript files with zero errors/warnings; 297 LuaJIT dispatcher checks; 28 travel-controller fixtures including streaming routes, wrong floors, distant safe landings and moving markers; 16 autodrive fixtures including units, destination, live limit, disable/restore and unrelated AI/taxi/scene exclusions; catalog pagination/deduplication/errors/cache; 7 full-package installer checks; RU/EN. Native APIs, physics and streaming are mocked. Earlier vehicle/police/geometry results remain in research history.

Public preparation covers an isolated clean tree, fresh builds, binary scans and RU/EN previews. No game artwork/archives or personal paths. The catalog reads the user's game locally; this new path is fixture-tested pending owner feedback. Dependency diagnostic paths/CodeView are removed without changing executable sections. CET/SDK patches apply to exact upstream sources. CET remains an experimental exact-build adaptation. The game was not launched.
