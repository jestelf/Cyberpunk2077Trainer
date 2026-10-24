using System;
using System.Collections.Generic;
using System.Drawing;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;

static class VehicleTuningEditor {
 public sealed class Setting {
  public string Key,Ru,En;public decimal Min,Max,Default;public int Decimals;
  public Setting(string key,string ru,string en,decimal min,decimal max,decimal standard,int decimals){Key=key;Ru=ru;En=en;Min=min;Max=max;Default=standard;Decimals=decimals;}
 }
 public static readonly Setting[] Settings={
  new Setting("vehicle_speed","Предел скорости вперёд, км/ч","Forward speed limit, km/h",20,600,250,0),
  new Setting("vehicle_reverse","Предел скорости назад, км/ч","Reverse speed limit, km/h",5,150,40,0),
  new Setting("vehicle_accel","Разгон 0–100 км/ч, секунд","Acceleration 0–100 km/h, seconds",0.25m,30,2,2),
  new Setting("vehicle_brake","Торможение 100–0 км/ч, секунд","Braking 100–0 km/h, seconds",0.25m,15,1.5m,2),
  new Setting("vehicle_turn","Быстрота поворота, градусов/с","Turn rate, degrees/second",0,360,120,0),
  new Setting("vehicle_grip","Подавление бокового заноса, 0–60","Lateral slide suppression, 0–60",0,60,25,1),
  new Setting("vehicle_downforce","Подавление подскока, 0–5","Anti-bounce, 0–5",0,5,0,1)
 };
 public static void Open(Form owner,Func<string,string> send,Action<string> log){
  var f=new Form();Skin.Form(f,L.P("Настройка транспорта","Vehicle tuning"),new Size(740,700));f.MinimumSize=new Size(600,460);f.AutoScroll=true;
  var panel=new TableLayoutPanel{Dock=DockStyle.Top,Height=640,Padding=new Padding(16),ColumnCount=2,RowCount=Settings.Length+3};panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,65));panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,35));panel.RowStyles.Add(new RowStyle(SizeType.Absolute,112));
  var note=Skin.Label("",10,Skin.Amber);note.Dock=DockStyle.Fill;panel.Controls.Add(note,0,0);panel.SetColumnSpan(note,2);
  var boxes=new Dictionary<string,NumericUpDown>();var labels=new Dictionary<string,Label>();var touched=new HashSet<string>();
  for(int i=0;i<Settings.Length;i++){
   var spec=Settings[i];panel.RowStyles.Add(new RowStyle(SizeType.Absolute,44));var label=Skin.Label("",10,Skin.Text);label.Dock=DockStyle.Fill;labels[spec.Key]=label;
   var value=new NumericUpDown{Name=spec.Key,Minimum=spec.Min,Maximum=spec.Max,Value=spec.Default,DecimalPlaces=spec.Decimals,Increment=spec.Decimals>0?0.1m:1m,BackColor=Skin.Panel,ForeColor=Skin.Text,Dock=DockStyle.Fill,Font=new Font("Segoe UI",12)};value.ValueChanged+=delegate{touched.Add(spec.Key);};boxes[spec.Key]=value;panel.Controls.Add(label,0,i+1);panel.Controls.Add(value,1,i+1);
  }
  panel.RowStyles.Add(new RowStyle(SizeType.Absolute,88));panel.RowStyles.Add(new RowStyle(SizeType.Absolute,90));
  var buttons=new FlowLayoutPanel{Dock=DockStyle.Fill,WrapContents=true};var status=Skin.Label("",9,Skin.Muted);status.Dock=DockStyle.Fill;
  Button apply=null,preset=null,off=null,upright=null;bool busy=false,polling=false;Action<bool> enable=on=>{busy=!on;apply.Enabled=preset.Enabled=off.Enabled=upright.Enabled=on;foreach(var box in boxes.Values)box.Enabled=on;};
  Action<bool> submit=on=>{
   var commands=on?Settings.Select(s=>"mul "+s.Key+" "+boxes[s.Key].Value.ToString(CultureInfo.InvariantCulture)).Concat(new[]{"set vehicle_tuning 1"}).ToArray():new[]{"set vehicle_tuning 0"};enable(false);
   Task.Run(delegate{string message;try{foreach(string command in commands){string result=send(command);if(result!="ok")throw new InvalidOperationException(L.D(result));}message=on?L.P("Настройки приняты. Текущее состояние показано ниже.","Settings accepted. Live controller status is shown below."):L.P("Помощь в управлении выключена.","Driving assistance disabled.");}catch(Exception error){message=L.D(error.Message);}log(message);if(!f.IsDisposed)try{f.BeginInvoke((Action)delegate{status.Text=message;enable(true);});}catch{}});
  };
  apply=Skin.Button("",()=>submit(true),true);apply.Name="ApplyVehicleTuning";apply.Width=180;
  preset=Skin.Button("",delegate{decimal[] values={250,40,2,2,90,12,0};for(int i=0;i<Settings.Length;i++)boxes[Settings[i].Key].Value=values[i];submit(true);});preset.Name="ArcadeVehiclePreset";preset.Width=200;
  off=Skin.Button("",()=>submit(false));off.Name="DisableVehicleTuning";off.Width=180;
  upright=Skin.Button("",delegate{enable(false);Task.Run(delegate{string message;try{string result=send("act vehicle_upright");message=result=="ok"?L.P("Транспорт поставлен на колёса.","Vehicle returned to its wheels."):L.D(result);}catch(Exception error){message=L.D(error.Message);}log(message);if(!f.IsDisposed)try{f.BeginInvoke((Action)delegate{status.Text=message;enable(true);});}catch{}});});upright.Name="UprightVehicle";upright.Width=180;
  buttons.Controls.Add(apply);buttons.Controls.Add(preset);buttons.Controls.Add(off);buttons.Controls.Add(upright);panel.Controls.Add(buttons,0,Settings.Length+1);panel.SetColumnSpan(buttons,2);panel.Controls.Add(status,0,Settings.Length+2);panel.SetColumnSpan(status,2);f.Controls.Add(panel);
  Action language=delegate{
   f.Text=L.P("Настройка транспорта","Vehicle tuning");note.Text=L.P("Машины и мотоциклы, только место водителя. Разгон и поворот ограничены по ускорению для устойчивости; на высокой скорости поворот плавнее. Подавление подскока гасит подъём и не давит на стоящий транспорт. Ручник сохраняет занос. Для переворота остановитесь; можно также смотреть на транспорт рядом.","Cars and motorcycles, driver seat only. Acceleration and cornering assistance are bounded for stability; turns soften at high speed. Anti-bounce damps upward motion without loading stationary suspension. Handbrake preserves sliding. Stop before uprighting; looking at a nearby vehicle also works.");
   foreach(var spec in Settings)labels[spec.Key].Text=L.P(spec.Ru,spec.En);apply.Text=L.P("Применить и включить","Apply and enable");preset.Text=L.P("Устойчиво · 250 км/ч","Stable · 250 km/h");off.Text=L.P("Выключить помощь","Disable assistance");upright.Text=L.P("Поставить на колёса","Return to wheels");
  };language();L.Changed+=language;f.FormClosed+=delegate{L.Changed-=language;};
  var timer=new System.Windows.Forms.Timer{Interval=1000};timer.Tick+=delegate{if(busy||polling)return;polling=true;Task.Run(delegate{string result;try{result=FormatStatus(send("get vehicle"));}catch(Exception error){result=L.D(error.Message);}if(!f.IsDisposed)try{f.BeginInvoke((Action)delegate{polling=false;if(!busy)status.Text=result;});}catch{}});};f.Shown+=delegate{timer.Start();};f.FormClosed+=delegate{timer.Stop();timer.Dispose();};
  f.Shown+=delegate{Task.Run(delegate{foreach(var spec in Settings){string key=spec.Key;try{string result=send("getparam "+key);decimal value;if(!result.StartsWith("ok ")||!decimal.TryParse(result.Substring(3),NumberStyles.Float,CultureInfo.InvariantCulture,out value))continue;if(!f.IsDisposed)f.BeginInvoke((Action)delegate{if(!touched.Contains(key))boxes[key].Value=Math.Max(boxes[key].Minimum,Math.Min(boxes[key].Maximum,value));});}catch{}}});};
  var area=Screen.FromControl(owner).WorkingArea;f.Height=Math.Min(f.Height,area.Height-30);f.Show(owner);
 }
 public static string FormatStatus(string reply){
  if(!reply.StartsWith("ok "))return L.D(reply);
  var fields=new Dictionary<string,string>();foreach(string field in reply.Substring(3).Split(';')){int i=field.IndexOf('=');if(i>0)fields[field.Substring(0,i)]=field.Substring(i+1);}
  string state;fields.TryGetValue("state",out state);string text;
  switch(state){
   case "ACTIVE":text=L.P("Контроллер работает","Controller active");break;
   case "OFF":return L.P("Помощь выключена","Assistance disabled");
   case "NO_PLAYER":text=L.P("Загрузите сохранение","Load a save");break;
   case "NO_VEHICLE":text=L.P("Сядьте за руль машины или мотоцикла","Drive a car or motorcycle");break;
   case "PASSENGER":text=L.P("Нужно место водителя","Driver seat required");break;
   case "SCENE":text=L.P("Управление занято сценой или автопилотом","Scene or autopilot controls this vehicle");break;
   case "ENGINE_OFF":text=L.P("Двигатель выключен или транспорт разрушен","Engine off or vehicle destroyed");break;
   case "TILTED":text=L.P("Помощь приостановлена: сильный наклон или трюк","Assistance paused: excessive tilt or stunt");break;
   case "NO_GROUND":text=L.P("Помощь приостановлена: нет опоры","Assistance paused: no ground support");break;
   case "PAUSED":text=L.P("Меню или пауза","Menu or pause");break;
   case "RECOVERY":text=L.P("Ожидание после переворота","Settling after recovery");break;
   case "TIMESTEP":text=L.P("Ожидание игрового такта","Waiting for simulation step");break;
   case "MASS":text=L.P("Неподдерживаемая масса транспорта","Unsupported vehicle mass");break;
   case "WAITING":text=L.P("Подготовка контроллера","Preparing controller");break;
   default:text=L.P("Состояние: ","State: ")+(state??"?");break;
  }
  string kind;if(fields.TryGetValue("kind",out kind))text+=" · "+(kind=="BIKE"?L.P("Мотоцикл","Motorcycle"):L.P("Машина","Car"));
  string speed;decimal value;if(fields.TryGetValue("speed",out speed)&&decimal.TryParse(speed.Replace(',','.'),NumberStyles.Float,CultureInfo.InvariantCulture,out value))text+=" · "+value.ToString("0")+L.P(" км/ч"," km/h");
  return text;
 }
}
