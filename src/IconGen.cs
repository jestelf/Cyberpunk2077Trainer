using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;

static class IconGen {
 static Bitmap Draw(int s,string letter,Color accent){
  var bmp=new Bitmap(s,s,PixelFormat.Format32bppArgb);
  using(var g=Graphics.FromImage(bmp)){
   g.SmoothingMode=SmoothingMode.AntiAlias;g.TextRenderingHint=TextRenderingHint.AntiAliasGridFit;g.Clear(Color.Transparent);
   var box=new RectangleF(s*0.02f,s*0.02f,s*0.96f,s*0.96f);
   using(var path=Rounded(box,s*0.18f))using(var bg=new LinearGradientBrush(box,Color.FromArgb(42,38,34),Color.FromArgb(16,15,14),90f))g.FillPath(bg,path);
   using(var pen=new Pen(accent,Math.Max(1.5f,s*0.06f)))g.DrawEllipse(pen,s*0.14f,s*0.14f,s*0.72f,s*0.72f);
   using(var f=new Font("Segoe UI",s*0.36f,FontStyle.Bold,GraphicsUnit.Pixel))using(var b=new SolidBrush(accent)){
    var fmt=new StringFormat{Alignment=StringAlignment.Center,LineAlignment=StringAlignment.Center};g.DrawString(letter,f,b,new RectangleF(0,s*0.02f,s,s),fmt);}
  }
  return bmp;
 }
 static GraphicsPath Rounded(RectangleF b,float r){var p=new GraphicsPath();float d=r*2;p.AddArc(b.X,b.Y,d,d,180,90);p.AddArc(b.Right-d,b.Y,d,d,270,90);p.AddArc(b.Right-d,b.Bottom-d,d,d,0,90);p.AddArc(b.X,b.Bottom-d,d,d,90,90);p.CloseFigure();return p;}
 static void Main(string[] args){
  string dir=args[0],letter=args[1];var accent=Color.FromArgb(int.Parse(args[2]),int.Parse(args[3]),int.Parse(args[4]));
  int[] sizes={16,20,24,32,40,48,64,128,256};var images=new byte[sizes.Length][];
  for(int i=0;i<sizes.Length;i++)using(var b=Draw(sizes[i],letter,accent))using(var ms=new MemoryStream()){b.Save(ms,ImageFormat.Png);images[i]=ms.ToArray();if(sizes[i]==256)File.WriteAllBytes(Path.Combine(dir,"icon.png"),images[i]);}
  using(var f=new BinaryWriter(File.Create(Path.Combine(dir,"icon.ico")))){
   f.Write((short)0);f.Write((short)1);f.Write((short)sizes.Length);int offset=6+16*sizes.Length;
   for(int i=0;i<sizes.Length;i++){f.Write((byte)(sizes[i]>=256?0:sizes[i]));f.Write((byte)(sizes[i]>=256?0:sizes[i]));f.Write((byte)0);f.Write((byte)0);f.Write((short)1);f.Write((short)32);f.Write(images[i].Length);f.Write(offset);offset+=images[i].Length;}
   foreach(var img in images)f.Write(img);
  }
 }
}
