using System;
using System.Collections.Generic;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

static class NumericEditor {

 public static void Open(Form owner,string ru,string en,decimal min,decimal max,decimal initial,int decimals,bool persistent,string command,string query,Func<string,string> send,Action<string> log,decimal? standard=null,decimal? sliderMin=null,decimal? sliderMax=null){
  decimal lo=Math.Max(min,sliderMin??min),hi=Math.Min(max,sliderMax??max);if(hi<=lo){lo=min;hi=max;}
  var f=new Form();Skin.Form(f,L.P(ru,en),new Size(560,300));f.MinimumSize=new Size(480,330);f.AutoScroll=true;
  var panel=new TableLayoutPanel{Dock=DockStyle.Fill,Padding=new Padding(16),ColumnCount=2,RowCount=5};panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));panel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,standard.HasValue?150:0));
  panel.RowStyles.Add(new RowStyle(SizeType.Absolute,50));panel.RowStyles.Add(new RowStyle(SizeType.Absolute,42));panel.RowStyles.Add(new RowStyle(SizeType.Absolute,48));panel.RowStyles.Add(new RowStyle(SizeType.Absolute,45));panel.RowStyles.Add(new RowStyle(SizeType.Percent,100));
  Func<string> noteText=delegate{return persistent?L.P("Изменение попадёт в сохранение. Отключение трейнера его не отменяет.","This edit persists in saves. Closing the trainer does not undo it."):L.P("Временный параметр. Ползунок — удобный диапазон, в поле можно ввести до ","Temporary parameter. The slider covers the usual range; type up to ")+max.ToString(CultureInfo.InvariantCulture)+L.P(".",".");};
  var note=Skin.Label(noteText(),10,Skin.Amber);note.Dock=DockStyle.Fill;
  var value=new NumericUpDown{Name="NumericValue",Minimum=min,Maximum=max,Value=Math.Max(min,Math.Min(max,initial)),DecimalPlaces=decimals,Increment=decimals>0?0.1m:1m,ThousandsSeparator=true,BackColor=Skin.Panel,ForeColor=Skin.Text,Dock=DockStyle.Fill,Font=new Font("Segoe UI",14)};
  var slider=new TrackBar{Name="NumericSlider",Minimum=0,Maximum=1000,TickStyle=TickStyle.None,Dock=DockStyle.Fill,BackColor=Skin.BG,SmallChange=decimals>0?1:Math.Max(1,(int)Math.Ceiling(1000m/Math.Max(1m,hi-lo))),LargeChange=50};
  var status=Skin.Label("",9,Skin.Muted);status.Dock=DockStyle.Fill;
  bool syncing=false;
  Action toSlider=delegate{syncing=true;slider.Value=(int)Math.Round(Math.Max(0m,Math.Min(1000m,(value.Value-lo)*1000m/(hi-lo))));syncing=false;};
  slider.ValueChanged+=delegate{if(syncing)return;decimal v=Math.Round(lo+(hi-lo)*slider.Value/1000m,decimals);syncing=true;value.Value=Math.Max(min,Math.Min(max,v));syncing=false;};
  value.ValueChanged+=delegate{if(!syncing)toSlider();};toSlider();
  Button apply=null,reset=null;
  Action<decimal> submit=delegate(decimal target){
   string number=target.ToString(CultureInfo.InvariantCulture);apply.Enabled=false;if(reset!=null)reset.Enabled=false;
   Task.Run(delegate{string message;try{string r=send(command+" "+number);if(r!="ok")throw new IOException(L.D(r));message=L.P("Команда принята: ","Command accepted: ")+L.P(ru,en)+" = "+number;}catch(Exception e){message=L.D(e.Message);}log(message);if(!f.IsDisposed)try{f.BeginInvoke((Action)delegate{status.Text=message;apply.Enabled=true;if(reset!=null)reset.Enabled=true;});}catch{}});
  };
  apply=Skin.Button(L.P("Применить","Apply"),delegate{submit(value.Value);},true);apply.Dock=DockStyle.Fill;
  panel.Controls.Add(note,0,0);panel.SetColumnSpan(note,2);panel.Controls.Add(value,0,1);panel.Controls.Add(slider,0,2);panel.SetColumnSpan(slider,2);panel.Controls.Add(apply,0,3);panel.SetColumnSpan(apply,2);panel.Controls.Add(status,0,4);panel.SetColumnSpan(status,2);
  if(standard.HasValue){reset=Skin.Button(L.P("Стандарт","Default"),delegate{value.Value=Math.Max(min,Math.Min(max,standard.Value));submit(value.Value);},false);reset.Name="NumericReset";reset.Dock=DockStyle.Fill;reset.Margin=new Padding(8,0,0,0);panel.Controls.Add(reset,1,1);}
  f.Controls.Add(panel);
  Action language=delegate{f.Text=L.P(ru,en);apply.Text=L.P("Применить","Apply");if(reset!=null)reset.Text=L.P("Стандарт","Default");note.Text=noteText();};
  L.Changed+=language;f.FormClosed+=delegate{L.Changed-=language;};
  bool touched=false;value.ValueChanged+=delegate{touched=true;};
  if(!String.IsNullOrEmpty(query))f.Shown+=delegate{Task.Run(delegate{try{string r=send(query);decimal current;if(!r.StartsWith("ok ") || !decimal.TryParse(r.Substring(3),NumberStyles.Float,CultureInfo.InvariantCulture,out current))throw new IOException(L.D(r));if(!f.IsDisposed)f.BeginInvoke((Action)delegate{if(!touched)value.Value=Math.Max(min,Math.Min(max,current));});}catch(Exception error){string message=L.P("Текущее значение не прочитано: ","Could not read current value: ")+L.D(error.Message);log(message);if(!f.IsDisposed)try{f.BeginInvoke((Action)delegate{if(!touched)status.Text=message;});}catch{}}});};
  f.Show(owner);
 }
}

sealed class CatalogItem {
 public string id,ru,en,icon,type,iconKind,area,family;
}
sealed class CatalogData {
 public readonly List<CatalogItem> Items=new List<CatalogItem>();
 public string Directory,Source,Error;
 public static CatalogData Load(string directory){
  var result=new CatalogData{Directory=directory,Source=""};var errors=new List<string>();
  foreach(string folder in new[]{directory,Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"catalog")}.Distinct(StringComparer.OrdinalIgnoreCase)){
   string path=Path.Combine(folder,"catalog.tsv");
   if(!File.Exists(path))continue;
   try{var candidate=new List<CatalogItem>();using(var reader=new StreamReader(path,Encoding.UTF8,true)){Read(reader,candidate);}if(candidate.Count>0){result.Items.AddRange(candidate);result.Directory=folder;result.Source=path;return result;}errors.Add(path+": "+L.P("нет корректных записей","no valid records"));}catch(Exception error){errors.Add(path+": "+error.Message);}
  }
  using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("catalog.tsv")){
   if(stream!=null)try{var candidate=new List<CatalogItem>();using(var reader=new StreamReader(stream,Encoding.UTF8,true)){Read(reader,candidate);}if(candidate.Count>0){result.Items.AddRange(candidate);result.Source=L.P("встроенный каталог","embedded catalog");return result;}}catch(Exception error){errors.Add(error.Message);}
  }
  result.Error=errors.Count>0?String.Join("; ",errors):L.P("Файл не найден: ","File not found: ")+Path.Combine(directory,"catalog.tsv");return result;
 }

 public static CatalogData Fetch(string directory,Func<string,string> send){
  var rows=new StringBuilder();int offset=0;
  for(int page=0;page<1000;page++){
   string response=send("get catalog "+offset.ToString(CultureInfo.InvariantCulture));int line=response.IndexOf('\n'),next;
   if(line<0 || !response.StartsWith("ok ") || !Int32.TryParse(response.Substring(3,line-3),out next))throw new IOException(L.D(response));
   rows.AppendLine(response.Substring(line+1));
   if(next==-1){
    var result=new CatalogData{Directory=directory,Source=L.P("текущая игра","current game")};
    using(var reader=new StringReader(rows.ToString()))Read(reader,result.Items);
    if(result.Items.Count==0)throw new IOException(L.P("Игра ещё не предоставила каталог предметов. Повторите после загрузки сохранения.","The game has not provided item records yet. Retry after loading a save."));
    System.IO.Directory.CreateDirectory(directory);string path=Path.Combine(directory,"catalog.tsv");
    File.WriteAllText(path+".new",rows.ToString(),Encoding.UTF8);if(File.Exists(path))File.Delete(path);File.Move(path+".new",path);return result;
   }
   if(next<=offset || next>100000)throw new IOException("Invalid catalog page");offset=next;
  }
  throw new IOException("Catalog page limit");
 }
 static void Read(TextReader reader,List<CatalogItem> items){
  var seen=new HashSet<string>(StringComparer.Ordinal);string row;
  while((row=reader.ReadLine())!=null){var p=row.Split('\t');if(p.Length<5 || !p[0].StartsWith("Items.",StringComparison.Ordinal) || !seen.Add(p[0]))continue;items.Add(new CatalogItem{id=p[0],ru=p[1],en=p[2],icon=p[3],type=p[4],iconKind=p.Length>5?p[5]:"",area=p.Length>6?p[6]:"",family=p.Length>7?p[7]:""});}
 }
}
static class CatalogKinds {
 public static readonly string[][] Names={new[]{"Все предметы","All items"},new[]{"Киберимпланты","Cyberware"},new[]{"Оружие","Weapons"},new[]{"Быстрые взломы","Quickhacks"},new[]{"Модули и обвесы","Mods & attachments"},new[]{"Расходники","Consumables"},new[]{"Материалы","Materials"},new[]{"Прочее","Other"}};
 public static int Group(CatalogItem x){string t=x.type.Replace("ItemType.","");if(t=="Cyberware" || t.StartsWith("Cyb_"))return 1;if(t.StartsWith("Wea_"))return 2;if(t=="Prt_Program")return 3;if(t.StartsWith("Prt_"))return 4;if(t=="Gen_CraftingMaterial")return 6;if(t.StartsWith("Con_"))return 5;return 7;}
 public static string Subkey(CatalogItem x){return Group(x)==1 && !String.IsNullOrEmpty(x.area)?x.area:x.type;}
 static readonly Dictionary<string,string[]> Labels=new Dictionary<string,string[]>{
 {"HandsCW",new[]{"Кисти","Hands"}},{"ArmsCW",new[]{"Руки","Arms"}},{"LegsCW",new[]{"Ноги","Legs"}},{"FrontalCortexCW",new[]{"Лобная доля","Frontal cortex"}},{"EyesCW",new[]{"Зрение","Eyes"}},{"SystemReplacementCW",new[]{"Операционные системы","Operating systems"}},{"CardiovascularSystemCW",new[]{"Кровеносная система","Circulatory system"}},{"NervousSystemCW",new[]{"Нервная система","Nervous system"}},{"MusculoskeletalSystemCW",new[]{"Скелет","Skeleton"}},{"IntegumentarySystemCW",new[]{"Кожа","Integumentary system"}},{"ImmuneSystemCW",new[]{"Иммунная система","Immune system"}},
 {"Wea_Handgun",new[]{"Пистолеты","Pistols"}},{"Wea_Revolver",new[]{"Револьверы","Revolvers"}},{"Wea_Rifle",new[]{"Штурмовые винтовки","Assault rifles"}},{"Wea_SubmachineGun",new[]{"Пистолеты-пулемёты","Submachine guns"}},{"Wea_Shotgun",new[]{"Дробовики","Shotguns"}},{"Wea_ShotgunDual",new[]{"Двуствольные дробовики","Double-barrel shotguns"}},{"Wea_SniperRifle",new[]{"Снайперские винтовки","Sniper rifles"}},{"Wea_PrecisionRifle",new[]{"Точные винтовки","Precision rifles"}},{"Wea_LightMachineGun",new[]{"Ручные пулемёты","Light machine guns"}},{"Wea_HeavyMachineGun",new[]{"Тяжёлые пулемёты","Heavy machine guns"}},
 {"Wea_Katana",new[]{"Катаны","Katanas"}},{"Wea_Knife",new[]{"Ножи","Knives"}},{"Wea_Machete",new[]{"Мачете","Machetes"}},{"Wea_OneHandedClub",new[]{"Одноручные дубинки","One-handed clubs"}},{"Wea_TwoHandedClub",new[]{"Двуручные дубинки","Two-handed clubs"}},{"Wea_Hammer",new[]{"Молоты","Hammers"}},{"Wea_Axe",new[]{"Топоры","Axes"}},{"Wea_Sword",new[]{"Мечи","Swords"}},{"Wea_LongBlade",new[]{"Длинные клинки","Long blades"}},{"Wea_Chainsword",new[]{"Цепные мечи","Chainswords"}},{"Wea_Fists",new[]{"Кулаки","Fists"}},
 {"Con_Edible",new[]{"Еда и напитки","Food & drink"}},{"Con_Inhaler",new[]{"Ингаляторы","Inhalers"}},{"Con_Injector",new[]{"Инъекторы","Injectors"}},{"Con_LongLasting",new[]{"Усилители","Boosters"}},{"Con_Skillbook",new[]{"Чипы навыков","Skill shards"}},{"Gen_CraftingMaterial",new[]{"Компоненты","Components"}},{"Gen_Junk",new[]{"Мусор","Junk"}},{"Gen_Jewellery",new[]{"Украшения","Jewellery"}},{"Gen_Readable",new[]{"Записи","Readables"}},{"Prt_Program",new[]{"Программы взлома","Quickhack programs"}},
 {"Prt_ShortScope",new[]{"Прицелы ближнего боя","Short scopes"}},{"Prt_LongScope",new[]{"Дальние прицелы","Long scopes"}},{"Prt_RifleMuzzle",new[]{"Насадки для винтовок","Rifle muzzles"}},{"Prt_HandgunMuzzle",new[]{"Насадки для пистолетов","Pistol muzzles"}}
 };
 public static string Label(string key){string k=key.Replace("EquipmentArea.","").Replace("ItemType.","");string[] names;return Labels.TryGetValue(k,out names)?L.P(names[0],names[1]):k.Replace("Prt_",L.P("Модуль: ","Mod: ")).Replace("Cyb_",L.P("Имплант: ","Cyberware: ")).Replace("_"," ");}
 public static bool CanInstall(CatalogItem x){return x!=null && Group(x)==1 && x.area!="EquipmentArea.ArmsCW" && x.area!="EquipmentArea.RightArm";}
}
sealed class CatalogImages : IDisposable {
 readonly Dictionary<string,Image> cache=new Dictionary<string,Image>();readonly string[] roots;readonly Stream packedStream;readonly ZipArchive packed;public int Loaded;
 public CatalogImages(string directory){roots=new[]{directory,Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),Game.AppId,"catalog"),Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"catalog")}.Distinct(StringComparer.OrdinalIgnoreCase).ToArray();packedStream=Assembly.GetExecutingAssembly().GetManifestResourceStream("catalog-icons.zip");if(packedStream!=null)packed=new ZipArchive(packedStream,ZipArchiveMode.Read);}
 public Image Get(CatalogItem item){Image found;if(String.IsNullOrEmpty(item.icon))return null;if(cache.TryGetValue(item.icon,out found))return found;found=null;
  foreach(string root in roots)try{string path=Path.GetFullPath(Path.Combine(root,item.icon));if(!path.StartsWith(Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase) || !File.Exists(path))continue;using(var original=Image.FromFile(path)){var thumb=new Bitmap(80,56);using(var g=Graphics.FromImage(thumb)){g.InterpolationMode=System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;float scale=Math.Min(80f/original.Width,56f/original.Height);float w=original.Width*scale,h=original.Height*scale;g.DrawImage(original,(80-w)/2,(56-h)/2,w,h);}found=thumb;Loaded++;}break;}catch{}
  if(found==null && packed!=null)try{var entry=packed.GetEntry(Path.GetFileName(item.icon));if(entry!=null)using(var stream=entry.Open())using(var original=Image.FromStream(stream)){found=new Bitmap(original);Loaded++;}}catch{}
  cache[item.icon]=found;return found;
 }
 public void Dispose(){foreach(var img in cache.Values)if(img!=null)img.Dispose();cache.Clear();if(packed!=null)packed.Dispose();if(packedStream!=null)packedStream.Dispose();}
}
static class CatalogWindow {
 public static void Open(Form owner,string directory,Func<string,string> send,Action<string> log){
  var data=CatalogData.Load(directory);var catalog=data.Items;var thumbs=new CatalogImages(data.Directory);var filtered=new List<CatalogItem>();int category=0;string subkey="";bool busy=false,updating=false;
  var f=new Form();Skin.Form(f,"ItemSpawner",new Size(1120,720));f.MinimumSize=new Size(780,480);
  var layout=new TableLayoutPanel{Dock=DockStyle.Fill,Padding=new Padding(12),ColumnCount=1,RowCount=3};layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));layout.RowStyles.Add(new RowStyle(SizeType.Absolute,50));layout.RowStyles.Add(new RowStyle(SizeType.Percent,100));layout.RowStyles.Add(new RowStyle(SizeType.Absolute,134));f.Controls.Add(layout);
  var top=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=3,RowCount=1};top.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));top.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,235));top.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,155));
  var search=new TextBox{Name="CatalogSearch",Dock=DockStyle.Fill,BackColor=Skin.Panel,ForeColor=Skin.Text,Font=new Font("Segoe UI",12),Margin=new Padding(0,6,10,6)};var types=new ComboBox{Name="CatalogTypes",Dock=DockStyle.Fill,DropDownStyle=ComboBoxStyle.DropDownList,BackColor=Skin.Panel,ForeColor=Skin.Text,FlatStyle=FlatStyle.Flat,Margin=new Padding(0,6,10,6)};top.Controls.Add(search,0,0);top.Controls.Add(types,1,0);layout.Controls.Add(top,0,0);
  var body=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=2,RowCount=1,Margin=Padding.Empty};body.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,185));body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));layout.Controls.Add(body,0,1);
  var groups=new ListBox{Name="CatalogCategories",Dock=DockStyle.Fill,BackColor=Skin.Panel,ForeColor=Skin.Text,BorderStyle=BorderStyle.None,ItemHeight=34,DrawMode=DrawMode.OwnerDrawFixed,IntegralHeight=false,Margin=new Padding(0,0,10,0)};groups.DrawItem+=delegate(object sender,DrawItemEventArgs e){if(e.Index<0)return;bool on=(e.State&DrawItemState.Selected)!=0;using(var b=new SolidBrush(on?Skin.Hover:Skin.Panel))e.Graphics.FillRectangle(b,e.Bounds);if(on)using(var b=new SolidBrush(Skin.Accent))e.Graphics.FillRectangle(b,e.Bounds.X,e.Bounds.Y,3,e.Bounds.Height);TextRenderer.DrawText(e.Graphics,groups.Items[e.Index].ToString(),groups.Font,new Rectangle(e.Bounds.X+9,e.Bounds.Y,e.Bounds.Width-10,e.Bounds.Height),on?Skin.Accent:Skin.Text,TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis|TextFormatFlags.NoPrefix);};body.Controls.Add(groups,0,0);
  var grid=new DataGridView{Name="CatalogGrid",Dock=DockStyle.Fill,VirtualMode=true,ReadOnly=true,AllowUserToAddRows=false,AllowUserToDeleteRows=false,AllowUserToResizeRows=false,MultiSelect=false,SelectionMode=DataGridViewSelectionMode.FullRowSelect,RowHeadersVisible=false,BackgroundColor=Skin.BG,BorderStyle=BorderStyle.None,EnableHeadersVisualStyles=false,AutoGenerateColumns=false,CellBorderStyle=DataGridViewCellBorderStyle.SingleHorizontal,GridColor=Skin.Off};grid.RowTemplate.Height=62;grid.DefaultCellStyle.BackColor=Skin.Panel;grid.DefaultCellStyle.ForeColor=Skin.Text;grid.DefaultCellStyle.SelectionBackColor=Skin.Hover;grid.DefaultCellStyle.SelectionForeColor=Skin.Accent;grid.ColumnHeadersDefaultCellStyle.BackColor=Skin.Off;grid.ColumnHeadersDefaultCellStyle.ForeColor=Skin.Text;grid.ColumnHeadersHeight=32;
  var icon=new DataGridViewImageColumn{Name="Icon",Width=88,ImageLayout=DataGridViewImageCellLayout.Zoom};var missing=new Bitmap(80,56);using(var g=Graphics.FromImage(missing))using(var font=new Font("Segoe UI",9))TextRenderer.DrawText(g,"—",font,new Rectangle(0,0,80,56),Skin.Muted,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);icon.DefaultCellStyle.NullValue=missing;grid.Columns.Add(icon);grid.Columns.Add(new DataGridViewTextBoxColumn{Name="Title",AutoSizeMode=DataGridViewAutoSizeColumnMode.Fill,MinimumWidth=180,FillWeight=65});grid.Columns.Add(new DataGridViewTextBoxColumn{Name="Kind",AutoSizeMode=DataGridViewAutoSizeColumnMode.Fill,MinimumWidth=150,FillWeight=35});foreach(DataGridViewColumn col in grid.Columns)col.SortMode=DataGridViewColumnSortMode.NotSortable;body.Controls.Add(grid,1,0);
  var bottom=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=4,RowCount=4,Margin=Padding.Empty};bottom.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,115));bottom.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,170));bottom.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));bottom.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,140));bottom.RowStyles.Add(new RowStyle(SizeType.Absolute,28));bottom.RowStyles.Add(new RowStyle(SizeType.Absolute,28));bottom.RowStyles.Add(new RowStyle(SizeType.Absolute,40));bottom.RowStyles.Add(new RowStyle(SizeType.Percent,100));layout.Controls.Add(bottom,0,2);
  var detail=Skin.Label("",9,Skin.Muted);detail.Dock=DockStyle.Fill;bottom.Controls.Add(detail,0,0);bottom.SetColumnSpan(detail,4);var note=Skin.Label("",9,Skin.Amber);note.Dock=DockStyle.Fill;bottom.Controls.Add(note,0,1);bottom.SetColumnSpan(note,4);
  var count=new NumericUpDown{Name="CatalogQuantity",Minimum=1,Maximum=100000,Value=1,Dock=DockStyle.Fill,BackColor=Skin.Panel,ForeColor=Skin.Text};bottom.Controls.Add(count,0,2);var status=Skin.Label("",9,Skin.Muted);status.Dock=DockStyle.Fill;bottom.Controls.Add(status,0,3);bottom.SetColumnSpan(status,4);
  Button give=null,equip=null;Func<CatalogItem> selected=delegate{return grid.CurrentCell!=null && grid.CurrentCell.RowIndex>=0 && grid.CurrentCell.RowIndex<filtered.Count?filtered[grid.CurrentCell.RowIndex]:null;};
  Action refreshActions=delegate{var item=selected();give.Enabled=!busy && item!=null;equip.Enabled=!busy && CatalogKinds.CanInstall(item);count.Enabled=!busy;detail.Text=item==null?L.P("Выберите предмет. Поиск работает по названию и ID.","Select an item. Search by name or ID."):item.id+"  ·  "+CatalogKinds.Label(CatalogKinds.Subkey(item))+ (item.iconKind=="model"?L.P("  ·  иконка модели; скин может отличаться","  ·  model icon; skin may differ"):thumbs.Get(item)==null?L.P("  ·  значок категории","  ·  category icon"):"");};
  Action<bool> execute=delegate(bool install){var item=selected();if(busy || item==null || install && !CatalogKinds.CanInstall(item))return;int quantity=(int)count.Value;busy=true;refreshActions();Task.Run(delegate{string message;try{string answer=send(install?"equip "+item.id:"give "+item.id+" "+quantity);if(answer!="ok")throw new IOException(L.D(answer));message=(install?L.P("Установлен дополнительно: ","Installed alongside: "):L.P("Команда выдачи принята: ","Spawn command accepted: "))+L.P(item.ru,item.en)+(install?"":" ×"+quantity);}catch(Exception error){message=L.D(error.Message);}log(message);if(!f.IsDisposed)try{f.BeginInvoke((Action)delegate{busy=false;refreshActions();status.Text=message;});}catch{}});};
  give=Skin.Button(L.P("Выдать","Spawn"),delegate{execute(false);},true);give.Name="CatalogGive";give.Dock=DockStyle.Fill;equip=Skin.Button(L.P("Установить вместе","Install alongside"),delegate{execute(true);});equip.Name="CatalogEquip";equip.Dock=DockStyle.Fill;bottom.Controls.Add(give,1,2);bottom.Controls.Add(equip,2,2);var copy=Skin.Button(L.P("Копировать ID","Copy ID"),delegate{var item=selected();if(item!=null)try{Clipboard.SetText(item.id);}catch{}});copy.Dock=DockStyle.Fill;bottom.Controls.Add(copy,3,2);
  grid.CellPainting+=delegate(object sender,DataGridViewCellPaintingEventArgs e){if(e.RowIndex<0 || e.RowIndex>=filtered.Count || e.ColumnIndex!=0)return;e.PaintBackground(e.CellBounds,true);var item=filtered[e.RowIndex];var img=thumbs.Get(item);if(img!=null){float scale=Math.Min((e.CellBounds.Width-8f)/img.Width,(e.CellBounds.Height-6f)/img.Height);float w=img.Width*scale,h=img.Height*scale;e.Graphics.DrawImage(img,e.CellBounds.X+(e.CellBounds.Width-w)/2,e.CellBounds.Y+(e.CellBounds.Height-h)/2,w,h);}else{string mark=new[]{"◇","▦","⌁","⌘","⚙","+","⬡","◇"}[CatalogKinds.Group(item)];TextRenderer.DrawText(e.Graphics,mark,f.Font,e.CellBounds,Skin.Accent,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);}e.Handled=true;};
  grid.CellValueNeeded+=delegate(object sender,DataGridViewCellValueEventArgs e){if(e.RowIndex<0 || e.RowIndex>=filtered.Count)return;var item=filtered[e.RowIndex];e.Value=e.ColumnIndex==0?(object)thumbs.Get(item):e.ColumnIndex==1?L.P(item.ru,item.en):CatalogKinds.Label(CatalogKinds.Subkey(item));};grid.CellToolTipTextNeeded+=delegate(object sender,DataGridViewCellToolTipTextNeededEventArgs e){if(e.RowIndex>=0 && e.RowIndex<filtered.Count)e.ToolTipText=filtered[e.RowIndex].id;};grid.SelectionChanged+=delegate{if(give!=null && equip!=null)refreshActions();};
  Action filter=delegate{if(updating)return;string query=search.Text.Trim();grid.RowCount=0;filtered=catalog.Where(x=>(category==0 || CatalogKinds.Group(x)==category) && (subkey=="" || CatalogKinds.Subkey(x)==subkey) && (x.ru+" "+x.en+" "+x.id+" "+x.family).IndexOf(query,StringComparison.OrdinalIgnoreCase)>=0).OrderBy(x=>L.P(x.ru,x.en),StringComparer.CurrentCultureIgnoreCase).ThenBy(x=>x.id).ToList();grid.RowCount=filtered.Count;if(filtered.Count>0)grid.CurrentCell=grid.Rows[0].Cells[1];grid.Invalidate();refreshActions();status.Text=catalog.Count==0?L.P("Каталог не загружен: ","Catalog not loaded: ")+data.Error:filtered.Count+L.P(" из "," of ")+catalog.Count+L.P(" предметов"," items");};
  var subkeys=new List<string>();Action rebuildTypes=delegate{updating=true;subkeys.Clear();subkeys.Add("");subkeys.AddRange(catalog.Where(x=>category==0 || CatalogKinds.Group(x)==category).Select(CatalogKinds.Subkey).Distinct().OrderBy(CatalogKinds.Label));types.Items.Clear();foreach(var key in subkeys)types.Items.Add(key==""?L.P("Все типы / слоты","All types / slots"):CatalogKinds.Label(key));types.SelectedIndex=0;subkey="";updating=false;};Action rebuildGroups=delegate{groups.Items.Clear();for(int i=0;i<CatalogKinds.Names.Length;i++){int id=i;groups.Items.Add(L.P(CatalogKinds.Names[i][0],CatalogKinds.Names[i][1])+"  "+(i==0?catalog.Count:catalog.Count(x=>CatalogKinds.Group(x)==id)));}};
  search.TextChanged+=delegate{filter();};types.SelectedIndexChanged+=delegate{if(updating)return;subkey=types.SelectedIndex>=0?subkeys[types.SelectedIndex]:"";filter();};groups.SelectedIndexChanged+=delegate{if(updating)return;category=Math.Max(0,groups.SelectedIndex);rebuildTypes();filter();};

  Button reload=null;Action<bool> load=delegate(bool refresh){
   if(busy)return;busy=true;reload.Enabled=false;refreshActions();status.Text=L.P("Загрузка каталога из игры…","Loading catalog from game…");
   Task.Run(delegate{
    CatalogData loaded=null;string error=null;
    try{loaded=CatalogData.Fetch(directory,send);}catch(Exception ex){error=L.D(ex.Message);}
    if(!f.IsDisposed)try{f.BeginInvoke((Action)delegate{
     busy=false;reload.Enabled=true;
     if(loaded!=null){data=loaded;catalog=data.Items;grid.RowCount=0;thumbs.Dispose();thumbs=new CatalogImages(data.Directory);updating=true;rebuildGroups();groups.SelectedIndex=category;updating=false;rebuildTypes();filter();log("ItemSpawner: "+catalog.Count+" · "+data.Source);}
     else{refreshActions();status.Text=error;log(error);}
    });}catch{}
   });
  };
  reload=Skin.Button(L.P("Обновить список","Reload list"),delegate{load(true);});reload.Dock=DockStyle.Fill;top.Controls.Add(reload,2,0);
  if(catalog.Count==0)f.Shown+=delegate{load(false);};

  Action language=delegate{Skin.Cue(search,L.P("Поиск по названию, ID или семейству импланта…","Search by name, ID or cyberware family…"));icon.HeaderText=L.P("Иконка","Icon");grid.Columns[1].HeaderText=L.P("Предмет","Item");grid.Columns[2].HeaderText=L.P("Тип / слот","Type / slot");give.Text=L.P("Выдать","Spawn");equip.Text=L.P("Установить вместе","Install alongside");copy.Text=L.P("Копировать ID","Copy ID");reload.Text=L.P("Обновить список","Reload list");note.Text=L.P("Выдача сохраняется в игре. «Установить вместе» — только для полученных имплантов; оружие рук не совмещается.","Spawned items persist. Install alongside requires owned cyberware; simultaneous arm weapons are unsupported.");updating=true;rebuildGroups();groups.SelectedIndex=category;updating=false;rebuildTypes();filter();};L.Changed+=language;f.FormClosed+=delegate{L.Changed-=language;thumbs.Dispose();missing.Dispose();};language();log("ItemSpawner: "+catalog.Count+" · "+data.Source);f.Show(owner);
 }
}
