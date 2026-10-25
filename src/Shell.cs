using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Media;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

sealed class FeatureMemory {
 readonly object gate=new object();readonly string path;readonly HashSet<string> keys;readonly Dictionary<string,decimal[]> limits=new Dictionary<string,decimal[]>();
 readonly HashSet<string> enabled=new HashSet<string>();readonly Dictionary<string,string> parameters=new Dictionary<string,string>();readonly HashSet<string> applied=new HashSet<string>();
 public FeatureMemory(string file,IEnumerable<string> toggles,string[,] ranges){
  path=file;keys=new HashSet<string>(toggles);for(int i=0;i<ranges.GetLength(0);i++)limits[ranges[i,0]]=new[]{decimal.Parse(ranges[i,1],System.Globalization.CultureInfo.InvariantCulture),decimal.Parse(ranges[i,2],System.Globalization.CultureInfo.InvariantCulture)};
  if(File.Exists(path))foreach(string line in File.ReadAllLines(path,Encoding.UTF8))Read(line);
 }
 bool Read(string command){
  var p=command.Split(' ');if(p.Length!=3)return false;
  if(p[0]=="set" && keys.Contains(p[1]) && (p[2]=="0" || p[2]=="1")){if(p[2]=="1")enabled.Add(p[1]);else enabled.Remove(p[1]);return true;}
  decimal value;decimal[] range;if(p[0]!="mul" || !limits.TryGetValue(p[1],out range) || !decimal.TryParse(p[2],System.Globalization.NumberStyles.Float,System.Globalization.CultureInfo.InvariantCulture,out value) || value<range[0] || value>range[1])return false;
  parameters[p[1]]=value.ToString(System.Globalization.CultureInfo.InvariantCulture);return true;
 }
 public bool Wants(string key){lock(gate)return enabled.Contains(key);}
 public int Count{get{lock(gate)return enabled.Count;}}
 public void Reconnect(){lock(gate)applied.Clear();}
 public string[] Pending(){lock(gate)return parameters.OrderBy(p=>p.Key,StringComparer.Ordinal).Select(p=>"mul "+p.Key+" "+p.Value).Concat(enabled.OrderBy(k=>k,StringComparer.Ordinal).Select(k=>"set "+k+" 1")).Where(c=>!applied.Contains(c)).ToArray();}
 public bool StillPending(string command){lock(gate)return Pending().Contains(command);}
 public void Remember(string command,string answer){
  if(answer!="ok")return;lock(gate){
   if(command=="reset"){enabled.Clear();parameters.Clear();applied.Clear();}
   else {if(!Read(command))return;var p=command.Split(' ');applied.RemoveWhere(c=>c.StartsWith(p[0]+" "+p[1]+" ",StringComparison.Ordinal));applied.Add(command);}
   Write();
  }
 }
 void Write(){
  Directory.CreateDirectory(Path.GetDirectoryName(path));string temp=path+".new";
  var lines=parameters.OrderBy(p=>p.Key,StringComparer.Ordinal).Select(p=>"mul "+p.Key+" "+p.Value).Concat(enabled.OrderBy(k=>k,StringComparer.Ordinal).Select(k=>"set "+k+" 1"));
  File.WriteAllLines(temp,lines.ToArray(),new UTF8Encoding(false));if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);
 }
}

sealed class Cheat {
 public readonly string Key,TitleRu,TitleEn,DescRu,DescEn,Hotkey;public bool Active,Pending,Remembered;
 public Cheat(string key,string titleRu,string titleEn,string descRu,string descEn,string hotkey=null){Key=key;TitleRu=titleRu;TitleEn=titleEn;DescRu=descRu;DescEn=descEn;Hotkey=hotkey;}
 public string Title{get{return L.En?TitleEn:TitleRu;}}
 public string Desc{get{return L.En?DescEn:DescRu;}}
}
sealed class Param {
 public readonly string Key,Ru,En;public readonly float[] Steps;public readonly int Default;
 public Param(string key,string ru,string en,float[] steps,int def){Key=key;Ru=ru;En=en;Steps=steps;Default=def;}
}
sealed class ActionDef {
 public readonly string Ru,En,DoneRu,DoneEn,Command,Hotkey;
 public ActionDef(string ru,string en,string doneRu,string doneEn,string command,string hotkey=null){Ru=ru;En=en;DoneRu=doneRu;DoneEn=doneEn;Command=command;Hotkey=hotkey;}
}

static class L {
 public static bool En;
 public static event Action Changed;
 public static void Notify(){if(Changed!=null)Changed();}
 static readonly Dictionary<string,string> Map=new Dictionary<string,string>{
  {"ПЕРЕКЛЮЧАТЕЛЕЙ","TOGGLES"},{"Ctrl + F12 — отключить все читы","Ctrl + F12 — turn every cheat off"},{"○ Игра не подключена","○ Game not connected"},
  {"Отключить всё  ·  Ctrl+F12","Turn all off  ·  Ctrl+F12"},{"Меняются на лету, в том числе при включённой функции","Change on the fly, even while the function is on"},
  {"Разовые действия — выданное остаётся в сохранении","One-time actions — what you get stays in the save"},
  {"Журнал","Log"},{"Справка","Help"},{"Звук переключений","Toggle sounds"},{"Горячие клавиши","Hotkeys"},
  {"Игра не запущена","Game is not running"},{"Запустите игру. Трейнер подключится автоматически.","Start the game. The trainer connects automatically."},
  {"Подключение…","Connecting…"},{"Активно: ","Active: "},{" из "," of "},{"● Подключено · PID ","● Connected · PID "},
  {"Восстанавливаю значения игры…","Restoring game values…"},{"Трейнер закрыт · значения игры восстановлены","Trainer closed · game values restored"},
  {"Игра закрыта · ожидание запуска","Game closed · waiting for launch"},{"Игра закрыта — читы будут включены снова при следующем подключении","Game closed — cheats will be turned back on at the next connection"},
  {"Подключено · PID ","Connected · PID "},{" · мост загружен"," · bridge loaded"},{"Не включено снова: ","Not turned back on: "},{"Повторно включено: ","Turned back on: "},
  {"Связь: ","Link: "},{"Связь с игрой потеряна · переподключение","Lost the link to the game · reconnecting"},{"Игра не подключена","Game not connected"},
  {"включено","on"},{"выключено","off"},{"Не выполнено: ","Failed: "},{"Все функции уже выключены","Every function is already off"},{"Все функции выключены","Every function is off"},
  {"Отключение: ","Turning off: "},{"Для этого действия нужна запущенная игра","This action needs the running game"},{"Параметр: ","Parameter: "},
  {"Запуск · PID ","Started · PID "},{"Горячая клавиша занята: ","Hotkey is taken: "},{"Ctrl + F12 занята другим приложением","Ctrl + F12 is taken by another application"},
  {"без клавиши","no key"},{" (занята)"," (taken)"},{"Язык: русский","Language: English"},{"ВКЛ","ON"},{"ВЫКЛ","OFF"},{"Сеанс ","Session "},
  {" · журнал"," · log"},{" · справка"," · help"},{" уже запущен."," is already running."},{": ошибка",": error"},
  {"Игра загружается…","Game is loading…"},{"Не удалось загрузить мост в игру","Could not load the bridge into the game"},
  {"Нет доступа к процессу игры (запустите трейнер от имени администратора)","No access to the game process (run the trainer as administrator)"},
  {"Запущено несколько копий игры — оставьте одну","Several copies of the game are running — keep one"},
  {"Мост закрыл канал","The bridge closed the channel"},{"Мост отключён","Bridge disconnected"},{"Чтение памяти игры не выполнено","Reading game memory failed"},
  {"Горячие клавиши (работают и в игре):","Hotkeys (work in game too):"},{"Отключить всё","Turn all off"},
  {"Журнал и настройки: ","Log and settings: "},{"Закрытие трейнера выключает все функции и возвращает исходные значения.","Closing the trainer turns every function off and restores the original values."}
 };
 static readonly string[][] Frag={
  new[]{"Другая версия игры (","Different game version ("},new[]{"Мост не отвечает: ","Bridge does not respond: "},new[]{"Ошибка подключения: ","Connection error: "},
  new[]{"перехват не установлен (другая версия игры)","hook not installed (different game version)"},new[]{"игра не ответила (пауза или загрузка)","the game did not answer (pause or loading)"},
  new[]{"сбой при выполнении (команда отменена)","execution failed (command cancelled)"},new[]{"нет игрока (загрузите сохранение)","no player (load a save)"},
  new[]{"нет игрока","no player"},new[]{"нет оружия","no weapon equipped"},new[]{"запись памяти не выполнена","writing game memory failed"},new[]{"неизвестная функция ","unknown function "},new[]{"неизвестное действие ","unknown action "},
  new[]{"неизвестная команда","unknown command"},new[]{"неизвестный параметр ","unknown parameter "},new[]{"значение","value"},new[]{"исключение","exception"},
  new[]{Game.VersionHintRu,Game.VersionHintEn}
 };
 public static string T(string s){if(!En || s==null)return s;string e;return Map.TryGetValue(s,out e)?e:s;}
 static readonly string[][] Protocol={
  new[]{"E_STAMINA_LOADING","Пул выносливости ещё не зарегистрирован: дождитесь полной загрузки персонажа","Stamina pool not registered yet: wait for the character to finish loading"},
  new[]{"E_GOD_APPLY","Не удалось применить защиту от урона","Could not apply damage protection"},
  new[]{"E_AMMO_COST","Не удалось отключить стоимость патрона; функция не включена","Could not disable ammo cost; feature not enabled"},
  new[]{"E_NO_SAFE_LANDING","Вокруг цели не найдена загруженная поверхность с местом для Ви","No loaded surface with room for V was found around the destination"},
  new[]{"E_BLACKWALL_TARGET","Наведитесь на живого враждебного NPC не дальше 60 м","Aim at a live hostile NPC within 60 m"},
  new[]{"E_BLACKWALL_EQUIP","Штатный режим чёрного заслона ещё не экипирован; проверьте оружейный слот","Native Blackwall mode is not equipped yet; check the weapon slot"},
  new[]{"E_FLIGHT_PHYSICS","Игровой обработчик движения отклонил изменение физики полёта","Game movement handler rejected the flight physics change"},
  new[]{"E_BLACKWALL_HANDS","Не удалось освободить руки для способности Сойки","Could not free both hands for Songbird's power"},
  new[]{"E_MAGAZINE_BYPASS","Штатный обход магазина недоступен в этой сессии","Native magazine bypass is unavailable in this session"},
  new[]{"E_NO_STAMINA_POOL","Запас выносливости недоступен или его максимум равен нулю; проверьте диагностику","Stamina pool unavailable or maximum is zero; check diagnostics"},
  new[]{"E_NO_PLAYER","Нет активного игрока: загрузите сохранение","No active player: load a save"},
  new[]{"E_PLAYER_DETACHED","Игрок ещё не присоединён к миру: дождитесь окончания загрузки","Player is not attached to the world yet: wait for loading to finish"},
  new[]{"E_SESSION_LOADING","Игровой сеанс ещё загружается: дождитесь появления персонажа","The game session is still loading: wait for the character to appear"},
  new[]{"E_NO_STATE","Игрок найден, но система CheatKit не создана: перезапустите игру после обновления мода","Player found, but the CheatKit system is missing: restart the game after updating the mod"},
  new[]{"E_VALUE","Недопустимое значение","Invalid value"},
  new[]{"E_REJECTED","Действие недоступно в текущем состоянии игры","Action unavailable in the current game state"},
  new[]{"E_NO_DEVELOPMENT","Данные развития персонажа недоступны","Character development data is unavailable"},
  new[]{"E_LEVEL_LIMIT","Уровень превышает доступный предел персонажа или навыка","Level exceeds the available character or skill cap"},
  new[]{"E_PERK_PARTIAL","Часть перков применена; некоторые недоступны для текущего персонажа","Some perks were applied; others are unavailable for this character"},
  new[]{"E_NO_WAYPOINT","Поставьте личный маркер на карте","Place a personal waypoint on the map"},
  new[]{"E_ENABLE_BLINK","Сначала включите режим блинка","Enable blink mode first"},
  new[]{"E_NO_SURFACE","По направлению перемещения не найдена поверхность","No surface was found in the travel direction"},
  new[]{"E_NO_QUEST_POSITION","У выбранной цели задания нет доступной позиции","The tracked objective has no available position"},
  new[]{"E_NO_QUEST","Сначала выберите отслеживаемое задание","Track a quest first"},
  new[]{"E_QUEST_NEARBY","Вы уже ближе 20 м к цели задания","You are already within 20 m of the objective"},
  new[]{"E_NO_MOVEMENT","Данные движения ещё недоступны: пройдите несколько шагов","Movement data is unavailable: walk a few steps"},
  new[]{"E_BLOCKED_DESTINATION","В месте назначения препятствие","The destination is obstructed"},
  new[]{"E_NO_VEHICLE","Сядьте в транспорт или посмотрите на машину/мотоцикл не дальше 12 м","Mount a vehicle or look at a car/motorcycle within 12 m"},
  new[]{"E_VEHICLE_SCENE","Транспорт занят другим водителем, сценой или автопилотом","Vehicle controlled by another driver, a scene or autopilot"},
  new[]{"E_VEHICLE_MOVING","Для переворота остановите транспорт: скорость должна быть ниже 5 км/ч","Stop before recovery: vehicle speed must be below 5 km/h"},
  new[]{"E_NO_SANDEVISTAN","Установите Сандевистан перед включением функции","Install a Sandevistan before enabling this feature"},
  new[]{"E_TRAVEL_BUSY","Перенос уже выполняется; дождитесь завершения или отмените его","Travel already in progress; wait or cancel it"},
  new[]{"E_EXIT_VEHICLE","Сначала выйдите из транспорта","Leave the vehicle first"},
  new[]{"E_TRAVEL_CONTEXT","Для переноса нужно быть пешком вне сцены/взаимодействия; выключите noclip","Travel requires being on foot outside scenes/workspots; disable noclip"},
  new[]{"TRAVEL_SEARCHING","Перенос: поиск площадки у цели","Travel: searching near destination"},
  new[]{"TRAVEL_LOADING","Перенос: подгрузка следующего участка","Travel: loading next area"},
  new[]{"TRAVEL_MOVING","Перенос: переход на проверенную площадку","Travel: moving to verified ground"},
  new[]{"TRAVEL_PAUSED","Перенос приостановлен: закройте игровое меню","Travel paused: close the game menu"},
  new[]{"TRAVEL_DONE","Перенос завершён","Travel completed"},
  new[]{"TRAVEL_CANCELLED","Перенос отменён","Travel cancelled"},
  new[]{"TRAVEL_TIMEOUT","Перенос остановлен по времени; Ви остался на последней площадке","Travel timed out; V remains at the last landing"},
  new[]{"TRAVEL_NO_ROUTE","Перенос остановлен: дальше нет проверенной опоры; Ви остался на последней площадке","Travel stopped: no verified ground ahead; V remains at the last landing"},
  new[]{"TRAVEL_NO_ARRIVAL","Перенос остановлен: игра не подтвердила прибытие","Travel stopped: game did not confirm arrival"},
  new[]{"TRAVEL_CONTEXT","Перенос остановлен: транспорт, сцена или noclip","Travel stopped: vehicle, scene or noclip"},
  new[]{"TRAVEL_HOPS","этапов","hops"},
  new[]{"TRAVEL_REQUEST","запрос","request"},
  new[]{"TRAVEL_METERS","м до цели","m to destination"},
  new[]{"TRAVEL_IDLE","Перенос не запущен","No travel in progress"},
  new[]{"AUTODRIVE_OFF","Ультра автодрайв выключен","Ultra autodrive is off"},
  new[]{"AUTODRIVE_WAIT_G","Ультра автодрайв: нажмите G для поездки к маркеру","Ultra autodrive: press G for a trip to the waypoint"},
  new[]{"AUTODRIVE_DESTINATION","Усиление действует на поездку к цели; свободная езда и такси используют штатный режим","Enhancement applies to destination trips; roaming and taxis keep native behavior"},
  new[]{"AUTODRIVE_ACTIVE","Предел скорости автодрайва применён:","Autodrive speed ceiling applied:"},
  new[]{"AUTODRIVE_WAIT_AI","Ожидание контроллера ИИ; задайте маршрут и перезапустите G","Waiting for the AI controller; set a route and restart G"},
  new[]{"AUTODRIVE_KMH","км/ч","km/h"},
  new[]{"E_AUTODRIVE_RESTORE","Не удалось восстановить настройки автодрайва; поездка остановлена","Could not restore autodrive settings; the trip was stopped"},
  new[]{"AD_CLEAR_DISTANCE","подтверждённый обзор:","verified lookahead:"},
  new[]{"AD_CONFIG_CONFLICT","Настройки автодрайва изменены другим модом; усиление снято","Autodrive settings changed by another mod; enhancement released"},
  new[]{"AD_CONFIG_ERROR","Настройки ИИ не применены; усиленный автодрайв заблокирован","AI configuration was not applied; enhanced autodrive is blocked"},
  new[]{"AD_WAIT_VEHICLE","Сядьте за руль личной машины с поддержкой автодрайва","Drive an owned vehicle with native autodrive support"},
  new[]{"AD_UNSUPPORTED","У этой машины нет доступного профиля ИИ автодрайва","This vehicle has no available native autodrive AI profile"},
  new[]{"AD_CALIBRATING","Проверка тормозов перед разгоном","Checking brakes before acceleration"},
  new[]{"AD_WEAK_BRAKES","Слабое торможение; быстрый разгон ограничен","Weak braking; high-speed acceleration restricted"},
  new[]{"AD_VISIBILITY","Скорость ограничена доступным обзором и опорой","Speed limited by available lookahead and ground"},
  new[]{"AD_OBSTACLE","Снижение скорости перед препятствием","Slowing for an obstacle"},
  new[]{"AD_DESTINATION","Торможение перед целью","Braking for destination"},
  new[]{"AD_UNSTABLE","Наклон или воздух; ускорение ограничено","Tilt or airborne; acceleration restricted"},
  new[]{"AD_TIMESTEP","Пауза расчёта; осторожная скорость","Controller timing gap; cautious speed"},
  new[]{"AD_SENSOR","Нет данных обзора; торможение","Sensor data unavailable; braking"},
  new[]{"AD_PAUSED","Пауза или игровое меню","Paused or game menu"},
  new[]{"AD_CURVE","Скорость ограничена поворотом","Speed limited by cornering"},
  new[]{"AD_SLIP","Боковой занос; скорость снижена","Lateral slip; reduced speed"},
  new[]{"AD_STOCK","Штатный автодрайв: параметры игры сохраняются","Native autodrive: game parameters preserved"},
  new[]{"AD_READY","Профиль ИИ подготовлен; нажмите G","AI profile prepared; press G"},
  new[]{"AD_CLEAR","Свободный участок; плавный разгон","Clear section; gradual acceleration"},
  new[]{"AD_WAIT","Ожидание поездки","Waiting for a trip"},
  new[]{"AD_BRAKE","расчётное торможение:","planning deceleration:"},
  new[]{"AD_STOP","путь остановки:","stopping distance:"},
  new[]{"AD_MPS2","м/с²","m/s²"},
  new[]{"AD_METERS","м","m"},
  new[]{"E_ENABLE_SANDEVISTAN","Сначала включите бесконечный Сандевистан","Enable infinite Sandevistan first"},
  new[]{"E_ENABLE_BLACKWALL","Сначала включите способность Сойки","Enable Songbird's ability first"},
  new[]{"E_NO_BLACKWALL","Способность Сойки отсутствует в данных игры","Songbird's ability is missing from the game data"},
  new[]{"E_ITEM_NOT_OWNED","Сначала получите или выдайте выбранный имплант","Acquire or spawn the selected cyberware first"},
  new[]{"E_NOT_CYBERWARE","Выбранный предмет не является киберимплантом","The selected item is not cyberware"},
  new[]{"E_ARM_CONFLICT","Оружие рук требует отдельного переключения; одновременная установка не поддержана","Arm weapons require separate switching; simultaneous installation is unsupported"},
  new[]{"E_HOLSTER_LEFT","Для силы Сойки сначала уберите оружие из левой руки","Holster the left-hand weapon before using Songbird's power"},
  new[]{"E_NO_EQUIP_AREA","Для импланта не найдена область установки","No equipment area was found for this cyberware"},
  new[]{"E_EXTRA_LIMIT","Достигнут предел 16 дополнительных имплантов","The limit of 16 extra implants has been reached"},
  new[]{"E_BREACH_NATIVE","Нативный модуль взлома недоступен: проверьте установку 0.3.13 и журнал загрузки моста","Native breach module unavailable: check the 0.3.13 installation and bridge startup log"},
  new[]{"E_RECIPES","Не удалось получить доступные рецепты крафта","Could not load available crafting recipes"},
  new[]{"E_APPEARANCE_BUSY","Редактор внешности уже открыт или открывается","The appearance editor is already open or opening"},
  new[]{"E_APPEARANCE_STATE","Для редактора выйдите из меню, диалога, боя, транспорта и брейнданса; отключите noclip","Leave menus, dialogue, combat, vehicles and braindance; disable noclip before opening the editor"},
  new[]{"E_APPEARANCE_MENU","Игровое меню не приняло запрос редактора; вернитесь к обычной игре и повторите","The game menu did not accept the editor request; return to normal gameplay and retry"},
  new[]{"E_APPEARANCE_GENDER","Штатный обработчик не принял смену тела или голоса; проверьте комплект файлов 0.3.18","The native handler rejected the body or voice change; check the 0.3.18 package files"},
  new[]{"E_CYBER_SLOTS_STATE","Меняйте слоты вне боя и сюжетной сцены, управляя обычным Ви","Edit slots outside combat and story scenes while controlling normal V"},
  new[]{"E_CYBER_SLOTS_MENU","Закройте игровые меню, задайте число слотов и заново откройте импланты","Close game menus, set the slot count, then reopen cyberware"},
  new[]{"E_CYBER_SLOTS_AREA","Для этой части тела дополнительные слоты не поддерживаются; доступно до 8 слотов","Extra slots are unsupported for this body area; up to 8 slots are supported"},
  new[]{"E_CYBER_SLOTS_MIN","Число слотов не может быть меньше штатного; 0 возвращает штатное число","Slot count cannot be below the native count; 0 restores the native count"},
  new[]{"E_CYBER_SLOTS_OCCUPIED","Сначала снимите импланты из удаляемых слотов","Unequip implants from slots being removed first"},
  new[]{"E_CYBER_SLOTS_FULL","Нет доступного дополнительного слота; предел — 8","No additional slot is available; the limit is 8"},
  new[]{"E_NO_OS_ABILITY","Установите Сандевистан или Берсерк в расширенные слоты ОС","Install Sandevistan or Berserk in expanded operating system slots"},
  new[]{"E_CAPACITY","Игра отклонила временное увеличение ёмкости имплантов","The game rejected the temporary cyberware capacity increase"},
  new[]{"E_NO_BREACH","Сначала откройте протокол взлома","Open a breach protocol first"},
  new[]{"E_BREACH_NOT_READY","Протокол ещё не сформировал программы: повторите после загрузки сетки","The breach programs are not ready: retry after the grid has loaded"},
  new[]{"E_BREACH_READ","Не удалось прочитать матрицу или демонов протокола; подробности в консоли CET","Could not read the breach matrix or daemons; see the CET console"},
  new[]{"E_BREACH_STARTED","Автовзлом работает только до первого выбранного кода: откройте протокол заново","Auto-breach only works before the first code is picked: reopen the protocol"},
  new[]{"E_BREACH_NO_SOLUTION","Буфера не хватает ни для одного демона","The buffer is too small for any daemon"},
  new[]{"E_EDIT_FAILED","Игра не подтвердила изменение значения","The game did not confirm the value change"},
  new[]{"E_ITEM_REJECTED","Игра отклонила выдачу выбранного предмета","The game rejected the selected item"},
  new[]{"E_EQUIP_FAILED","Не удалось установить дополнительный имплант","Could not install the extra cyberware"},
  new[]{"E_COMMAND","Неизвестная или повреждённая команда","Unknown or malformed command"},
  new[]{"E_SCRIPT","Ошибка игрового скрипта; действие могло выполниться частично","Game script error; the action may have partially completed"},
  new[]{"E_RUNTIME","Сбой игрового такта; отправлен сброс функций","Game update failed; function reset requested"},
  new[]{"E_TIMEOUT_CANCELLED","Время ожидания истекло; команда отменена до выполнения","Timed out; command cancelled before execution"},
  new[]{"E_TIMEOUT_UNKNOWN","Нет подтверждения; результат неизвестен. Проверьте игру перед повтором","No acknowledgement; outcome unknown. Check the game before retrying"}
 };
 public static string D(string s){if(String.IsNullOrEmpty(s))return s;foreach(var row in Protocol)s=s.Replace(row[0],row[En?2:1]);if(!En)return s;string e;if(Map.TryGetValue(s,out e))return e;foreach(var f in Frag)s=s.Replace(f[0],f[1]);return s;}
 public static string P(string ru,string en){return En?en:ru;}
 public static bool SystemRussian(){string n=System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName;return n=="ru"||n=="uk"||n=="be"||n=="kk";}
}

static class Skin {
 public static readonly Color BG=Color.FromArgb(17,16,15),Panel=Color.FromArgb(30,28,26),Text=Color.FromArgb(240,235,228),Muted=Color.FromArgb(158,150,142),
  Amber=Color.FromArgb(236,190,90),Off=Color.FromArgb(54,50,46),Red=Color.FromArgb(232,104,96),Hover=Color.FromArgb(40,37,34);
 public static Color Accent{get{return Game.Accent;}}
 public static Color AccentLight{get{return ControlPaint.Light(Game.Accent,0.3f);}}
 public static Label Label(string text,int size=10,Color? color=null,bool bold=false){return new Label{Text=text,ForeColor=color??Text,Font=new Font("Segoe UI",size,bold?FontStyle.Bold:FontStyle.Regular),AutoSize=false,BackColor=Color.Transparent,TextAlign=ContentAlignment.MiddleLeft,AutoEllipsis=true};}
 public static Button Button(string text,Action action,bool primary=false){var b=new ReadableButton{Text=text,FlatStyle=FlatStyle.Flat,BackColor=primary?Accent:Panel,ForeColor=primary?BG:Text,Font=new Font("Segoe UI",9.5f,FontStyle.Bold),Height=35,Cursor=Cursors.Hand,TabStop=true,AutoEllipsis=true};b.FlatAppearance.BorderSize=0;b.FlatAppearance.MouseOverBackColor=primary?AccentLight:Color.FromArgb(46,42,39);b.Click+=delegate{action();};return b;}
 public static void Form(Form f,string title,Size size){f.Text=title;f.ClientSize=size;f.BackColor=BG;f.ForeColor=Text;f.Font=new Font("Segoe UI",10);f.StartPosition=FormStartPosition.CenterParent;f.AutoScaleMode=AutoScaleMode.Dpi;}
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern IntPtr SendMessageW(IntPtr window,int message,IntPtr param,string text);
 public static void Cue(TextBox box,string text){box.AccessibleName=text;if(box.IsHandleCreated)SendMessageW(box.Handle,0x1501,new IntPtr(1),text);else box.HandleCreated+=delegate{SendMessageW(box.Handle,0x1501,new IntPtr(1),text);};}
}

sealed class ReadableButton : Button {
 protected override void OnPaint(PaintEventArgs e){if(Enabled){base.OnPaint(e);return;}e.Graphics.Clear(BackColor);TextRenderer.DrawText(e.Graphics,Text,Font,ClientRectangle,Skin.Muted,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis);}
}

static class Sounds {
 static SoundPlayer on,off;
 public static void Init(){on=new SoundPlayer(new MemoryStream(Wave(new[]{620.0,930.0})));off=new SoundPlayer(new MemoryStream(Wave(new[]{930.0,560.0})));on.Load();off.Load();}
 public static void Play(bool enabled){try{(enabled?on:off).Play();}catch{}}
 static byte[] Wave(double[] tones){
  const int rate=44100;int seg=rate*75/1000;int n=seg*tones.Length;var pcm=new short[n];
  for(int t=0;t<tones.Length;t++)for(int i=0;i<seg;i++){double env=Math.Min(1.0,i/(rate*0.006))*Math.Min(1.0,(seg-i)/(rate*0.018));double s=Math.Sin(2*Math.PI*tones[t]*i/rate)*0.75+Math.Sin(4*Math.PI*tones[t]*i/rate)*0.12;pcm[t*seg+i]=(short)(s*env*0.32*short.MaxValue);}
  var ms=new MemoryStream();var w=new BinaryWriter(ms);w.Write(Encoding.ASCII.GetBytes("RIFF"));w.Write(36+n*2);w.Write(Encoding.ASCII.GetBytes("WAVEfmt "));w.Write(16);w.Write((short)1);w.Write((short)1);w.Write(rate);w.Write(rate*2);w.Write((short)2);w.Write((short)16);w.Write(Encoding.ASCII.GetBytes("data"));w.Write(n*2);foreach(short s in pcm)w.Write(s);return ms.ToArray();
 }
}

sealed class CheatRow : Control {
 public Action EditBinding;bool keyboardActivate;
 Rectangle BindingRect{get{return new Rectangle(Width-215,14,135,30);}}
 public readonly Cheat Cheat;public readonly int Index;public string Hotkey="";public bool Available;
 public CheatRow(int index,Cheat cheat){Index=index;Cheat=cheat;SetStyle(ControlStyles.AllPaintingInWmPaint|ControlStyles.UserPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.Selectable,true);BackColor=Skin.Panel;Height=58;Margin=new Padding(4);Cursor=Cursors.Hand;TabStop=true;AccessibleName=cheat.Title;AccessibleRole=AccessibleRole.CheckButton;}
 protected override void OnPaint(PaintEventArgs e){
  var g=e.Graphics;g.Clear(BackColor);
  if(Cheat.Active)using(var b=new SolidBrush(Skin.Accent))g.FillRectangle(b,0,0,3,Height);
  int reserve=EditBinding==null?95:230;
  using(var f=new Font("Segoe UI",10,FontStyle.Bold))TextRenderer.DrawText(g,Cheat.Title,f,new Rectangle(14,7,Width-reserve,23),Available?Skin.Text:Skin.Muted,TextFormatFlags.EndEllipsis);
  using(var f=new Font("Segoe UI",8))TextRenderer.DrawText(g,(EditBinding==null && Hotkey!=""?Hotkey+"  ·  ":"")+Cheat.Desc,f,new Rectangle(14,32,Width-reserve,21),Skin.Muted,TextFormatFlags.EndEllipsis);
  if(EditBinding!=null){using(var b=new SolidBrush(Skin.Off))g.FillRectangle(b,BindingRect);using(var f=new Font("Segoe UI",9))TextRenderer.DrawText(g,String.IsNullOrEmpty(Hotkey)?L.P("Назначить","Assign"):Hotkey,f,BindingRect,Skin.Accent,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis);}
  Rectangle box=new Rectangle(Width-66,14,52,28);using(var b=new SolidBrush(Cheat.Pending||Cheat.Remembered?Skin.Amber:Cheat.Active?Skin.Accent:Skin.Off))g.FillRectangle(b,box);
  using(var f=new Font("Segoe UI",9,FontStyle.Bold))TextRenderer.DrawText(g,Cheat.Pending?"…":Cheat.Remembered?L.P("АВТО","AUTO"):L.T(Cheat.Active?"ВКЛ":"ВЫКЛ"),f,box,Cheat.Active||Cheat.Pending||Cheat.Remembered?Skin.BG:Skin.Muted,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);
  if(Focused)ControlPaint.DrawFocusRectangle(g,new Rectangle(2,2,Width-4,Height-4),Skin.Accent,BackColor);
 }
 protected override void OnMouseEnter(EventArgs e){BackColor=Skin.Hover;base.OnMouseEnter(e);}
 protected override void OnMouseLeave(EventArgs e){BackColor=Skin.Panel;base.OnMouseLeave(e);}
 protected override void OnClick(EventArgs e){if(!keyboardActivate && EditBinding!=null && BindingRect.Contains(PointToClient(Cursor.Position))){EditBinding();return;}if(Available && !Cheat.Pending)base.OnClick(e);}
 protected override void OnKeyDown(KeyEventArgs e){if(e.KeyCode==Keys.F2 && EditBinding!=null){EditBinding();e.Handled=true;}if(e.KeyCode==Keys.Space || e.KeyCode==Keys.Enter){keyboardActivate=true;try{OnClick(EventArgs.Empty);}finally{keyboardActivate=false;}e.Handled=true;}base.OnKeyDown(e);}
 protected override void OnResize(EventArgs e){base.OnResize(e);Invalidate();}
}

sealed class Trainer : Form {
 static readonly string User=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),Game.AppId);
 public static bool Preview;
 static int GridRows{get{return (Game.Cheats.Length+2)/2;}}
 readonly List<CheatRow> rows=new List<CheatRow>();readonly List<Button> actions=new List<Button>();readonly List<ComboBox> paramBoxes=new List<ComboBox>();readonly Dictionary<int,Action> hotkeys=new Dictionary<int,Action>();
 readonly System.Windows.Forms.Timer uiTimer=new System.Windows.Forms.Timer{Interval=500};readonly DateTime started=DateTime.Now;readonly List<string> events=new List<string>();
 readonly object sync=new object();GameLink link;string linkState="Игра не запущена";volatile bool closing,busy;Thread worker;int layoutHeight;
 readonly object commandSync=new object();FeatureMemory memory;
 BindingSet bindings;
 readonly Dictionary<string,Button> bindingLabels=new Dictionary<string,Button>();
 int selectedCategory;string featureSearch="";
 readonly ToolTip tips=new ToolTip{AutoPopDelay=20000};
 static bool CustomBindings{get{var f=typeof(Game).GetField("CustomBindings");return f!=null && (bool)f.GetValue(null);}}
 static string ResetCommand{get{var f=typeof(Game).GetField("ResetCommand");return f==null?null:(string)f.GetValue(null);}}
 static string ProgressCommand{get{var f=typeof(Game).GetField("ProgressCommand");return f==null?null:(string)f.GetValue(null);}}
 Label connection,metrics,lastEvent,runtime;CheckBox sound,keys;TextBox historyText;Form history;Button ruButton,enButton;

 public Trainer(){
  Skin.Form(this,Game.AppId.Replace("Trainer"," Trainer"),new Size(1000,800));MinimumSize=new Size(760,480);StartPosition=FormStartPosition.CenterScreen;AutoScroll=true;
  try{Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath);}catch{}
  L.En=!L.SystemRussian();bool snd=true,k=true;int[] values=Game.Params.Select(p=>p.Default).ToArray();LoadSettings(ref snd,ref k);
  Build(values,snd,k);FitToScreen();
  if(CustomBindings){
   bindings=new BindingSet(User);bindings.Enabled=delegate{return Live() && keys.Checked && !busy;};bindings.TargetPid=delegate{return link==null?0:link.Pid;};
   foreach(var c in Game.Cheats){var captured=c;bindings.Add(c.Key,c.TitleRu,c.TitleEn,c.Hotkey,delegate{Toggle(captured);});}
   foreach(var a in Game.Actions){var captured=a;bindings.Add("action:"+a.Command,a.Ru,a.En,a.Hotkey,delegate{Run(L.P(captured.DoneRu,captured.DoneEn),captured.Command);});}
   bindings.Add("reset","Отключить всё","Turn all off","Ctrl+F12",ClearAll);if(!Preview)bindings.Load();
   bindings.Changed+=delegate{UpdateHotkeys();foreach(var row in rows)row.Invalidate();};
  }
  try{string log=Path.Combine(User,"history.log");if(File.Exists(log))events.AddRange(File.ReadAllLines(log,Encoding.UTF8).Reverse().Take(300).Reverse());}catch{}
  Log(L.T("Запуск · PID ")+Process.GetCurrentProcess().Id);
  var ranges=typeof(Game).GetField("SavedParameterRanges");
  if(!Preview && ranges!=null)try{memory=new FeatureMemory(Path.Combine(User,"features.txt"),Game.Cheats.Select(c=>c.Key),(string[,])ranges.GetValue(null));}catch(Exception error){Log(L.P("Не прочитаны сохранённые функции: ","Could not read saved features: ")+error.Message);}
  uiTimer.Tick+=delegate{Sync();};uiTimer.Start();
  if(!Preview){worker=new Thread(Loop){IsBackground=true,Name="GameLink"};worker.Start();}
  FormClosing+=OnClosingTrainer;
  Sync();
 }

 void FitToScreen(){var area=Screen.FromPoint(Cursor.Position).WorkingArea;int chrome=Height-ClientSize.Height;ClientSize=new Size(Math.Min(ClientSize.Width,area.Width-40),Math.Min(layoutHeight,area.Height-chrome-20));}

 void Build(int[] values,bool snd,bool k){
  if(typeof(Game).GetMethod("CategoryOf")!=null){BuildGrouped(snd,k);return;}
  bool hasParams=Game.Params.Length>0;int actionRows=(Game.Actions.Length+2+3)/4;
  int[] heights={70,62,GridRows*62,hasParams?48:0,22+actionRows*42,62};
  layoutHeight=heights.Sum()+22;
  var layout=new TableLayoutPanel{Dock=DockStyle.Top,Height=layoutHeight,Padding=new Padding(18,12,18,10),ColumnCount=1,RowCount=heights.Length};layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
  foreach(int h in heights)layout.RowStyles.Add(new RowStyle(SizeType.Absolute,h));Controls.Add(layout);
  var head=new Panel{Dock=DockStyle.Fill};
  var image=new PictureBox{Location=new Point(1,2),Size=new Size(58,58),SizeMode=PictureBoxSizeMode.Zoom};
  try{image.Image=Image.FromStream(Assembly.GetExecutingAssembly().GetManifestResourceStream("icon.png"));}catch{}
  head.Controls.Add(image);
  var title=Skin.Label(Game.Title,24,Skin.Accent,true);title.SetBounds(73,0,420,38);head.Controls.Add(title);
  var sub=Skin.Label(Game.Subtitle+"  ·  "+Game.Cheats.Length+" "+L.T("ПЕРЕКЛЮЧАТЕЛЕЙ"),9,Skin.Muted);sub.SetBounds(76,37,460,24);head.Controls.Add(sub);
  runtime=Skin.Label("",9,Skin.Muted);runtime.TextAlign=ContentAlignment.MiddleRight;head.Controls.Add(runtime);
  var hk=Skin.Label(L.T("Ctrl + F12 — отключить все читы"),9,Skin.Muted);hk.TextAlign=ContentAlignment.MiddleRight;head.Controls.Add(hk);
  ruButton=LangButton("RU",!L.En,delegate{SetLanguage(false);});enButton=LangButton("EN",L.En,delegate{SetLanguage(true);});head.Controls.Add(ruButton);head.Controls.Add(enButton);
  Action place=delegate{int w=Math.Max(200,head.Width-560);runtime.SetBounds(head.Width-110-w,5,w,24);hk.SetBounds(head.Width-110-w,30,w,24);ruButton.SetBounds(head.Width-100,8,46,30);enButton.SetBounds(head.Width-50,8,46,30);};
  head.Resize+=delegate{place();};place();layout.Controls.Add(head,0,0);
  var stat=new Panel{Dock=DockStyle.Fill,BackColor=Skin.Panel,Margin=new Padding(4,0,4,6)};connection=Skin.Label(L.T("○ Игра не подключена"),11,Skin.Amber,true);connection.SetBounds(14,4,820,27);stat.Controls.Add(connection);
  metrics=Skin.Label(L.T("Запустите игру. Трейнер подключится автоматически."),9,Skin.Muted);metrics.SetBounds(14,30,820,22);stat.Controls.Add(metrics);
  stat.Resize+=delegate{connection.Width=stat.Width-28;metrics.Width=stat.Width-28;};layout.Controls.Add(stat,0,1);
  var grid=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=2,RowCount=GridRows,Margin=new Padding(0)};grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));
  for(int i=0;i<GridRows;i++)grid.RowStyles.Add(new RowStyle(SizeType.Percent,100f/GridRows));
  for(int i=0;i<Game.Cheats.Length;i++){var row=new CheatRow(i,Game.Cheats[i]){Dock=DockStyle.Fill,Hotkey=HotkeyName(i)};row.Click+=delegate{Toggle(row.Cheat);};tips.SetToolTip(row,row.Cheat.Title+"\r\n"+row.Cheat.Desc);rows.Add(row);grid.Controls.Add(row,i/GridRows,i%GridRows);}
  var clearRow=Skin.Button(L.T("Отключить всё  ·  Ctrl+F12"),delegate{ClearAll();});clearRow.Dock=DockStyle.Fill;clearRow.Margin=new Padding(4);clearRow.BackColor=Color.FromArgb(56,30,30);clearRow.ForeColor=Skin.Red;
  grid.Controls.Add(clearRow,Game.Cheats.Length/GridRows,Game.Cheats.Length%GridRows);actions.Add(clearRow);
  layout.Controls.Add(grid,0,2);
  paramBoxes.Clear();
  if(hasParams){
   var prm=new FlowLayoutPanel{Dock=DockStyle.Fill,BackColor=Skin.Panel,Margin=new Padding(4,2,4,4),Padding=new Padding(8,6,8,0),WrapContents=false,AutoScroll=false};
   for(int i=0;i<Game.Params.Length;i++){var p=Game.Params[i];var lbl=Skin.Label(L.P(p.Ru,p.En),9,Skin.Muted);lbl.AutoSize=true;lbl.Margin=new Padding(6,5,6,0);prm.Controls.Add(lbl);
    var box=Combo(p.Steps,i<values.Length?values[i]:p.Default);box.Width=90;box.Margin=new Padding(0,0,18,0);string key=p.Key;float[] steps=p.Steps;box.SelectedIndexChanged+=delegate{SendParam(key,steps[box.SelectedIndex]);};paramBoxes.Add(box);prm.Controls.Add(box);}
   var pn=Skin.Label(L.T("Меняются на лету, в том числе при включённой функции"),8,Skin.Muted);pn.AutoSize=true;pn.Margin=new Padding(6,6,0,0);prm.Controls.Add(pn);
   layout.Controls.Add(prm,0,3);
  }
  var act=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=4,RowCount=actionRows+1,Margin=new Padding(4,3,4,0)};for(int i=0;i<4;i++)act.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,25));
  act.RowStyles.Add(new RowStyle(SizeType.Absolute,22));for(int i=0;i<actionRows;i++)act.RowStyles.Add(new RowStyle(SizeType.Absolute,42));
  var note=Skin.Label(L.T("Разовые действия — выданное остаётся в сохранении"),8,Skin.Muted);note.Dock=DockStyle.Fill;act.Controls.Add(note,0,0);act.SetColumnSpan(note,4);
  int cell=0;
  foreach(var a in Game.Actions){var def=a;var b=Skin.Button(L.P(a.Ru,a.En),delegate{Run(L.P(def.DoneRu,def.DoneEn),def.Command);});tips.SetToolTip(b,L.P(a.Ru,a.En)+(a.Hotkey==null?"":"\r\n"+a.Hotkey));Place(act,b,cell%4,1+cell/4);actions.Add(b);cell++;}
  cell=actionRows*4-2;
  Place(act,Skin.Button(L.T("Журнал"),delegate{OpenHistory();}),cell%4,1+cell/4);cell++;Place(act,Skin.Button(L.T("Справка"),delegate{OpenHelp();}),cell%4,1+cell/4);
  layout.Controls.Add(act,0,4);
  var footer=new Panel{Dock=DockStyle.Fill};sound=new CheckBox{Text=L.T("Звук переключений"),Checked=snd,ForeColor=Skin.Muted,AutoSize=true,Location=new Point(6,5)};keys=new CheckBox{Text=L.T("Горячие клавиши"),Checked=k,ForeColor=Skin.Muted,AutoSize=true,Location=new Point(220,5)};footer.Controls.Add(sound);footer.Controls.Add(keys);
  lastEvent=Skin.Label("",8,Skin.Muted);lastEvent.SetBounds(6,29,830,24);footer.Controls.Add(lastEvent);footer.Resize+=delegate{lastEvent.Width=footer.Width-12;};layout.Controls.Add(footer,0,5);
  sound.CheckedChanged+=delegate{SaveSettings();};keys.CheckedChanged+=delegate{SaveSettings();UnregisterKeys();UpdateHotkeys();};
  if(CustomBindings){var bind=Skin.Button(L.P("Привязки клавиш","Key bindings"),delegate{if(bindings!=null)bindings.Show(this);});bind.SetBounds(430,0,180,28);footer.Controls.Add(bind);}
 }
 void BuildGrouped(bool snd,bool k){
  AutoScroll=false;layoutHeight=800;paramBoxes.Clear();bindingLabels.Clear();
  var categoryMethod=typeof(Game).GetMethod("CategoryOf");var names=(string[][])typeof(Game).GetField("CategoryNames").GetValue(null);
  Func<string,int> category=key=>(int)categoryMethod.Invoke(null,new object[]{key});
  var root=new TableLayoutPanel{Dock=DockStyle.Fill,Padding=new Padding(18,10,18,8),ColumnCount=1,RowCount=4};root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));root.RowStyles.Add(new RowStyle(SizeType.Absolute,76));root.RowStyles.Add(new RowStyle(SizeType.Absolute,56));root.RowStyles.Add(new RowStyle(SizeType.Percent,100));root.RowStyles.Add(new RowStyle(SizeType.Absolute,78));Controls.Add(root);
  var head=new Panel{Dock=DockStyle.Fill};var title=Skin.Label(Game.Title,23,Skin.Accent,true);title.SetBounds(2,0,480,40);head.Controls.Add(title);var sub=Skin.Label(Game.VersionText+" · "+L.P("Функции и редакторы","Features and editors"),10,Skin.Muted);sub.SetBounds(4,40,500,26);head.Controls.Add(sub);
  runtime=Skin.Label("",8,Skin.Muted);head.Controls.Add(runtime);ruButton=LangButton("RU",!L.En,delegate{SetLanguage(false);});enButton=LangButton("EN",L.En,delegate{SetLanguage(true);});head.Controls.Add(ruButton);head.Controls.Add(enButton);head.Resize+=delegate{ruButton.SetBounds(head.Width-100,5,46,32);enButton.SetBounds(head.Width-50,5,46,32);runtime.SetBounds(head.Width-280,42,276,25);};root.Controls.Add(head,0,0);
  var stat=new Panel{Dock=DockStyle.Fill,BackColor=Skin.Panel,Margin=new Padding(0,0,0,6)};connection=Skin.Label("",10,Skin.Amber,true);metrics=Skin.Label("",8,Skin.Muted);stat.Controls.Add(connection);stat.Controls.Add(metrics);var reset=Skin.Button(L.P("Отключить всё","Turn all off"),ClearAll);var resetBind=Skin.Button("Ctrl+F12",delegate{if(bindings!=null)bindings.Edit(this,"reset");});resetBind.ForeColor=Skin.Accent;bindingLabels["reset"]=resetBind;stat.Controls.Add(reset);stat.Controls.Add(resetBind);actions.Add(reset);stat.Resize+=delegate{connection.SetBounds(12,1,stat.Width-330,25);metrics.SetBounds(12,24,stat.Width-330,22);reset.SetBounds(stat.Width-310,7,165,34);resetBind.SetBounds(stat.Width-140,7,130,34);};root.Controls.Add(stat,0,1);
  var body=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=2,RowCount=1,Margin=Padding.Empty};body.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,190));body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));root.Controls.Add(body,0,2);
  var groups=new ListBox{Name="FeatureCategories",Dock=DockStyle.Fill,BackColor=Skin.Panel,ForeColor=Skin.Text,BorderStyle=BorderStyle.None,DrawMode=DrawMode.OwnerDrawFixed,ItemHeight=38,IntegralHeight=false,Margin=new Padding(0,0,12,0)};
  groups.DrawItem+=delegate(object sender,DrawItemEventArgs e){if(e.Index<0)return;bool selected=(e.State&DrawItemState.Selected)!=0;using(var brush=new SolidBrush(selected?Skin.Hover:Skin.Panel))e.Graphics.FillRectangle(brush,e.Bounds);if(selected)using(var brush=new SolidBrush(Skin.Accent))e.Graphics.FillRectangle(brush,e.Bounds.X,e.Bounds.Y,3,e.Bounds.Height);TextRenderer.DrawText(e.Graphics,groups.Items[e.Index].ToString(),groups.Font,new Rectangle(e.Bounds.X+10,e.Bounds.Y,e.Bounds.Width-12,e.Bounds.Height),selected?Skin.Accent:Skin.Text,TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis|TextFormatFlags.NoPrefix);};
  for(int g=0;g<names.Length;g++){int id=g;int total=g==0?Game.Cheats.Length+Game.Actions.Length:Game.Cheats.Count(c=>category(c.Key)==id)+Game.Actions.Count(a=>category(a.Command)==id);groups.Items.Add(L.P(names[g][0],names[g][1])+"  "+total);}body.Controls.Add(groups,0,0);
  var right=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=1,RowCount=3,Margin=Padding.Empty};right.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));right.RowStyles.Add(new RowStyle(SizeType.Absolute,38));right.RowStyles.Add(new RowStyle(SizeType.Absolute,25));right.RowStyles.Add(new RowStyle(SizeType.Percent,100));body.Controls.Add(right,1,0);
  var search=new TextBox{Name="FeatureSearch",Dock=DockStyle.Fill,BackColor=Skin.Panel,ForeColor=Skin.Text,Font=new Font("Segoe UI",12),Text=featureSearch};Skin.Cue(search,L.P("Поиск функции или редактора…","Search features and editors…"));tips.SetToolTip(search,L.P("Поиск по названию и описанию","Search names and descriptions"));right.Controls.Add(search,0,0);
  var hint=Skin.Label(L.P("Нажмите на функцию; клавиша справа меняется щелчком или F2.","Click a feature; click its binding or press F2 to change it."),9,Skin.Muted);hint.Dock=DockStyle.Fill;right.Controls.Add(hint,0,1);
  var list=new Panel{Name="FeatureList",Dock=DockStyle.Fill,AutoScroll=true,Margin=Padding.Empty};right.Controls.Add(list,0,2);var content=new Panel{Dock=DockStyle.Top,Height=0};list.Controls.Add(content);var entries=new List<Tuple<Control,int,string>>();
  foreach(var c in Game.Cheats){var captured=c;var row=new CheatRow(Array.IndexOf(Game.Cheats,c),c){Hotkey=c.Hotkey,EditBinding=delegate{if(bindings!=null)bindings.Edit(this,captured.Key);}};row.Click+=delegate{Toggle(captured);};tips.SetToolTip(row,c.Title+"\r\n"+c.Desc+"\r\n"+L.P("Клавиша справа: изменить. Delete в окне ввода: убрать.","Click the binding to edit. Delete in the capture window unbinds."));rows.Add(row);content.Controls.Add(row);entries.Add(Tuple.Create((Control)row,category(c.Key),c.TitleRu+" "+c.TitleEn+" "+c.DescRu+" "+c.DescEn));}
  foreach(var a in Game.Actions){var captured=a;string id="action:"+a.Command;var line=new Panel{BackColor=Skin.Panel,Height=58};var button=Skin.Button(L.P(a.Ru,a.En)+"  ›",delegate{Run(L.P(captured.DoneRu,captured.DoneEn),captured.Command);});button.TextAlign=ContentAlignment.MiddleLeft;button.Tag=a.Command;button.KeyDown+=delegate(object sender,KeyEventArgs e){if(e.KeyCode==Keys.F2 && bindings!=null){bindings.Edit(this,id);e.Handled=true;}};var bind=Skin.Button(String.IsNullOrEmpty(a.Hotkey)?L.P("Назначить","Assign"):a.Hotkey,delegate{if(bindings!=null)bindings.Edit(this,id);});bind.ForeColor=Skin.Accent;bind.Font=new Font("Segoe UI",9);line.Controls.Add(button);line.Controls.Add(bind);line.Resize+=delegate{button.SetBounds(4,5,Math.Max(60,line.Width-158),48);bind.SetBounds(line.Width-149,14,135,30);};bindingLabels[id]=bind;actions.Add(button);content.Controls.Add(line);entries.Add(Tuple.Create((Control)line,category(a.Command),a.Ru+" "+a.En));}
  Action filter=delegate{list.SuspendLayout();list.AutoScrollPosition=Point.Empty;int y=0;string text=search.Text.Trim();foreach(var entry in entries){bool show=(selectedCategory==0 || entry.Item2==selectedCategory) && entry.Item3.IndexOf(text,StringComparison.OrdinalIgnoreCase)>=0;entry.Item1.Visible=show;entry.Item1.SetBounds(0,show?y:0,Math.Max(100,content.ClientSize.Width),60);if(show)y+=66;}content.Height=y;list.ResumeLayout();hint.Text=y==0?L.P("Ничего не найдено. Измените поиск или категорию.","No matches. Change the search or category."):L.P("Функций: ","Features: ")+(y/66)+L.P(" · клавиша рядом: изменить; F2 — назначить"," · click a binding to edit; F2 assigns");};
  content.Resize+=delegate{foreach(var entry in entries)entry.Item1.Width=Math.Max(100,content.ClientSize.Width);};search.TextChanged+=delegate{featureSearch=search.Text;filter();};groups.SelectedIndexChanged+=delegate{selectedCategory=groups.SelectedIndex;filter();};list.Resize+=delegate{filter();};groups.SelectedIndex=Math.Min(selectedCategory,names.Length-1);filter();
  var footer=new Panel{Dock=DockStyle.Fill};sound=new CheckBox{Text=L.T("Звук переключений"),Checked=snd,ForeColor=Skin.Muted,AutoSize=true,Location=new Point(2,10)};keys=new CheckBox{Text=L.T("Горячие клавиши"),Checked=k,ForeColor=Skin.Muted,AutoSize=true,Location=new Point(205,10)};footer.Controls.Add(sound);footer.Controls.Add(keys);var log=Skin.Button(L.T("Журнал"),OpenHistory);var help=Skin.Button(L.T("Справка"),OpenHelp);footer.Controls.Add(log);footer.Controls.Add(help);lastEvent=Skin.Label("",9,Skin.Muted);footer.Controls.Add(lastEvent);footer.Resize+=delegate{log.SetBounds(footer.Width-200,6,95,32);help.SetBounds(footer.Width-100,6,95,32);lastEvent.SetBounds(2,43,footer.Width-4,28);};sound.CheckedChanged+=delegate{SaveSettings();};keys.CheckedChanged+=delegate{SaveSettings();UnregisterKeys();UpdateHotkeys();};root.Controls.Add(footer,0,3);
 }
 Button LangButton(string text,bool active,Action action){var b=Skin.Button(text,action,active);b.Font=new Font("Segoe UI",9,FontStyle.Bold);return b;}
 public void SetLanguage(bool en){
  if(L.En==en)return;L.En=en;
  int[] values=paramBoxes.Select(b=>b.SelectedIndex).ToArray();bool snd=sound.Checked,k=keys.Checked;var scroll=AutoScrollPosition;
  UnregisterKeys();SuspendLayout();var old=Controls.Cast<Control>().ToList();Controls.Clear();foreach(var c in old)c.Dispose();rows.Clear();actions.Clear();
  Build(values,snd,k);ResumeLayout(true);AutoScrollPosition=new Point(-scroll.X,-scroll.Y);SaveSettings();Sync();L.Notify();Log(L.T("Язык: русский"));
 }
 ComboBox Combo(float[] steps,int def){var c=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,BackColor=Skin.BG,ForeColor=Skin.Text,FlatStyle=FlatStyle.Flat,Font=new Font("Segoe UI",10)};foreach(float s in steps)c.Items.Add("×"+s.ToString(System.Globalization.CultureInfo.InvariantCulture));
  c.DrawMode=DrawMode.OwnerDrawFixed;c.ItemHeight=22;c.DrawItem+=delegate(object o,DrawItemEventArgs e){bool sel=(e.State&DrawItemState.Selected)!=0 && (e.State&DrawItemState.ComboBoxEdit)==0;using(var b=new SolidBrush(sel?Skin.Hover:Skin.Panel))e.Graphics.FillRectangle(b,e.Bounds);if(e.Index>=0)TextRenderer.DrawText(e.Graphics,c.Items[e.Index].ToString(),c.Font,e.Bounds,Skin.Accent,TextFormatFlags.Left|TextFormatFlags.VerticalCenter);};
  c.SelectedIndex=Math.Max(0,Math.Min(def,c.Items.Count-1));return c;}
 static string Num(float v){return v.ToString(System.Globalization.CultureInfo.InvariantCulture);}
 void SendParam(string key,float v){if(!Live())return;Task.Run(delegate{try{Send("mul "+key+" "+Num(v));var p=Game.Params.First(x=>x.Key==key);Post(L.P(p.Ru,p.En)+": ×"+Num(v));}catch(Exception e){Post(L.T("Параметр: ")+L.D(e.Message));}});}
 void PushParams(){for(int i=0;i<Game.Params.Length && i<paramBoxes.Count;i++)try{Send("mul "+Game.Params[i].Key+" "+Num(Game.Params[i].Steps[paramBoxes[i].SelectedIndex]));}catch{}}
 void Place(TableLayoutPanel p,Button b,int x,int y){b.Dock=DockStyle.Fill;b.Margin=new Padding(0,2,6,2);p.Controls.Add(b,x,y);}
 bool Live(){GameLink l=link;return !closing && l!=null && l.Alive;}

 void Loop(){
  DateTime nextAttach=DateTime.MinValue;
  DateTime nextHeartbeat=DateTime.MinValue;
  DateTime nextRestore=DateTime.MinValue;
  DateTime nextProgress=DateTime.MinValue;string lastProgress=null;
  while(!closing){
   try{
    if(ResetCommand!=null && link!=null && DateTime.UtcNow>=nextHeartbeat){nextHeartbeat=DateTime.UtcNow.AddSeconds(1);if(Send("ping")!="ok")throw new IOException(L.P("Мод не отвечает","Mod does not respond"));}
    if(link!=null && !link.Alive){lock(sync){try{link.Dispose();}catch{}link=null;}linkState="Игра закрыта · ожидание запуска";Post(L.T("Игра закрыта — читы будут включены снова при следующем подключении"));}
    if(link!=null && ProgressCommand!=null && DateTime.UtcNow>=nextProgress){
     nextProgress=DateTime.UtcNow.AddSeconds(1);string progress=link.Send(ProgressCommand);
     if(progress.StartsWith("ok ") && progress!=lastProgress){lastProgress=progress;if(progress!="ok TRAVEL_IDLE")Post(L.D(progress.Substring(3)));}
    }
    if(link==null && DateTime.UtcNow>=nextAttach){
     nextAttach=DateTime.UtcNow.AddSeconds(3);string state;var l=GameLink.Attach(out state);linkState=state;
     if(l!=null){lock(sync)link=l;linkState="ok";Post(L.T("Подключено · PID ")+l.Pid+L.T(" · мост загружен"));PushParams();
      if(memory!=null){memory.Reconnect();foreach(var c in Game.Cheats)c.Active=false;nextRestore=DateTime.MinValue;}
      var restore=memory==null?Game.Cheats.Where(c=>c.Active).ToList():new List<Cheat>();
      foreach(var c in restore)try{Send("set "+c.Key+" 1");}catch(Exception e){c.Active=false;Post(L.T("Не включено снова: ")+c.Title+" · "+L.D(e.Message));}
      if(restore.Count>0)Post(L.T("Повторно включено: ")+String.Join(", ",restore.Select(c=>c.Title)));}
    }
    if(memory!=null && link!=null && !busy && DateTime.UtcNow>=nextRestore){
     nextRestore=DateTime.UtcNow.AddSeconds(3);
     if(memory.Pending().Length>0 && link.Send("get ready")=="ok"){
      foreach(string command in memory.Pending()){
       if(closing)break;
       lock(commandSync){
        if(!memory.StillPending(command))continue;
        string answer=Send(command);
        if(answer=="ok" && command.StartsWith("set ")){var c=Game.Cheats.First(x=>x.Key==command.Split(' ')[1]);c.Active=true;Post(L.P("Восстановлено: ","Restored: ")+c.Title);}
       }
      }
      nextRestore=DateTime.UtcNow.AddSeconds(15);
     }
    }
   }catch(Exception e){
    Post(L.T("Связь: ")+L.D(e.Message));
    lock(sync){if(link!=null){try{link.Dispose();}catch{}link=null;}}linkState="Связь с игрой потеряна · переподключение";
   }
   Thread.Sleep(200);
  }
 }
 string Send(string command){lock(commandSync){GameLink l;lock(sync)l=link;if(l==null)throw new InvalidOperationException("Игра не подключена");string answer=l.Send(command);if(answer.StartsWith("err "))Post(L.P("Отказ команды: ","Command failed: ")+command+" · "+L.D(answer.Substring(4)));
  if(answer=="ok" && command.StartsWith("set ")){var parts=command.Split(' ');if(parts.Length==3){var feature=Game.Cheats.FirstOrDefault(c=>c.Key==parts[1]);if(feature!=null)feature.Active=parts[2]=="1";}}
  if(memory!=null){try{memory.Remember(command,answer);if(command=="act blackwall" && answer=="ok"){string flags=l.Send("get features");if(flags.StartsWith("ok ") || flags=="ok"){bool on=flags.Split(' ').Contains("blackwall");memory.Remember("set blackwall "+(on?1:0),"ok");Game.Cheats.First(c=>c.Key=="blackwall").Active=on;}}}catch(Exception error){Post(L.P("Команда выполнена, но настройки не сохранены: ","Command completed, but settings could not be saved: ")+error.Message);}}
  return answer;}}

 void Toggle(Cheat c){
  if(c.Pending || busy || closing)return;bool target=!(c.Active || memory!=null && memory.Wants(c.Key));
  if(!Live()){if(memory!=null)try{memory.Remember("set "+c.Key+" "+(target?1:0),"ok");memory.Reconnect();c.Active=false;Post(c.Title+L.P(target?": сохранено для включения после загрузки":": автозапуск отключён",target?": saved for activation after loading":": automatic activation disabled"));Sync();}catch(Exception error){Post(L.D(error.Message));}return;}
  c.Pending=true;Sync();
  Task.Run(delegate{
   try{string r=Send("set "+c.Key+" "+(target?1:0));if(!r.StartsWith("ok"))throw new InvalidOperationException(r.StartsWith("err ")?r.Substring(4):r);
    c.Active=target;Post(c.Title+": "+L.T(target?"включено":"выключено"));BeginInvoke((Action)delegate{Beep(target);});}
   catch(Exception e){Post(L.T("Не выполнено: ")+c.Title+" · "+L.D(e.Message));}
   finally{c.Pending=false;}
  });
 }
 void ClearAll(){
  if(ResetCommand!=null){if(busy)return;if(!Live()){if(memory!=null)try{memory.Remember("reset","ok");foreach(var c in Game.Cheats)c.Active=false;Sync();Post(L.T("Все функции выключены"));}catch(Exception e){Post(L.D(e.Message));}return;}busy=true;Task.Run(delegate{try{string r=Send(ResetCommand);if(r!="ok")throw new IOException(L.D(r));foreach(var c in Game.Cheats)c.Active=false;Post(L.T("Все функции выключены"));}catch(Exception e){Post(L.T("Отключение: ")+L.D(e.Message));}finally{busy=false;}});return;}
  if(!Live() || busy)return;var on=Game.Cheats.Where(c=>c.Active).ToList();if(on.Count==0){Post(L.T("Все функции уже выключены"));return;}busy=true;
  Task.Run(delegate{try{foreach(var c in on){c.Pending=true;try{Send("set "+c.Key+" 0");c.Active=false;}finally{c.Pending=false;}}Post(L.T("Все функции выключены")+" ("+on.Count+")");BeginInvoke((Action)delegate{Beep(false);});}catch(Exception e){Post(L.T("Отключение: ")+L.D(e.Message));}finally{busy=false;}});
 }
 void Run(string title,string command){
  if(command.StartsWith("ui:")){var open=typeof(Game).GetMethod("OpenTool");if(open!=null)open.Invoke(null,new object[]{command,this,(Func<string,string>)Send,(Action<string>)Post});return;}
  if(!Live()){Post(L.T("Для этого действия нужна запущенная игра"));return;}
  Task.Run(delegate{try{string r=Send(command);if(!r.StartsWith("ok"))throw new InvalidOperationException(r.StartsWith("err ")?r.Substring(4):r);Post(title+(r.StartsWith("ok ")?" · "+L.D(r.Substring(3)):""));BeginInvoke((Action)delegate{Beep(true);});}catch(Exception e){Post(L.T("Не выполнено: ")+L.D(e.Message));}});
 }
 [DllImport("dwmapi.dll")]static extern int DwmSetWindowAttribute(IntPtr h,int attr,ref int value,int size);
 static string InstanceWindowKey{get{return "CheatKit.Window."+Game.AppId+(Preview?".preview":".v1");}}
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern bool SetPropW(IntPtr window,string name,IntPtr value);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern IntPtr GetPropW(IntPtr window,string name);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern IntPtr RemovePropW(IntPtr window,string name);
 delegate bool InstanceWindowCallback(IntPtr window,IntPtr unused);
 [DllImport("user32.dll")]static extern bool EnumWindows(InstanceWindowCallback callback,IntPtr unused);
 [DllImport("user32.dll")]static extern bool IsIconic(IntPtr window);
 [DllImport("user32.dll")]static extern bool ShowWindowAsync(IntPtr window,int command);
 [DllImport("user32.dll")]static extern bool SetForegroundWindow(IntPtr window);
 static bool ShowExistingInstance(){
  for(int attempt=0;attempt<10;attempt++){
   IntPtr target=IntPtr.Zero;
   EnumWindows(delegate(IntPtr window,IntPtr unused){if(GetPropW(window,InstanceWindowKey)==IntPtr.Zero)return true;target=window;return false;},IntPtr.Zero);
   if(target!=IntPtr.Zero){ShowWindowAsync(target,IsIconic(target)?9:5);SetForegroundWindow(target);return true;}
   Thread.Sleep(100);
  }
  return false;
 }
 protected override void OnHandleCreated(EventArgs e){base.OnHandleCreated(e);SetPropW(Handle,InstanceWindowKey,new IntPtr(1));int dark=1;try{DwmSetWindowAttribute(Handle,20,ref dark,4);}catch{}}
 protected override void OnHandleDestroyed(EventArgs e){RemovePropW(Handle,InstanceWindowKey);base.OnHandleDestroyed(e);}

 void Sync(){
  if(connection==null || connection.IsDisposed)return;
  bool live=Live();GameLink l=link;
  connection.Text=live?L.T("● Подключено · PID ")+l.Pid+" · "+Game.VersionText:"○ "+(linkState=="ok"?L.T("Подключение…"):L.D(L.T(linkState)));
  connection.ForeColor=live?Skin.Accent:Skin.Amber;
  metrics.Text=live?L.T("Активно: ")+Game.Cheats.Count(c=>c.Active)+L.T(" из ")+Game.Cheats.Length:L.T("Запустите игру. Трейнер подключится автоматически.");
  if(memory!=null)metrics.Text+=L.P(" · Сохранено: "," · Saved: ")+memory.Count;
  foreach(var r in rows){r.Cheat.Remembered=memory!=null && memory.Wants(r.Cheat.Key) && (!live || !r.Cheat.Active);r.Available=!busy && (live || memory!=null);r.Invalidate();}foreach(var b in actions)b.Enabled=!busy && (live || b.Tag is string && ((string)b.Tag).StartsWith("ui:") || memory!=null && b.Text==L.P("Отключить всё","Turn all off"));
  runtime.Text=L.T("Сеанс ")+(DateTime.Now-started).ToString(@"hh\:mm\:ss")+"  ·  PID "+Process.GetCurrentProcess().Id;
  UpdateHotkeys();
 }
 void Beep(bool on){if(sound.Checked)Sounds.Play(on);}
 void Post(string message){try{if(IsHandleCreated && !IsDisposed)BeginInvoke((Action)delegate{Log(message);});}catch{}}
 void Log(string message){string line=DateTime.Now.ToString("dd.MM.yyyy HH:mm:ss")+"  "+message;events.Add(line);if(events.Count>1000)events.RemoveRange(0,events.Count-1000);if(lastEvent!=null && !lastEvent.IsDisposed)lastEvent.Text=message;if(historyText!=null && !historyText.IsDisposed)historyText.AppendText(line+Environment.NewLine);if(Preview)return;try{Directory.CreateDirectory(User);File.AppendAllText(Path.Combine(User,"history.log"),line+Environment.NewLine,Encoding.UTF8);}catch{}}
 void LoadSettings(ref bool snd,ref bool k){try{string f=Path.Combine(User,"settings.txt");if(!File.Exists(f))return;foreach(string line in File.ReadAllLines(f)){var p=line.Split('=');if(p.Length!=2)continue;if(p[0]=="sound")snd=p[1]=="1";if(p[0]=="hotkeys")k=p[1]=="1";if(p[0]=="lang")L.En=p[1]=="en";}}catch{}}
 void SaveSettings(){if(Preview)return;try{Directory.CreateDirectory(User);File.WriteAllText(Path.Combine(User,"settings.txt"),"sound="+(sound.Checked?1:0)+"\r\nhotkeys="+(keys.Checked?1:0)+"\r\nlang="+(L.En?"en":"ru")+"\r\n");}catch{}}
 void OpenHistory(){if(history!=null && !history.IsDisposed){history.Activate();return;}history=new Form();Skin.Form(history,Text+L.T(" · журнал"),new Size(860,500));history.Icon=Icon;historyText=new TextBox{Dock=DockStyle.Fill,ReadOnly=true,Multiline=true,ScrollBars=ScrollBars.Vertical,BackColor=Skin.Panel,ForeColor=Skin.Text,BorderStyle=BorderStyle.None,Font=new Font("Consolas",9.5f),Text=String.Join(Environment.NewLine,events.ToArray())+Environment.NewLine};history.Controls.Add(historyText);history.Show(this);historyText.SelectionStart=historyText.TextLength;historyText.ScrollToCaret();}
 void OpenHelp(){var f=new Form();Skin.Form(f,Text+L.T(" · справка"),new Size(760,560));f.Icon=Icon;
  var keysText=String.Join("\r\n",rows.Select(r=>"  "+r.Hotkey.PadRight(16)+r.Cheat.Title));
  string text=L.P(Game.HelpRu,Game.HelpEn)+"\r\n\r\n"+L.T("Горячие клавиши (работают и в игре):")+"\r\n"+keysText+"\r\n  Ctrl+F12          "+L.T("Отключить всё")+"\r\n\r\n"+
   L.T("Закрытие трейнера выключает все функции и возвращает исходные значения.")+"\r\n"+L.T("Журнал и настройки: ")+"%LOCALAPPDATA%\\"+Game.AppId;
  var info=new TextBox{Multiline=true,ReadOnly=true,Dock=DockStyle.Fill,BackColor=Skin.Panel,ForeColor=Skin.Text,BorderStyle=BorderStyle.None,ScrollBars=ScrollBars.Vertical,Font=new Font("Segoe UI",10),Text=text};
  f.Controls.Add(info);f.Show(this);}

 [DllImport("user32.dll")]static extern bool RegisterHotKey(IntPtr h,int id,uint mods,uint key);
 [DllImport("user32.dll")]static extern bool UnregisterHotKey(IntPtr h,int id);
 void UpdateHotkeys(){
  if(CustomBindings){foreach(var row in rows)row.Hotkey=bindings==null?row.Cheat.Hotkey:bindings.Name(row.Cheat.Key);if(bindings!=null)foreach(var pair in bindingLabels)pair.Value.Text=bindings.Name(pair.Key);return;}
  bool enable=Live() && keys.Checked;if(!enable){if(hotkeys.Count>0){UnregisterKeys();foreach(var r in rows)r.Hotkey=HotkeyName(r.Index);}return;}
  if(hotkeys.Count>0 || !IsHandleCreated)return;
  foreach(var row in rows){int i=row.Index;row.Hotkey=HotkeyName(i);if(i>=20)continue;int id=100+i;
   int j=i%10;uint vk=(uint)(j<9?0x61+j:0x60);uint mods=(uint)(0x4000|2|(i>=10?1:0));
   if(RegisterHotKey(Handle,id,mods,vk)){CheatRow capture=row;hotkeys[id]=delegate{Toggle(capture.Cheat);};}else{row.Hotkey+=L.T(" (занята)");Log(L.T("Горячая клавиша занята: ")+row.Cheat.Title);}}
  if(RegisterHotKey(Handle,200,0x4002,0x7B))hotkeys[200]=delegate{ClearAll();};else Log(L.T("Ctrl + F12 занята другим приложением"));
 }
 static string HotkeyName(int i){if(Game.Cheats[i].Hotkey!=null)return Game.Cheats[i].Hotkey;if(i>=20)return L.T("без клавиши");int j=i%10;return (i<10?"Ctrl":"Ctrl+Alt")+"+Num"+(j<9?j+1:0);}
 void UnregisterKeys(){if(!IsHandleCreated)return;foreach(int id in hotkeys.Keys)UnregisterHotKey(Handle,id);hotkeys.Clear();}
 protected override void WndProc(ref Message m){if(m.Msg==0x312){Action a;if(hotkeys.TryGetValue(m.WParam.ToInt32(),out a))a();}base.WndProc(ref m);}

 bool shutdownDone;
 void OnClosingTrainer(object sender,FormClosingEventArgs e){
  if(shutdownDone)return;e.Cancel=true;if(closing)return;closing=true;uiTimer.Stop();UnregisterKeys();
  if(bindings!=null)bindings.Dispose();
  foreach(var r in rows)r.Available=false;foreach(var b in actions)b.Enabled=false;connection.Text=L.T("Восстанавливаю значения игры…");
  Task.Run(delegate{
   if(ResetCommand!=null){bool restored=false;try{GameLink l;lock(sync){l=link;link=null;}if(l!=null){try{restored=l.Send(ResetCommand)=="ok";}finally{l.Dispose();}}}catch{}BeginInvoke((Action)delegate{Log(restored?L.T("Трейнер закрыт · значения игры восстановлены"):L.P("Трейнер закрыт; подтверждение сброса не получено","Trainer closed; reset was not acknowledged"));shutdownDone=true;Close();});return;}
   try{GameLink l;lock(sync){l=link;link=null;}if(l!=null){var until=DateTime.UtcNow.AddSeconds(6);if(l.Alive)foreach(var c in Game.Cheats.Where(c=>c.Active)){if(DateTime.UtcNow>until)break;try{string r=l.Send("set "+c.Key+" 0");if(r.StartsWith("err"))break;}catch{break;}}l.Dispose();}}catch{}
   BeginInvoke((Action)delegate{Log(L.T("Трейнер закрыт · значения игры восстановлены"));shutdownDone=true;Close();});
  });
 }

 static int SelfTest(string[] args){
  int i=Array.IndexOf(args,"--selftest");string report=i+1<args.Length?args[i+1]:"selftest.txt";var log=new StringBuilder();
  Action<string> say=s=>{log.AppendLine(DateTime.Now.ToString("HH:mm:ss.fff ")+s);File.WriteAllText(report,log.ToString(),Encoding.UTF8);};
  string state;var link=GameLink.Attach(out state);say("attach: "+state);if(link==null)return 2;
  try{for(int k=i+2;k<args.Length;k++){string a=args[k];if(a.StartsWith("wait ")){Thread.Sleep(int.Parse(a.Substring(5)));say(a);continue;}say("> "+a);say(link.Send(a));}return 0;}
  catch(Exception e){say("error: "+e);return 1;}finally{link.Dispose();}
 }

 [STAThread]static void Main(string[] args){
  Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
  if(args.Contains("--selftest")){Environment.ExitCode=SelfTest(args);return;}
  Preview=args.Contains("--preview");
  bool first;using(var mutex=new Mutex(true,"Local\\"+Game.AppId+(Preview?".preview":".v1"),out first)){
   if(!first){if(!ShowExistingInstance())MessageBox.Show(Game.AppId+L.T(" уже запущен."),Game.AppId);return;}
   try{Sounds.Init();var form=new Trainer();int li=Array.IndexOf(args,"--lang");if(li>=0 && li+1<args.Length)form.SetLanguage(args[li+1]=="en");int si=Array.IndexOf(args,"--shot");if(si<0)si=Array.IndexOf(args,"--screenshot");
    int ti=Array.IndexOf(args,"--tool");if(Preview && ti>=0 && ti+1<args.Length){string tool=args[ti+1];form.Shown+=delegate{var open=typeof(Game).GetMethod("OpenTool");if(open!=null)open.Invoke(null,new object[]{tool,form,(Func<string,string>)delegate(string command){return "err "+L.P("Предпросмотр: игра не подключена","Preview: game not connected");},(Action<string>)form.Post});};}
    if(si>=0 && si+1<args.Length){string shot=Path.GetFullPath(args[si+1]);var t=new System.Windows.Forms.Timer{Interval=2500};
     t.Tick+=delegate{t.Stop();form.AutoScrollPosition=Point.Empty;Control target=form.OwnedForms.Length>0?(Control)form.OwnedForms.Last():args.Contains("--windowshot")?(Control)form:form.Controls[0];using(var b=new Bitmap(target.Width,target.Height)){target.DrawToBitmap(b,new Rectangle(0,0,target.Width,target.Height));b.Save(shot);}form.Close();};
     form.Shown+=delegate{t.Start();};}
    Application.Run(form);}catch(Exception e){MessageBox.Show(e.Message,Game.AppId+L.T(": ошибка"));Environment.ExitCode=1;}
  }
 }
}
