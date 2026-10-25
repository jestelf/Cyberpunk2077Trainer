# Адаптивный автодрайв / Adaptive autodrive

**Русский** · [English](#english)

Откройте **Транспорт → Профили и расчёты автодрайва**, выберите профиль, нажмите «Применить профиль», затем G в игре. Штатный режим сохраняет параметры игры. Усиленные профили используют отдельный предел до **300 км/ч**; ручной редактор машины его не повышает.

| Профиль | Предлагаемый максимум, км/ч | Номинальное замедление, м/с² | Реакция с задержкой опроса, с | Запас, м | Боковое ускорение, м/с² |
|---|---:|---:|---:|---:|---:|
| Штатный | По правилам игры | По правилам игры | По правилам игры | По правилам игры | По правилам игры |
| Спокойный | 120 | 3,0 | 1,55 | 12 | 1,8 |
| Дорожный | 180 | 3,5 | 1,45 | 16 | 2,2 |
| Быстрый | 240 | 4,0 | 1,35 | 20 | 2,6 |
| Максимальный | 300 | 4,0 | 1,35 | 25 | 2,8 |

Потолок усиленного профиля можно выбрать от 60 до 300; «Штатный» — отдельный вариант без переопределения. Это предел настройки, а не минимальная фактическая скорость: перед препятствием машина должна замедляться вплоть до остановки.

Используется `v = км/ч ÷ 3,6` и дистанция `d = v × t + v² ÷ (2 × a) + запас`. Допустимая скорость по известной дистанции находится обратной формулой. Для поворота — `v ≤ √(боковое ускорение × радиус)`. В редакторе есть обе таблицы.

Пример номинального расчёта для профиля «Максимальный»:

| Скорость, км/ч | Остановка с реакцией и запасом, м | Горизонт штатного ИИ, м |
|---:|---:|---:|
| 60 | 83 | 120 |
| 120 | 209 | 262 |
| 180 | 405 | 507 |
| 240 | 671 | 839 |
| 250 | 722 | 902 |
| 300 | 1006 | 1257 |

Перед быстрым разгоном выполняется короткая проверка штатных тормозов на прямом устойчивом участке. Расчёт использует не более 60% измеренного замедления и не более номинала профиля. Если проверка не состоялась или тормоза слабы, высокая скорость не разрешается. После замедлений оценка может снижаться. Более слабое торможение увеличивает нужную дистанцию и уменьшает допустимую скорость.

Для текущей личной машины создаются отдельные копии профиля ИИ, его обзора и оценки поворотов. Дальность обзора увеличивается по тормозному пути; штатные системы ограничения скорости по обстановке остаются включёнными. Общие исходные профили, физика шин, мощность двигателя, тормозной PID и настройки обычных NPC не меняются. Ускорение ограничивается плавным ростом потолка. При превышении рассчитанной скорости запрашиваются штатные полные тормоза короткими импульсами до 0,22 с; искусственные физические толчки не применяются.

Дополнительный контроллер проверяет образцы опоры через 12 м, до 1152 м, препятствия тремя лучами, текущий поворот, занос и расстояние до цели. Максимум — 99 пространственных запросов за такт 0,1 с. При неизвестной опоре, недоступных датчиках или пропуске такта скорость уменьшается. Пустое пространство без подтверждённой опоры не считается свободной дорогой. Лучи и текущая кривизна дополняют штатное прогнозирование дороги; они не описывают все будущие события или форму дороги между образцами.

Статус показывает **реальный действующий потолок**, причину ограничения, расчётное замедление, путь остановки и расстояние до проверенной опоры. Выбранные 300 не означают постоянную езду с 300: город, повороты, слабые тормоза или неподгруженный район ограничат скорость ниже.

Смена настроек или отключение завершает текущую усиленную поездку и восстанавливает исходную ссылку профиля; G запускает новую. Короткий уже отправленный запрос торможения истекает сам. Чужие изменения не перезаписываются; конфликт блокирует усиление. Свободная езда без цели и такси Деламейна остаются штатными. Новая логика проверена локальными моделями и компиляцией; результаты поездок в игре оценивает владелец.

## English

Open **Vehicles → Autodrive profiles and calculations**, choose a profile, apply it, then press G in game. Native keeps game settings. Enhanced modes use an independent ceiling up to **300 km/h**; the manual vehicle editor cannot raise it.

| Profile | Suggested ceiling, km/h | Nominal deceleration, m/s² | Reaction incl. polling allowance, s | Reserve, m | Lateral acceleration, m/s² |
|---|---:|---:|---:|---:|---:|
| Native | Game rules | Game rules | Game rules | Game rules | Game rules |
| Relaxed | 120 | 3.0 | 1.55 | 12 | 1.8 |
| Road | 180 | 3.5 | 1.45 | 16 | 2.2 |
| Fast | 240 | 4.0 | 1.35 | 20 | 2.6 |
| Maximum | 300 | 4.0 | 1.35 | 25 | 2.8 |

Enhanced ceilings are adjustable from60 to300; Native is a separate option without an override. This is a settings range, not a minimum actual driving speed: the car must be able to slow to a stop.

With `v = km/h ÷ 3.6`, stopping distance is `d = v × t + v² ÷ (2 × a) + reserve`. The inverse gives a speed ceiling for available distance. Cornering uses `v ≤ √(lateral acceleration × radius)`. Both tables are in the editor; the example table above is the Maximum profile, with distance/lookahead in metres.

A brief native-brake check on a stable straight section precedes fast acceleration. Planning uses no more than60% of measured deceleration and no more than the profile nominal value. Failed/weak calibration never unlocks high speeds. Later braking can lower the estimate. Weaker brakes increase required distance and reduce allowed speed.

The current owned vehicle receives private copies of its AI profile, vision and cornering estimate. Lookahead grows with stopping distance; native situational speed safety remains enabled. Shared originals, tire physics, engine power, brake PID and ordinary NPC settings remain unchanged. The ceiling ramps up gradually. Overspeed requests short native full-brake pulses, at most0.22s; no artificial physical impulses are applied.

Additional checks sample support every12m, up to1152m, cast three obstacle rays, and consider current curvature, slip and destination distance. At most99 spatial queries per0.1s tick. Unknown ground, missing sensors and timing gaps reduce speed. An empty ray without verified ground is not treated as an open road. Rays/current curvature supplement native road prediction; they do not model every future event or road shape between samples.

Live status shows the **effective ceiling**, limiting reason, planning deceleration, stopping distance and sampled support range. Selecting300 does not force constant300: city streets, bends, weak brakes or unloaded areas lower it.

Changing settings/disabling ends the enhanced trip and restores the original profile reference; G starts another trip. An already issued short brake request expires naturally. External edits are preserved and conflicts block enhancement. Destination-free roaming and Delamain remain native. New logic is locally fixture/compile-tested; the owner evaluates actual driving results.
