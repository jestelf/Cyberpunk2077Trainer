using System;
using System.Drawing;
using System.Threading.Tasks;
using System.Windows.Forms;

static class CyberwareSlotEditor {
 static readonly string[][] Areas={
  new[]{"SystemReplacementCW","Операционная система","Operating system"},
  new[]{"FrontalCortexCW","Лобная доля","Frontal cortex"},
  new[]{"EyesCW","Лицо / глаза","Face / eyes"},
  new[]{"HandsCW","Ладони","Hands"},
  new[]{"NervousSystemCW","Нервная система","Nervous system"},
  new[]{"CardiovascularSystemCW","Кровеносная система","Circulatory system"},
  new[]{"MusculoskeletalSystemCW","Скелет","Skeleton"},
  new[]{"IntegumentarySystemCW","Кожа","Integumentary system"},
  new[]{"LegsCW","Ноги","Legs"}
 };
 public static void Open(Form owner,Func<string,string> send,Action<string> log){
  var f=new Form();Skin.Form(f,L.P("Слоты имплантов","Cyberware slots"),new Size(600,430));f.MinimumSize=new Size(500,430);f.AutoScroll=true;
  var panel=new TableLayoutPanel{Dock=DockStyle.Fill,Padding=new Padding(16),ColumnCount=2,RowCount=6};panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,65));panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,35));
  foreach(int height in new[]{120,38,38,42,42})panel.RowStyles.Add(new RowStyle(SizeType.Absolute,height));panel.RowStyles.Add(new RowStyle(SizeType.Percent,100));
  var note=Skin.Label("",10,Skin.Amber);note.Dock=DockStyle.Fill;
  var area=new ComboBox{Name="CyberwareArea",Dock=DockStyle.Fill,DropDownStyle=ComboBoxStyle.DropDownList,BackColor=Skin.Panel,ForeColor=Skin.Text};
  var count=new NumericUpDown{Name="CyberwareSlotCount",Minimum=0,Maximum=8,Value=2,Dock=DockStyle.Fill,BackColor=Skin.Panel,ForeColor=Skin.Text,Font=new Font("Segoe UI",12)};
  var current=Skin.Label("",10,Skin.Muted);current.Dock=DockStyle.Fill;
  var status=Skin.Label("",9,Skin.Muted);status.Dock=DockStyle.Fill;
  Button apply=null,restore=null,two=null;int generation=0;bool reading=false;int? currentValue=null;string currentError=null;
  Action load=delegate{
   if(reading||area.SelectedIndex<0)return;int request=++generation;string key=Areas[area.SelectedIndex][0];currentValue=null;currentError=null;current.Text=L.P("Чтение текущего числа...","Reading current count...");
   Task.Run(delegate{string result;try{result=send("getslots "+key);}catch(Exception e){result=e.Message;}
    if(!f.IsDisposed)try{f.BeginInvoke((Action)delegate{if(request!=generation)return;int value;if(result.StartsWith("ok ")&&int.TryParse(result.Substring(3),out value)){currentValue=value;count.Value=Math.Max(0,Math.Min(8,value));current.Text=L.P("Сейчас слотов: ","Current slots: ")+value;}else{currentError=result;current.Text=L.D(result);}});}catch{}
   });
  };
  Action<string,int> submit=delegate(string key,int value){
   apply.Enabled=restore.Enabled=two.Enabled=area.Enabled=count.Enabled=false;++generation;
   Task.Run(delegate{string message;try{string result=send("slots "+key+" "+value);message=result=="ok"?L.P("Слоты настроены. Откройте меню имплантов заново.","Slots updated. Reopen the cyberware menu."):L.D(result);}catch(Exception e){message=L.D(e.Message);}log(message);
    if(!f.IsDisposed)try{f.BeginInvoke((Action)delegate{status.Text=message;apply.Enabled=restore.Enabled=two.Enabled=area.Enabled=count.Enabled=true;load();});}catch{}
   });
  };
  apply=Skin.Button("",delegate{submit(Areas[area.SelectedIndex][0],(int)count.Value);},true);apply.Dock=DockStyle.Fill;
  restore=Skin.Button("",delegate{submit(Areas[area.SelectedIndex][0],0);});restore.Dock=DockStyle.Fill;
  two=Skin.Button("",delegate{area.SelectedIndex=0;submit("SystemReplacementCW",2);});two.Name="TwoOperatingSystemSlots";two.Dock=DockStyle.Fill;
  panel.Controls.Add(note,0,0);panel.SetColumnSpan(note,2);panel.Controls.Add(area,0,1);panel.Controls.Add(count,1,1);panel.Controls.Add(current,0,2);panel.SetColumnSpan(current,2);panel.Controls.Add(apply,0,3);panel.Controls.Add(restore,1,3);panel.Controls.Add(two,0,4);panel.SetColumnSpan(two,2);panel.Controls.Add(status,0,5);panel.SetColumnSpan(status,2);f.Controls.Add(panel);
  Action language=delegate{reading=true;int selected=Math.Max(0,area.SelectedIndex);area.Items.Clear();foreach(var row in Areas)area.Items.Add(L.P(row[1],row[2]));area.SelectedIndex=selected;reading=false;f.Text=L.P("Слоты имплантов","Cyberware slots");note.Text=L.P("Сохраняется с персонажем. Сначала закройте игровые меню. 0 — штатное число; уменьшение возможно только для пустых ячеек. Импланты устанавливайте у риппера или через «Установить вместе» в ItemSpawner. Оружие рук не расширяется.","Persists with the character. Close game menus first. 0 restores native count; removed slots must be empty. Install at a ripperdoc or with Install alongside in ItemSpawner. Arm weapon slots are excluded.");apply.Text=L.P("Применить","Apply");restore.Text=L.P("Штатное число","Native count");two.Text=L.P("Два слота операционной системы","Two operating system slots");};
  Action translated=delegate{language();current.Text=currentValue.HasValue?L.P("Сейчас слотов: ","Current slots: ")+currentValue.Value:currentError!=null?L.D(currentError):L.P("Чтение текущего числа...","Reading current count...");};
  translated();area.SelectedIndexChanged+=delegate{load();};f.Shown+=delegate{load();};L.Changed+=translated;f.FormClosed+=delegate{++generation;L.Changed-=translated;};f.Show(owner);
 }
}
