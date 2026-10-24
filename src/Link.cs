using System;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Reflection;
using System.Security.Cryptography;
using System.Runtime.InteropServices;
using System.Text;

sealed class GameLink : IDisposable {
 readonly Process process;NamedPipeClientStream pipe;readonly object gate=new object();
 public readonly int Pid;
 public bool Alive{get{if(Game.WindowHookLoader){IntPtr h=OpenProcess(0x1000,false,Pid);if(h==IntPtr.Zero)return false;try{uint code;return GetExitCodeProcess(h,out code) && code==259;}finally{CloseHandle(h);}}try{return !process.HasExited;}catch{return false;}}}

 GameLink(Process p){process=p;Pid=p.Id;}

 public static GameLink Attach(out string state){
  var plugin=typeof(Game).GetField("PluginOnly");
  if(plugin!=null && (bool)plugin.GetValue(null))return AttachPlugin(out state);
  if(Game.WindowHookLoader)return AttachWindow(out state);
  state="Игра не запущена";
  Process[] all=Process.GetProcessesByName(Game.ProcessName);
  if(all.Length==0)return null;
  if(all.Length>1){state="Запущено несколько копий игры — оставьте одну";foreach(var x in all)x.Dispose();return null;}
  Process p=all[0];IntPtr h=OpenProcess(0x1F0FFF,false,p.Id);
  if(h==IntPtr.Zero){state="Нет доступа к процессу игры (запустите трейнер от имени администратора)";p.Dispose();return null;}
  try{
   ulong exe=FindModule(h,Game.ProcessName+".exe");
   if(exe==0){state="Игра загружается…";p.Dispose();return null;}
   uint lfanew=BitConverter.ToUInt32(Read(h,exe+0x3C,4),0);byte[] nt=Read(h,exe+lfanew,0x58);
   uint stamp=BitConverter.ToUInt32(nt,8),image=BitConverter.ToUInt32(nt,0x50);
   if((Game.ExpectedStamp!=0 && stamp!=Game.ExpectedStamp) || (Game.ExpectedImage!=0 && image!=Game.ExpectedImage)){state="Другая версия игры ("+stamp.ToString("X8")+") — "+Game.VersionHintRu;p.Dispose();return null;}
   if(!HasWindow(p.Id)){state="Игра загружается…";p.Dispose();return null;}
   if(FindModule(h,Game.BridgeDll)==0){
    string dll=ExtractBridge();
    if(!Inject(h,dll)){state="Не удалось загрузить мост в игру";p.Dispose();return null;}
   }
   var link=new GameLink(p);
   try{link.Connect(15000);}catch(Exception e){state="Мост не отвечает: "+e.Message;link.Dispose();return null;}
   string hello=link.Send("ping");
   if(!hello.StartsWith("ok")){state=hello.StartsWith("err ")?hello.Substring(4):hello;link.Dispose();return null;}
   state="ok";return link;
  }catch(Exception e){state="Ошибка подключения: "+e.Message;p.Dispose();return null;}
  finally{CloseHandle(h);}
 }

 static GameLink AttachPlugin(out string state){
  state="Игра не запущена";
  var all=Process.GetProcessesByName(Game.ProcessName);
  if(all.Length==0)return null;
  if(all.Length!=1){foreach(var p in all)p.Dispose();state="Запущено несколько копий игры — оставьте одну";return null;}
  var process=all[0];GameLink link=null;
  try{
   string path=process.MainModule.FileName;
   using(var stream=File.OpenRead(path))using(var sha=SHA256.Create()){
    string hash=BitConverter.ToString(sha.ComputeHash(stream)).Replace("-","");
    if(Game.ExpectedSha256.Length==0 || !String.Equals(hash,Game.ExpectedSha256,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException(L.P(Game.VersionHintRu,Game.VersionHintEn));
   }
   link=new GameLink(process);link.Connect(500);
   uint server;if(!GetNamedPipeServerProcessId(link.pipe.SafePipeHandle.DangerousGetHandle(),out server) || server!=(uint)process.Id)throw new IOException(L.P("Канал принадлежит другому процессу","Pipe belongs to a different process"));
   string answer=link.Send("ping");if(answer!="ok")throw new IOException(L.D(answer));
   state="ok";return link;
  }catch(Exception e){state=L.P("Мод не подключён: ","Mod not connected: ")+e.Message;if(link!=null)link.Dispose();else process.Dispose();return null;}
 }
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool GetNamedPipeServerProcessId(IntPtr pipe,out uint pid);

 static GameLink AttachWindow(out string state){
  state="Игра не запущена";Process[] all=Process.GetProcessesByName(Game.ProcessName);
  if(all.Length==0)return null;
  if(all.Length!=1){foreach(var item in all)item.Dispose();state="Запущено несколько копий игры — оставьте одну";return null;}
  Process p=all[0];GameLink link=null;
  try{
   IntPtr handle=OpenProcess(0x1000,false,p.Id);if(handle==IntPtr.Zero)throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
   string path;
   try{var value=new StringBuilder(32768);uint count=(uint)value.Capacity;if(!QueryFullProcessImageNameW(handle,0,value,ref count))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());path=value.ToString();}finally{CloseHandle(handle);}
   if(!String.Equals(Path.GetFileNameWithoutExtension(path),Game.ProcessName,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException(Game.VersionHintRu);
   using(var stream=File.OpenRead(path)){
    if(Game.ExpectedSha256.Length!=0){using(var hash=SHA256.Create()){string value=BitConverter.ToString(hash.ComputeHash(stream)).Replace("-","");if(!String.Equals(value,Game.ExpectedSha256,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException(Game.VersionHintRu);}stream.Position=0;}
    using(var reader=new BinaryReader(stream)){
     stream.Position=0x3C;int pe=reader.ReadInt32();if(pe<0 || pe>stream.Length-0x58)throw new InvalidDataException(Game.VersionHintRu);
     stream.Position=pe;if(reader.ReadUInt32()!=0x4550)throw new InvalidDataException(Game.VersionHintRu);
     stream.Position=pe+8;uint stamp=reader.ReadUInt32();stream.Position=pe+0x50;uint image=reader.ReadUInt32();
     if(stamp!=Game.ExpectedStamp || image!=Game.ExpectedImage)throw new InvalidOperationException(Game.VersionHintRu);
    }
   }
   uint thread=0,fallback=0;IntPtr targetWindow=IntPtr.Zero,fallbackWindow=IntPtr.Zero;
   long bestArea=-1;
   EnumWindows(delegate(IntPtr window,IntPtr unused){uint pid;uint tid=GetWindowThreadProcessId(window,out pid);if(pid!=(uint)p.Id)return true;var name=new StringBuilder(256);GetClassNameW(window,name,name.Capacity);if(name.ToString()=="ConsoleWindowClass")return true;if(fallback==0){fallback=tid;fallbackWindow=window;}WindowRect rect;long area=GetClientRect(window,out rect)?Math.Max(0,rect.Right-rect.Left)*(long)Math.Max(0,rect.Bottom-rect.Top):0;if(IsWindowVisible(window) && area>bestArea){bestArea=area;thread=tid;targetWindow=window;}return true;},IntPtr.Zero);
   if(targetWindow==IntPtr.Zero)targetWindow=fallbackWindow;
   if(thread==0)thread=fallback;if(thread==0){state="Игра загружается…";p.Dispose();return null;}
   link=new GameLink(p);
   try{link.Connect(200);if(link.Send("ping")=="ok"){state="ok";return link;}}catch{}
   if(link.pipe!=null){link.pipe.Dispose();link.pipe=null;}
   string dll=ExtractBridge();
   IntPtr module=LoadLibraryExW(dll,IntPtr.Zero,0);
   if(module==IntPtr.Zero)throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
   IntPtr hook=IntPtr.Zero;
   try{
    IntPtr callback=GetProcAddress(module,"TrainerWindowHook");if(callback==IntPtr.Zero)throw new InvalidOperationException("Не удалось загрузить мост в игру");
    hook=SetWindowsHookExW(3,callback,module,thread);if(hook==IntPtr.Zero)throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    var watch=Stopwatch.StartNew();
    while(watch.ElapsedMilliseconds<15000){PostMessageW(targetWindow,0,UIntPtr.Zero,IntPtr.Zero);PostThreadMessageW(thread,0,UIntPtr.Zero,IntPtr.Zero);try{link.Connect(300);break;}catch{if(link.pipe!=null){link.pipe.Dispose();link.pipe=null;}}}
    if(link.pipe==null || !link.pipe.IsConnected)throw new IOException("Мост не отвечает: игра загружается");
    string answer=link.Send("ping");if(answer!="ok")throw new InvalidOperationException(answer.StartsWith("err ")?answer.Substring(4):answer);
   }finally{if(hook!=IntPtr.Zero){UnhookWindowsHookEx(hook);PostThreadMessageW(thread,0,UIntPtr.Zero,IntPtr.Zero);}FreeLibrary(module);}
   state="ok";return link;
  }catch(Exception error){state="Ошибка подключения: "+error.Message;if(link!=null)link.Dispose();else p.Dispose();return null;}
 }

 static bool HasWindow(int pid){bool found=false;EnumWindows(delegate(IntPtr w,IntPtr l){uint p;GetWindowThreadProcessId(w,out p);if(p==pid && IsWindowVisible(w)){found=true;return false;}return true;},IntPtr.Zero);return found;}

 static string ExtractBridge(){
  string dir=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),Game.AppId);Directory.CreateDirectory(dir);
  string path=Path.Combine(dir,Game.BridgeDll);byte[] bytes;
  using(var s=Assembly.GetExecutingAssembly().GetManifestResourceStream(Game.BridgeDll)){bytes=new byte[s.Length];s.Read(bytes,0,bytes.Length);}
  string packaged=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,Game.BridgeDll);
  if(File.Exists(packaged) && Same(File.ReadAllBytes(packaged),bytes))return PhysicalPath(packaged);
  try{if(!File.Exists(path) || !Same(File.ReadAllBytes(path),bytes))File.WriteAllBytes(path,bytes);}catch(IOException){}
  return PhysicalPath(path);
 }
 static string PhysicalPath(string path){
  using(var stream=File.OpenRead(path)){
   var value=new StringBuilder(32768);
   uint size=GetFinalPathNameByHandleW(stream.SafeFileHandle.DangerousGetHandle(),value,(uint)value.Capacity,0);
   if(size==0 || size>=value.Capacity)throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
   string resolved=value.ToString();
   if(resolved.StartsWith(@"\\?\UNC\"))return @"\\"+resolved.Substring(8);
   return resolved.StartsWith(@"\\?\")?resolved.Substring(4):resolved;
  }
 }
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern uint GetFinalPathNameByHandleW(IntPtr file,StringBuilder value,uint length,uint flags);
 static bool Same(byte[] a,byte[] b){if(a.Length!=b.Length)return false;for(int i=0;i<a.Length;i++)if(a[i]!=b[i])return false;return true;}

 static bool Inject(IntPtr h,string dll){
  byte[] path=Encoding.Unicode.GetBytes(dll+"\0");
  IntPtr mem=VirtualAllocEx(h,IntPtr.Zero,(UIntPtr)path.Length,0x3000,0x04);if(mem==IntPtr.Zero)return false;
  try{
   UIntPtr n;if(!WriteProcessMemory(h,mem,path,(UIntPtr)path.Length,out n))return false;
   IntPtr load=GetProcAddress(GetModuleHandle("kernel32.dll"),"LoadLibraryW");uint tid;
   IntPtr t=CreateRemoteThread(h,IntPtr.Zero,UIntPtr.Zero,load,mem,0,out tid);if(t==IntPtr.Zero)return false;
   WaitForSingleObject(t,15000);CloseHandle(t);
   return FindModule(h,Game.BridgeDll)!=0;
  }finally{VirtualFreeEx(h,mem,UIntPtr.Zero,0x8000);}
 }

 void Connect(int ms){pipe=new NamedPipeClientStream(".",Game.Pipe,PipeDirection.InOut,PipeOptions.Asynchronous);pipe.Connect(ms);pipe.ReadMode=PipeTransmissionMode.Message;}

 public string Send(string command){
  lock(gate){
   if(pipe==null || !pipe.IsConnected)throw new InvalidOperationException("Мост отключён");
   byte[] req=Encoding.UTF8.GetBytes(command);pipe.Write(req,0,req.Length);pipe.Flush();
   var ms=new MemoryStream();var buf=new byte[65536];
   do{var read=pipe.ReadAsync(buf,0,buf.Length);if(!read.Wait(4500)){pipe.Dispose();throw new IOException(L.P("Время ответа истекло; результат команды неизвестен","Response timeout; command outcome unknown"));}int n=read.Result;if(n<=0)throw new IOException("Мост закрыл канал");ms.Write(buf,0,n);if(ms.Length>1048576)throw new IOException("Invalid response size");}while(!pipe.IsMessageComplete);
   return Encoding.UTF8.GetString(ms.ToArray());
  }
 }

 static byte[] Read(IntPtr h,ulong address,int size){var b=new byte[size];UIntPtr n;if(!ReadProcessMemory(h,(IntPtr)(long)address,b,(UIntPtr)size,out n))throw new InvalidOperationException("Чтение памяти игры не выполнено");return b;}
 static ulong FindModule(IntPtr h,string name){
  var mods=new IntPtr[4096];uint need;
  if(!EnumProcessModulesEx(h,mods,(uint)(IntPtr.Size*mods.Length),out need,3))return 0;
  int count=Math.Min(mods.Length,(int)(need/IntPtr.Size));var sb=new StringBuilder(260);
  for(int i=0;i<count;i++){sb.Length=0;if(GetModuleBaseNameW(h,mods[i],sb,260)>0 && String.Equals(sb.ToString(),name,StringComparison.OrdinalIgnoreCase))return (ulong)mods[i].ToInt64();}
  return 0;
 }

 public void Dispose(){try{if(pipe!=null)pipe.Dispose();}catch{}pipe=null;process.Dispose();}

 delegate bool EnumProc(IntPtr w,IntPtr l);
 [DllImport("user32.dll")]static extern bool EnumWindows(EnumProc f,IntPtr l);
 [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr w,out uint pid);
 [DllImport("user32.dll")]static extern bool IsWindowVisible(IntPtr w);
 [DllImport("kernel32.dll",SetLastError=true)]static extern IntPtr OpenProcess(uint access,bool inherit,int pid);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern bool QueryFullProcessImageNameW(IntPtr handle,uint flags,StringBuilder path,ref uint length);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern IntPtr LoadLibraryExW(string path,IntPtr file,uint flags);
 [DllImport("kernel32.dll")]static extern bool FreeLibrary(IntPtr module);
 [DllImport("user32.dll",SetLastError=true)]static extern IntPtr SetWindowsHookExW(int type,IntPtr callback,IntPtr module,uint thread);
 [StructLayout(LayoutKind.Sequential)]struct WindowRect{public int Left,Top,Right,Bottom;}
 [DllImport("user32.dll")]static extern bool GetClientRect(IntPtr window,out WindowRect rect);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetClassNameW(IntPtr window,StringBuilder name,int count);
 [DllImport("user32.dll")]static extern bool UnhookWindowsHookEx(IntPtr hook);
 [DllImport("user32.dll")]static extern bool PostThreadMessageW(uint thread,uint message,UIntPtr wParam,IntPtr lParam);
 [DllImport("user32.dll")]static extern bool PostMessageW(IntPtr window,uint message,UIntPtr wParam,IntPtr lParam);
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr h);
 [DllImport("kernel32.dll")]static extern bool GetExitCodeProcess(IntPtr process,out uint code);
 [DllImport("kernel32.dll",SetLastError=true)]static extern IntPtr VirtualAllocEx(IntPtr h,IntPtr addr,UIntPtr size,uint type,uint protect);
 [DllImport("kernel32.dll")]static extern bool VirtualFreeEx(IntPtr h,IntPtr addr,UIntPtr size,uint type);
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool WriteProcessMemory(IntPtr h,IntPtr addr,byte[] buffer,UIntPtr size,out UIntPtr written);
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool ReadProcessMemory(IntPtr h,IntPtr addr,[Out]byte[] buffer,UIntPtr size,out UIntPtr read);
 [DllImport("kernel32.dll",SetLastError=true)]static extern IntPtr CreateRemoteThread(IntPtr h,IntPtr attr,UIntPtr stack,IntPtr start,IntPtr param,uint flags,out uint tid);
 [DllImport("kernel32.dll")]static extern uint WaitForSingleObject(IntPtr h,uint ms);
 [DllImport("kernel32.dll",CharSet=CharSet.Ansi)]static extern IntPtr GetProcAddress(IntPtr mod,string name);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)]static extern IntPtr GetModuleHandle(string name);
 [DllImport("psapi.dll",SetLastError=true)]static extern bool EnumProcessModulesEx(IntPtr h,[Out]IntPtr[] mods,uint cb,out uint needed,uint filter);
 [DllImport("psapi.dll",CharSet=CharSet.Unicode)]static extern uint GetModuleBaseNameW(IntPtr h,IntPtr mod,StringBuilder name,uint size);
}
