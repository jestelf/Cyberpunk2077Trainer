# Verification / Проверки — 0.3.19

**Русский** · [English](#english)

Владелец проверял настройку машин в 0.3.18. После его отчёта исправлены мотоциклы, прижим и резкие коррекции; добавлены восстановление транспорта, игнорирование полицией и асинхронный перенос. Последняя 0.3.19 пока не подтверждена владельцем в игре. Релиз экспериментальный.

До публичной подготовки: 13 REDscript — 0 ошибок/предупреждений; 297 проверок LuaJIT-диспетчера; 56 расчётов транспорта/повреждений; 23 восстановления; 26 полиции; 23 контроллера перемещения; 34 защитных проверок; 12 геометрии; 7 проверок полного пакета установщика; RU/EN и узкие окна. Проверки имитируют игровые API: это не тест реальной физики, сцен или стриминга.

Публичная подготовка: чистое отдельное дерево, повторная сборка C#/C++, проверка EXE/DLL, предпросмотр RU/EN, отсутствие игровых картинок/архивов и личных путей. Каталог читается постранично из собственной игры и сохраняется в локальном профиле. Проверены ответы страниц, дубли, конец списка и ошибки на имитации API. CET очищен от путей сборки и CodeView-метаданных; исполняемые секции не изменялись. Рабочая установка игры не менялась и игра не запускалась.

## English

The owner tested car tuning in 0.3.18. Subsequent fixes add motorcycle support, remove constant downforce, bound corrections, and add vehicle recovery, police ignore and asynchronous travel. The final 0.3.19 is not yet owner-confirmed in gameplay. This is experimental.

Before public preparation: 13 REDscript files with zero errors/warnings; 297 LuaJIT dispatcher checks; 56 vehicle/damage calculations; 23 recovery; 26 police; 23 travel-controller; 34 gameplay guards; 12 geometry; 7 full-package installer checks; RU/EN and narrow layouts. Fixtures mock game APIs and do not validate actual physics, scenes or streaming.

Public preparation covers a clean isolated tree, fresh C#/C++ build, binary scans, RU/EN previews, no bundled game artwork/archives or personal paths. A paginated catalog reads the user's own game and caches locally. Page responses, duplicates, completion and errors are fixture-tested. CET build paths and CodeView metadata are removed without changes to executable sections. The installed game is unchanged and was not launched.
