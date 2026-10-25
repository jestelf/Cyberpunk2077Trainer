using System;
using System.Drawing;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;

static class AutodriveEditor {
 public static readonly string[][] Profiles={new[]{"Штатный","Native"},new[]{"Спокойный · 120","Relaxed · 120"},new[]{"Дорожный · 180","Road · 180"},new[]{"Быстрый · 240","Fast · 240"},new[]{"Максимальный · 300","Maximum · 300"}};
 public static readonly decimal[] Ceilings={180,120,180,240,300};
 public static readonly double[] Deceleration={0,3,3.5,4,4},Reaction={0,1.55,1.45,1.35,1.35},Reserve={0,12,16,20,25},Lateral={0,1.8,2.2,2.6,2.8};
 public static double StopDistance(double speedKmh,int mode){double v=speedKmh/3.6;return v*Reaction[mode]+v*v/(2*Deceleration[mode])+Reserve[mode];}
 public static void Open(Form owner,Func<string,string> send,Action<string> log){
  var f=new Form();Skin.Form(f,L.P("Адаптивный автодрайв","Adaptive autodrive"),new Size(900,760));f.MinimumSize=new Size(650,510);
  var panel=new TableLayoutPanel{Dock=DockStyle.Fill,Padding=new Padding(14),ColumnCount=2,RowCount=6};panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,64));panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,36));
  foreach(float height in new[]{105f,42f,38f})panel.RowStyles.Add(new RowStyle(SizeType.Absolute,height));panel.RowStyles.Add(new RowStyle(SizeType.Percent,100));panel.RowStyles.Add(new RowStyle(SizeType.Absolute,78));panel.RowStyles.Add(new RowStyle(SizeType.Absolute,100));f.Controls.Add(panel);
  var note=Skin.Label("",10,Skin.Amber);note.Dock=DockStyle.Fill;panel.Controls.Add(note,0,0);panel.SetColumnSpan(note,2);
  var mode=new ComboBox{Name="AutodriveProfile",Dock=DockStyle.Fill,DropDownStyle=ComboBoxStyle.DropDownList,BackColor=Skin.Panel,ForeColor=Skin.Text,FlatStyle=FlatStyle.Flat,Font=new Font("Segoe UI",11)};
  var limit=new NumericUpDown{Name="AutodriveCeiling",Minimum=60,Maximum=300,Value=180,Dock=DockStyle.Fill,BackColor=Skin.Panel,ForeColor=Skin.Text,Font=new Font("Segoe UI",12)};
  panel.Controls.Add(mode,0,1);panel.Controls.Add(limit,1,1);
  var explanation=Skin.Label("",9,Skin.Muted);explanation.Dock=DockStyle.Fill;panel.Controls.Add(explanation,0,2);panel.SetColumnSpan(explanation,2);
  var tabs=new TabControl{Dock=DockStyle.Fill,Name="AutodriveCalculations"};var stoppingPage=new TabPage();var turningPage=new TabPage();tabs.TabPages.Add(stoppingPage);tabs.TabPages.Add(turningPage);panel.Controls.Add(tabs,0,3);panel.SetColumnSpan(tabs,2);
  Func<DataGridView> makeGrid=delegate{var g=new DataGridView{Dock=DockStyle.Fill,ReadOnly=true,AllowUserToAddRows=false,AllowUserToDeleteRows=false,RowHeadersVisible=false,BackgroundColor=Skin.BG,BorderStyle=BorderStyle.None,EnableHeadersVisualStyles=false,AutoSizeColumnsMode=DataGridViewAutoSizeColumnsMode.Fill};g.DefaultCellStyle.BackColor=Skin.Panel;g.DefaultCellStyle.ForeColor=Skin.Text;g.DefaultCellStyle.SelectionBackColor=Skin.Hover;g.DefaultCellStyle.SelectionForeColor=Skin.Accent;g.ColumnHeadersDefaultCellStyle.BackColor=Skin.Off;g.ColumnHeadersDefaultCellStyle.ForeColor=Skin.Text;g.RowTemplate.Height=28;g.ColumnHeadersHeight=42;return g;};
  var stopping=makeGrid();var turning=makeGrid();stoppingPage.Controls.Add(stopping);turningPage.Controls.Add(turning);for(int i=0;i<4;i++)stopping.Columns.Add("S"+i,"");for(int i=0;i<2;i++)turning.Columns.Add("T"+i,"");
  var buttons=new FlowLayoutPanel{Dock=DockStyle.Fill,WrapContents=true};panel.Controls.Add(buttons,0,4);panel.SetColumnSpan(buttons,2);var status=Skin.Label("",9,Skin.Muted);status.Dock=DockStyle.Fill;panel.Controls.Add(status,0,5);panel.SetColumnSpan(status,2);
  bool updating=false,touched=false,busy=false,polling=false;Button apply=null,off=null,refresh=null;
  Action recalculate=delegate{int selected=Math.Max(0,mode.SelectedIndex);limit.Enabled=!busy&&selected>0;stopping.Rows.Clear();turning.Rows.Clear();
   if(selected==0){explanation.Text=L.P("Параметры игры сохраняются. Ускорение автодрайва и дополнительные проверки выключены.","Game parameters are preserved. Autodrive enhancement and additional checks are disabled.");return;}
   explanation.Text=L.P("Номинально: торможение ","Nominal: braking ")+Deceleration[selected].ToString("0.0")+L.P(" м/с². Слабые тормоза увеличат дистанцию; фактические значения ниже."," m/s². Weaker brakes increase distance; live values appear below.");
   foreach(int speed in new[]{60,90,120,160,180,200,240,250,300}){double distance=StopDistance(speed,selected);stopping.Rows.Add(speed,Math.Ceiling(distance),Math.Ceiling(Math.Max(120,distance*1.25)),(Reaction[selected]+speed/3.6/Deceleration[selected]).ToString("0.0"));}
   foreach(int radius in new[]{10,20,30,50,100,200,500,1000})turning.Rows.Add(radius,Math.Floor(Math.Min((double)limit.Value,Math.Sqrt(Lateral[selected]*radius)*3.6)));
  };
  Action<bool> enable=value=>{busy=!value;apply.Enabled=off.Enabled=refresh.Enabled=mode.Enabled=value;recalculate();};
  Action<string[]> submit=commands=>{enable(false);Task.Run(delegate{string message;try{foreach(string command in commands){string response=send(command);if(response!="ok")throw new InvalidOperationException(L.D(response));}message=L.P("Настройки приняты. Для новой поездки нажмите G в игре.","Settings accepted. Press G in game to start a new trip.");}catch(Exception ex){message=L.D(ex.Message);}log(message);if(!f.IsDisposed)try{f.BeginInvoke((Action)delegate{status.Text=message;enable(true);});}catch{}});};
  apply=Skin.Button("",delegate{int selected=Math.Max(0,mode.SelectedIndex);submit(new[]{"set ultra_autodrive 0","mul autodrive_mode "+selected,"mul autodrive_limit "+limit.Value.ToString(CultureInfo.InvariantCulture),"set ultra_autodrive "+(selected>0?"1":"0")});},true);apply.Name="ApplyAutodrive";apply.Width=220;
  off=Skin.Button("",delegate{mode.SelectedIndex=0;submit(new[]{"set ultra_autodrive 0","mul autodrive_mode 0"});});off.Name="DisableAutodrive";off.Width=190;
  Action poll=delegate{if(busy||polling)return;polling=true;Task.Run(delegate{string message;try{message=L.D(send("get autodrive").Replace("ok ",""));}catch(Exception ex){message=L.D(ex.Message);}if(!f.IsDisposed)try{f.BeginInvoke((Action)delegate{polling=false;if(!busy)status.Text=message;});}catch{}});};
  refresh=Skin.Button("",delegate{poll();});refresh.Name="RefreshAutodrive";refresh.Width=180;buttons.Controls.Add(apply);buttons.Controls.Add(off);buttons.Controls.Add(refresh);
  mode.SelectedIndexChanged+=delegate{if(updating)return;touched=true;limit.Value=Ceilings[Math.Max(0,mode.SelectedIndex)];recalculate();};limit.ValueChanged+=delegate{if(!updating)touched=true;recalculate();};
  Action language=delegate{int selected=Math.Max(0,mode.SelectedIndex);updating=true;mode.Items.Clear();foreach(var p in Profiles)mode.Items.Add(L.P(p[0],p[1]));mode.SelectedIndex=selected;updating=false;
   f.Text=L.P("Адаптивный автодрайв","Adaptive autodrive");note.Text=L.P("Штатный режим или предел 60–300 км/ч. Включайте до G: сначала короткая проверка тормозов, затем плавный разгон. Скорость снижается перед препятствиями, поворотами и целью. Смена настроек завершает текущую поездку. Цифры — расчётный запас, а не обещание постоянной скорости.","Native behavior or a 60–300 km/h ceiling. Enable before G: a brief brake check precedes gradual acceleration. Speed drops for obstacles, bends and the destination. Changing settings ends the current trip. Calculations are planning margins, not a promise of constant speed.");
   stoppingPage.Text=L.P("Торможение и обзор","Braking and lookahead");turningPage.Text=L.P("Повороты","Cornering");string[] headers={L.P("Скорость, км/ч","Speed, km/h"),L.P("Остановка с запасом, м","Stop with margin, m"),L.P("Обзор ИИ, м","AI lookahead, m"),L.P("Время с реакцией, с","Time incl. reaction, s")};for(int i=0;i<4;i++)stopping.Columns[i].HeaderText=headers[i];turning.Columns[0].HeaderText=L.P("Радиус поворота, м","Turn radius, m");turning.Columns[1].HeaderText=L.P("Расчётный предел, км/ч","Calculated ceiling, km/h");apply.Text=L.P("Применить профиль","Apply profile");off.Text=L.P("Штатный автодрайв","Native autodrive");refresh.Text=L.P("Обновить статус","Refresh status");recalculate();
  };language();L.Changed+=language;
  var timer=new System.Windows.Forms.Timer{Interval=1000};timer.Tick+=delegate{poll();};f.FormClosed+=delegate{timer.Stop();timer.Dispose();L.Changed-=language;};
  f.Shown+=delegate{timer.Start();Task.Run(delegate{int selected=0;decimal ceiling=180;try{string m=send("getparam autodrive_mode"),v=send("getparam autodrive_limit");if(!m.StartsWith("ok ")||!v.StartsWith("ok ")||!Int32.TryParse(m.Substring(3),out selected)||!Decimal.TryParse(v.Substring(3),NumberStyles.Float,CultureInfo.InvariantCulture,out ceiling))return;}catch{return;}if(!f.IsDisposed)try{f.BeginInvoke((Action)delegate{if(!touched){updating=true;mode.SelectedIndex=Math.Max(0,Math.Min(4,selected));limit.Value=Math.Max(60,Math.Min(300,ceiling));updating=false;recalculate();}});}catch{}});};
  var area=Screen.FromControl(owner).WorkingArea;f.Height=Math.Min(f.Height,area.Height-30);f.Show(owner);
  Action resize=delegate{bool small=f.ClientSize.Height<620;panel.RowStyles[0].Height=small?85:105;panel.RowStyles[4].Height=small?54:78;panel.RowStyles[5].Height=small?70:100;};f.ClientSizeChanged+=delegate{resize();};resize();
 }
}
