using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows.Forms;

sealed class BindingSet : IDisposable {
 sealed class Entry { public string Id,Ru,En; public Keys Key; public Action Action; }
 readonly List<Entry> entries=new List<Entry>();
 readonly bool[] previous=new bool[256];
 readonly Timer timer=new Timer{Interval=16};
 readonly string file;
 public Func<bool> Enabled;
 public Func<int> TargetPid;
 public event Action Changed;
 public void Edit(Form owner,string id){
  var entry=entries.Find(x=>x.Id==id);if(entry==null)return;
  Keys? chosen=Capture(owner);if(!chosen.HasValue)return;
  if(chosen.Value!=Keys.None && entries.Any(x=>x!=entry && x.Key==chosen.Value)){MessageBox.Show(owner,L.P("Клавиша уже назначена другой функции.","This binding is assigned to another function."));return;}
  entry.Key=chosen.Value;Save();if(Changed!=null)Changed();
 }
 public BindingSet(string directory){file=Path.Combine(directory,"bindings.txt");timer.Tick+=delegate{Poll();};timer.Start();}
 public void Add(string id,string ru,string en,string key,Action action){Keys parsed=Parse(key);entries.Add(new Entry{Id=id,Ru=ru,En=en,Key=parsed,Action=action});}
 public void Load(){try{if(!File.Exists(file))return;foreach(string line in File.ReadAllLines(file)){int p=line.IndexOf('=');int key;if(p<0 || !int.TryParse(line.Substring(p+1),out key))continue;var entry=entries.Find(x=>x.Id==line.Substring(0,p));if(entry!=null)entry.Key=(Keys)key;}}catch{}}
 void Save(){Directory.CreateDirectory(Path.GetDirectoryName(file));File.WriteAllLines(file,entries.Select(x=>x.Id+"="+(int)x.Key));}
 public string Name(string id){var e=entries.Find(x=>x.Id==id);return e==null?"":Format(e.Key);}
 static Keys Parse(string text){
  if(String.IsNullOrEmpty(text))return Keys.None;Keys value=Keys.None;
  foreach(string part in text.Split('+')){string p=part.Trim();if(p=="Ctrl")value|=Keys.Control;else if(p=="Alt")value|=Keys.Alt;else if(p=="Shift")value|=Keys.Shift;else{if(p.StartsWith("Num"))p=p.Replace("Num","NumPad").Replace("NumPadMultiply","Multiply").Replace("NumPadAdd","Add").Replace("NumPadDecimal","Decimal").Replace("NumPadSubtract","Subtract");Keys k;if(Enum.TryParse<Keys>(p,true,out k))value|=k;}}
  return value;
 }
 public static string Format(Keys key){if(key==Keys.None)return L.P("без клавиши","unbound");string name=(key&Keys.KeyCode).ToString().Replace("NumPad","Num");switch(key&Keys.KeyCode){case Keys.Multiply:name="Num*";break;case Keys.Add:name="Num+";break;case Keys.Subtract:name="Num-";break;case Keys.Decimal:name="Num.";break;case Keys.Divide:name="Num/";break;}return ((key&Keys.Control)!=0?"Ctrl+":"")+((key&Keys.Alt)!=0?"Alt+":"")+((key&Keys.Shift)!=0?"Shift+":"")+name;}
 static bool Down(int key){return (GetAsyncKeyState(key)&0x8000)!=0;}
 static Keys Modifiers(){return (Down(17)?Keys.Control:Keys.None)|(Down(18)?Keys.Alt:Keys.None)|(Down(16)?Keys.Shift:Keys.None);}
 static Keys OwnModifier(int key){return key==16 || key==160 || key==161?Keys.Shift:key==17 || key==162 || key==163?Keys.Control:key==18 || key==164 || key==165?Keys.Alt:Keys.None;}
 void Poll(){
  bool active=false;uint pid;GetWindowThreadProcessId(GetForegroundWindow(),out pid);
  if(Enabled!=null && TargetPid!=null)active=Enabled() && pid==(uint)TargetPid();
  Keys mods=Modifiers();
  var fired=new List<Action>();
  for(int i=1;i<256;i++){bool down=Down(i);if(active && down && !previous[i])foreach(var e in entries)if((e.Key&Keys.KeyCode)==(Keys)i && (e.Key&Keys.Modifiers)==(mods&~OwnModifier(i)))fired.Add(e.Action);previous[i]=down;}
  foreach(var action in fired)action();
 }
 public void Show(Form owner){
  var f=new Form();Skin.Form(f,L.P("Привязки клавиш","Key bindings"),new Size(750,570));f.MinimumSize=new Size(600,400);f.AutoScroll=true;
  var list=new ListView{Dock=DockStyle.Fill,View=View.Details,FullRowSelect=true,MultiSelect=false,BackColor=Skin.Panel,ForeColor=Skin.Text,HideSelection=false};
  list.Columns.Add(L.P("Функция","Function"),485);list.Columns.Add(L.P("Клавиша","Binding"),190);
  Action refresh=delegate{list.Items.Clear();foreach(var entry in entries){var row=new ListViewItem(L.P(entry.Ru,entry.En));row.SubItems.Add(Format(entry.Key));row.Tag=entry;list.Items.Add(row);}};
  refresh();var bottom=new FlowLayoutPanel{Dock=DockStyle.Bottom,Height=72,Padding=new Padding(8)};
  var hint=Skin.Label(L.P("Клавиатура и кнопки мыши; действуют только при активной игре.","Keyboard and mouse buttons; active only while the game has focus."),9,Skin.Muted);hint.Width=700;hint.Height=22;bottom.Controls.Add(hint);
  var set=Skin.Button(L.P("Назначить","Assign"),delegate{if(list.SelectedItems.Count==0)return;var entry=(Entry)list.SelectedItems[0].Tag;Keys? chosen=Capture(f);if(!chosen.HasValue)return;if(chosen.Value!=Keys.None && entries.Any(x=>x!=entry && x.Key==chosen.Value)){MessageBox.Show(f,L.P("Клавиша уже назначена другой функции.","This binding is assigned to another function."));return;}entry.Key=chosen.Value;Save();refresh();});set.Width=160;bottom.Controls.Add(set);list.DoubleClick+=delegate{set.PerformClick();};
  var clear=Skin.Button(L.P("Убрать привязку","Unbind"),delegate{if(list.SelectedItems.Count==0)return;((Entry)list.SelectedItems[0].Tag).Key=Keys.None;Save();refresh();});clear.Width=160;bottom.Controls.Add(clear);
  f.Controls.Add(list);f.Controls.Add(bottom);f.ShowDialog(owner);f.Dispose();
 }
 static Keys? Capture(Form owner){
  Keys? result=null;var f=new Form();Skin.Form(f,L.P("Нажмите клавишу или кнопку мыши","Press a key or mouse button"),new Size(500,150));f.FormBorderStyle=FormBorderStyle.FixedDialog;f.MaximizeBox=false;f.MinimizeBox=false;
  var info=Skin.Label(L.P("Ctrl / Alt / Shift + клавиша; MButton / XButton1 / XButton2.\r\nDelete — убрать привязку, Esc — отменить.","Ctrl / Alt / Shift + key; MButton / XButton1 / XButton2.\r\nDelete unbinds; Esc cancels."),10,Skin.Text);info.Dock=DockStyle.Fill;f.Controls.Add(info);
  bool armed=false;var before=new bool[256];for(int i=1;i<256;i++)before[i]=Down(i);var scan=new Timer{Interval=16};int elapsed=0,pending=0;Keys pendingMods=Keys.None;
  scan.Tick+=delegate{elapsed+=16;if(elapsed>400)armed=true;for(int i=1;i<256;i++){bool down=Down(i);if(armed && down && !before[i] && i!=16 && i!=17 && i!=18){if(i==27){f.Close();return;}if(i==46){result=Keys.None;f.Close();return;}Keys own=OwnModifier(i);if(own!=Keys.None){pending=i;pendingMods=Modifiers()&~own;}else{result=(Keys)i|Modifiers();f.Close();break;}}before[i]=down;}if(!result.HasValue && pending!=0 && !Down(pending)){result=(Keys)pending|pendingMods;f.Close();}};
  f.Shown+=delegate{scan.Start();};f.ShowDialog(owner);scan.Dispose();f.Dispose();return result;
 }
 public void Dispose(){timer.Dispose();}
 [DllImport("user32.dll")]static extern short GetAsyncKeyState(int key);
 [DllImport("user32.dll")]static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr window,out uint pid);
}
