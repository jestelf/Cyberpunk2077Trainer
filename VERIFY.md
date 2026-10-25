# Verification / Проверки — 0.3.21

**Русский** · [English](#english)

Владелец подтвердил основные существующие функции. Его замечание к0.3.20: поднятый потолок автодрайва не сопровождался адаптацией торможения. В0.3.21 это отдельная система профилей, прогноза и проверки тормозов. Устаревшие пометки на существующих функциях не возвращались. Новую систему реальных поездок ещё оценивает владелец.

Локально проверены:

- C#/C++ и16 REDscript:0 ошибок и предупреждений компилятора скриптов.
- 297 прежних +12 новых проверок диспетчера: профиль0–4, целочисленный режим, предел60–300, запрос статуса, включение/отключение.
- 142 проверки математической модели: монотонность тормозного пути, обратная формула скорости, более слабые тормоза, повороты и штатный профиль без переопределения.
- 21 проверка нативного адаптера: контекст текущего водителя, маршрут, восстановление, чужие изменения, предел300, независимость от ручных600 и устаревшие данные.
- 19 проверок CET-конфигурации: отдельные копии, исходные общие профили не меняются, смена настроек, проверки чтения, ошибки клонирования/привязки, конфликт и откат.
- Сценарии полного контроллера: калибровка,500 шагов разгона с проверками потолка и бюджета запросов, препятствие, слабые тормоза, опора/промежуточный разрыв, поворот, воздух, пауза, пропуск такта, недоступный датчик, некорректные числа, завершение поездки и отсутствие подготовленной конфигурации.
- Каталог предметов,28 сценариев прежнего перемещения и5 выбора цели;7 проверок полного установочного пакета.
- RU/EN:5 профилей, штатный режим,300 максимум, таблицы, порядок применения команд, перевод статуса и узкое окно.

Всё перечисленное про игровые API выполняется с имитацией Native AI, TweakDB, тормозов, физики и стриминга. Это не подтверждение поездок на300 и не доказательство отсутствия любых столкновений. Фактическая производительность расширенного обзора и нативное поведение клонированных профилей требуют обратной связи владельца.

Реверс: прочитаны точные классы2.5, нативные регистрации методов и профили TweakDB. У исходного профиля автодрайва обнаружены vision.maxDistance=13, minDistance=7, maxStraightPathExtension=10, speedLimitDeceleration=7, обе системы безопасного ограничения включены. Существующие записи сохраняются; привязываются отдельные копии для текущей личной машины. PID тормозов, физика шин, мощность двигателя и обычные NPC не меняются. Усиление не применяет физические толчки. Формулы и пределы: [docs/autodrive.md](docs/autodrive.md).

Публичная подготовка сохраняет лицензии, RU/EN, сканирование EXE/DLL и точную проверку EXE игры. Нет игровых картинок, архивов озвучки/локализации, сохранений или личных путей. CET — прежняя экспериментальная адаптация для точной2.5, не новый официальный выпуск. Игра и рабочий трейнер не запускаются автоматически; установленный результат проверяется по манифесту/резервным копиям.

## English

The owner confirmed the main existing features. Their concern with0.3.20 was that a raised ceiling did not adapt braking. Version0.3.21 adds separate profiles, prediction and brake checking. Obsolete labels on existing features remain replaced with useful descriptions. Actual driving of the new system still awaits owner feedback.

Local checks: C#/C++,16 REDscript files with no compiler errors/warnings;297 existing plus12 new dispatcher cases;142 model properties;21 native-adapter/ownership cases;19 CET configuration/rollback cases; full-controller scenarios including500 acceleration steps with ceiling/query-budget bounds, calibration, obstacles, weak brakes, support/gaps, cornering, airborne/menu/timing/sensor/invalid-data cases and release. Catalog checks,28 travel and5 target-selection regressions;7 full-package installer cases; RU/EN and narrow editor layout with5 profiles, native behavior,300 bound, tables, command order and translated status.

Native AI,TweakDB,brakes,physics and streaming are mocked in fixtures. This does not confirm real300km/h trips or prove collision-free driving. Native clone/rebind behavior and performance of extended vision need owner feedback.

Read-only research inspected exact2.5 scripts, native method registration and TweakDB policies. The source autodrive policy has vision.maxDistance13,minDistance7,straight extension10,speedLimitDeceleration7 and both safety systems enabled. Originals are retained; scoped copies bind to the current owned vehicle. Brake PID,tire physics,engine power and ordinary NPCs are unchanged; no artificial physical impulses. [Model details](docs/autodrive.md).

Public preparation retains licenses,RU/EN,binary scans and exact game-EXE gating. No game artwork,dubbing/localization archives,saves or personal paths. CET remains the prior experimental exact2.5 adaptation,not an official new release. The game/working trainer are not launched automatically; installation is verified against manifests/backups.
