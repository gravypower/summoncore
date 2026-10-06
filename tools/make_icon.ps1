# Draws the addon's icon in the Neon Index look: Media\icon.tga (256x256, 32-bit TGA with alpha), which the TOC's
# ## IconTexture points at, and tools\icon\summoncore_icon_512.png (512x512), for anywhere a picture of the addon is wanted
# (a GitHub organisation's avatar is what WowUp shows for an addon installed from GitHub).
# A dark rounded tile with a green glowing edge, a cyan summoning circle ringed with rune marks, and Zennit's Z in pink,
# in the addon's font (VT323). An original drawing.
#   powershell -ExecutionPolicy Bypass -File tools\make_icon.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$font = Join-Path $root "Media\fonts\VT323-Regular.ttf"
$pngDir = Join-Path $PSScriptRoot "icon"
New-Item -ItemType Directory -Force $pngDir | Out-Null

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;

public static class IconGen {
    static readonly Color Green = Color.FromArgb(0x4d, 0xff, 0x8f);
    static readonly Color Cyan = Color.FromArgb(0x5c, 0xe1, 0xff);
    static readonly Color Pink = Color.FromArgb(0xff, 0x6e, 0xdb);
    static readonly Color Ground = Color.FromArgb(0x04, 0x06, 0x0a);

    static GraphicsPath Round(float x, float y, float w, float h, float r) {
        var p = new GraphicsPath();
        p.AddArc(x, y, 2 * r, 2 * r, 180, 90);
        p.AddArc(x + w - 2 * r, y, 2 * r, 2 * r, 270, 90);
        p.AddArc(x + w - 2 * r, y + h - 2 * r, 2 * r, 2 * r, 0, 90);
        p.AddArc(x, y + h - 2 * r, 2 * r, 2 * r, 90, 90);
        p.CloseFigure();
        return p;
    }

    // A neon stroke: two wide faint passes for the glow, then the bright core.
    static void Glow(Action<Pen> draw, Color c, float core) {
        float[] widths = { core * 4f, core * 2.2f, core };
        int[] alphas = { 28, 70, 255 };
        for (int i = 0; i < 3; i++)
            using (var pen = new Pen(Color.FromArgb(alphas[i], c), widths[i]) { LineJoin = LineJoin.Round, StartCap = LineCap.Round, EndCap = LineCap.Round })
                draw(pen);
    }

    // Draws the icon at `size` px (everything is laid out on a 256 grid and scaled).
    static Bitmap Draw(int size, string fontPath) {
        var bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bmp)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            g.Clear(Color.Transparent);
            g.ScaleTransform(size / 256f, size / 256f);

            // the tile, with faint scanlines and a green edge
            using (var tile = Round(10, 10, 236, 236, 34)) {
                using (var fill = new SolidBrush(Ground)) g.FillPath(fill, tile);
                g.SetClip(tile);
                using (var scan = new Pen(Color.FromArgb(14, Green), 1)) for (int y = 12; y < 246; y += 4) g.DrawLine(scan, 10, y, 246, y);
                g.ResetClip();
                Glow(pen => g.DrawPath(pen, tile), Green, 4f);
            }

            // the summoning circle: two rings and rune marks between them
            float cx = 128, cy = 128;
            Glow(pen => g.DrawEllipse(pen, cx - 88, cy - 88, 176, 176), Cyan, 3.5f);
            Glow(pen => g.DrawEllipse(pen, cx - 70, cy - 70, 140, 140), Cyan, 2f);
            for (int i = 0; i < 12; i++) {
                double a = i * Math.PI / 6 + Math.PI / 12;
                float ca = (float)Math.Cos(a), sa = (float)Math.Sin(a);
                if (i % 3 == 0) { // a small diamond
                    float r = 79;
                    var pts = new PointF[] {
                        new PointF(cx + ca * (r - 6), cy + sa * (r - 6)), new PointF(cx + ca * r - sa * 5, cy + sa * r + ca * 5),
                        new PointF(cx + ca * (r + 6), cy + sa * (r + 6)), new PointF(cx + ca * r + sa * 5, cy + sa * r - ca * 5) };
                    Glow(pen => g.DrawPolygon(pen, pts), Cyan, 1.8f);
                } else { // a tick
                    Glow(pen => g.DrawLine(pen, cx + ca * 74, cy + sa * 74, cx + ca * 84, cy + sa * 84), Cyan, 2f);
                }
            }

            // Zennit's Z, centred on the circle
            var fonts = new PrivateFontCollection();
            fonts.AddFontFile(fontPath);
            using (var f = new Font(fonts.Families[0], 150, FontStyle.Regular, GraphicsUnit.Pixel))
            using (var path = new GraphicsPath()) {
                path.AddString("Z", f.FontFamily, (int)f.Style, f.Size, new PointF(0, 0), StringFormat.GenericTypographic);
                var b = path.GetBounds();
                using (var m = new Matrix()) {
                    m.Translate(cx - (b.X + b.Width / 2), cy - (b.Y + b.Height / 2));
                    path.Transform(m);
                }
                Glow(pen => g.DrawPath(pen, path), Pink, 2f);
                using (var fill = new SolidBrush(Pink)) g.FillPath(fill, path);
            }
        }
        return bmp;
    }

    public static void Make(string tgaPath, string pngPath, string fontPath) {
        using (var small = Draw(256, fontPath)) Save(small, tgaPath);
        using (var big = Draw(512, fontPath)) big.Save(pngPath, ImageFormat.Png);
    }

    // Uncompressed 32-bit TGA with alpha, rows stored bottom-up.
    static void Save(Bitmap bmp, string path) {
        int w = bmp.Width, h = bmp.Height;
        var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try {
            using (var fs = new FileStream(path, FileMode.Create, FileAccess.Write))
            using (var bw = new BinaryWriter(fs)) {
                bw.Write((byte)0); bw.Write((byte)0); bw.Write((byte)2);
                bw.Write((short)0); bw.Write((short)0); bw.Write((byte)0);
                bw.Write((short)0); bw.Write((short)0);
                bw.Write((short)w); bw.Write((short)h);
                bw.Write((byte)32); bw.Write((byte)8);
                var row = new byte[w * 4];
                for (int y = h - 1; y >= 0; y--) {
                    System.Runtime.InteropServices.Marshal.Copy(IntPtr.Add(data.Scan0, y * data.Stride), row, 0, row.Length);
                    bw.Write(row);
                }
            }
        } finally { bmp.UnlockBits(data); }
    }
}
"@

$tga = Join-Path $root "Media\icon.tga"
$png = Join-Path $pngDir "summoncore_icon_512.png"
[IconGen]::Make($tga, $png, $font)
Get-Item $tga, $png | Select-Object Name, Length
