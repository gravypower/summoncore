# Generates the sprite sheet for the Zennit gag: Media\gag_wag_sheet.tga
# 1024x512, 4 columns x 2 rows of 256x256 frames, 32-bit TGA with alpha, drawn in the addon's Neon Index look:
# a dark scanline panel, a cartoon man with a big head and a patterned shirt wagging his finger, and "AH AH AH!"
# beside him. Everything is green glowing outlines (amber for the motion and the words). It is an original
# drawing, not traced from any film or photo. Replace it with your own art (same layout, or change the sheet entry
# in Gag.lua) when recorded frames are ready.
#   powershell -ExecutionPolicy Bypass -File tools\make_gag_sheet.ps1
# Set GAG_PREVIEW to a .png path to also save a copy you can look at.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "Media"
$font = Join-Path $out "fonts\VT323-Regular.ttf"
New-Item -ItemType Directory -Force $out | Out-Null

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;

public static class WagGen {
    static readonly Color Green = Color.FromArgb(0x4d, 0xff, 0x8f);
    static readonly Color Amber = Color.FromArgb(0xff, 0xc9, 0x4d);
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

    static Pen Line(Color c, int alpha, float width) {
        return new Pen(Color.FromArgb(alpha, c), width) { LineJoin = LineJoin.Round, StartCap = LineCap.Round, EndCap = LineCap.Round };
    }

    // A neon stroke: two wide faint passes for the glow, then the bright core.
    static void Glow(Action<Pen> draw, Color c, float core) {
        float[] widths = { core * 4f, core * 2.2f, core };
        int[] alphas = { 28, 70, 255 };
        for (int i = 0; i < 3; i++) using (var pen = Line(c, alphas[i], widths[i])) draw(pen);
    }

    static void Outline(Graphics g, GraphicsPath p, Color c, float core) {
        using (var fill = new SolidBrush(Ground)) g.FillPath(fill, p); // opaque, so lines behind it do not show through
        Glow(pen => g.DrawPath(pen, p), c, core);
    }

    static void Stroke(Graphics g, float x1, float y1, float x2, float y2, Color c, float core) {
        Glow(pen => g.DrawLine(pen, x1, y1, x2, y2), c, core);
    }

    static void Arc(Graphics g, float x, float y, float w, float h, float start, float sweep, Color c, float core) {
        Glow(pen => g.DrawArc(pen, x, y, w, h, start, sweep), c, core);
    }

    // The words, scaled to fit a box, drawn as filled letters with a glow.
    static void Words(Graphics g, string text, FontFamily family, float bx, float by, float bw, float bh) {
        using (var path = new GraphicsPath()) {
            path.AddString(text, family, 0, 40f, new PointF(0, 0), StringFormat.GenericTypographic);
            var b = path.GetBounds();
            float s = Math.Min(bw / b.Width, bh / b.Height);
            using (var m = new Matrix(s, 0, 0, s, bx - b.X * s, by - b.Y * s)) path.Transform(m);
            Glow(pen => g.DrawPath(pen, path), Amber, 2.2f);
            using (var brush = new SolidBrush(Amber)) g.FillPath(brush, path);
        }
    }

    // One man, front on, drawn from the back forwards. wag is the angle (degrees) of the raised forearm.
    static void Man(Graphics g, float wag) {
        // the arm hanging down
        using (var p = Round(34, 128, 18, 54, 9)) Outline(g, p, Green, 2.4f);
        using (var p = new GraphicsPath()) { p.AddEllipse(32, 178, 22, 18); Outline(g, p, Green, 2.4f); }
        // legs and shoes
        using (var p = Round(58, 192, 26, 42, 6)) Outline(g, p, Green, 2.4f);
        using (var p = Round(94, 192, 26, 42, 6)) Outline(g, p, Green, 2.4f);
        using (var p = Round(48, 230, 40, 16, 8)) Outline(g, p, Green, 2.4f);
        using (var p = Round(90, 230, 40, 16, 8)) Outline(g, p, Green, 2.4f);
        // the shirt, with a collar and its pattern
        using (var p = Round(50, 120, 80, 76, 16)) Outline(g, p, Green, 2.6f);
        Stroke(g, 80, 121, 90, 136, Green, 2f);
        Stroke(g, 100, 121, 90, 136, Green, 2f);
        float[][] marks = { new[] { 62f, 152f, 72f, 147f }, new[] { 84f, 160f, 95f, 164f }, new[] { 106f, 148f, 116f, 153f },
            new[] { 66f, 176f, 76f, 173f }, new[] { 98f, 180f, 108f, 175f }, new[] { 80f, 142f, 86f, 150f }, new[] { 112f, 168f, 120f, 163f } };
        foreach (var m in marks) Stroke(g, m[0], m[1], m[2], m[3], Green, 1.5f);
        // the head: big, with a cap of hair, shut smiling eyes and a wide smile
        using (var p = new GraphicsPath()) { p.AddEllipse(48, 26, 84, 94); Outline(g, p, Green, 2.6f); }
        using (var p = new GraphicsPath()) { p.AddArc(48, 26, 84, 94, 200, 140); p.CloseFigure(); Outline(g, p, Green, 2.6f); }
        Arc(g, 68, 70, 16, 12, 180, 180, Green, 2.2f);
        Arc(g, 96, 70, 16, 12, 180, 180, Green, 2.2f);
        Arc(g, 66, 80, 48, 28, 10, 160, Green, 2.4f);
        Stroke(g, 90, 78, 87, 88, Green, 1.8f);
        // the raised arm: a fixed upper arm, then the forearm, fist and finger swinging about the elbow
        var s = g.Save();
        g.TranslateTransform(124, 134);
        g.RotateTransform(30);
        using (var p = Round(0, -8, 56, 16, 8)) Outline(g, p, Green, 2.4f);
        g.Restore(s);
        s = g.Save();
        g.TranslateTransform(172, 162);
        g.RotateTransform(wag);
        using (var p = Round(-8, -46, 16, 54, 8)) Outline(g, p, Green, 2.4f);
        using (var p = Round(-4.5f, -98, 9, 38, 4.5f)) Outline(g, p, Green, 2.4f);
        using (var p = Round(-11, -66, 22, 24, 9)) Outline(g, p, Green, 2.4f);
        g.Restore(s);
    }

    public static void Make(string path, string preview, string fontFile) {
        const int cell = 256, cols = 4, rows = 2;
        float[] angles = { -20, -10, 0, 10, 20, 10, 0, -10 };
        using (var fonts = new PrivateFontCollection()) {
            FontFamily family = FontFamily.GenericMonospace;
            if (File.Exists(fontFile)) { fonts.AddFontFile(fontFile); family = fonts.Families[0]; }
            using (var bmp = new Bitmap(cell * cols, cell * rows, PixelFormat.Format32bppArgb))
            using (var g = Graphics.FromImage(bmp)) {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.Clear(Color.Transparent);
                for (int i = 0; i < angles.Length; i++) {
                    int ox = (i % cols) * cell, oy = (i / cols) * cell;
                    var saved = g.Save();
                    g.SetClip(new Rectangle(ox, oy, cell, cell));

                    // the panel: dark, with faint scanlines, a border and corner brackets
                    using (var b = new SolidBrush(Color.FromArgb(238, Ground))) g.FillRectangle(b, ox + 2, oy + 2, cell - 4, cell - 4);
                    using (var pen = new Pen(Color.FromArgb(16, Green), 1f))
                        for (int y = oy + 4; y < oy + cell - 2; y += 4) g.DrawLine(pen, ox + 3, y, ox + cell - 3, y);
                    using (var pen = Line(Green, 110, 2f)) g.DrawRectangle(pen, ox + 3, oy + 3, cell - 7, cell - 7);
                    int inset = 10, arm = 24;
                    foreach (int sx in new[] { -1, 1 }) foreach (int sy in new[] { -1, 1 }) {
                        float cx = sx < 0 ? ox + inset : ox + cell - inset, cy = sy < 0 ? oy + inset : oy + cell - inset;
                        Stroke(g, cx, cy, cx - sx * arm, cy, Green, 2.4f);
                        Stroke(g, cx, cy, cx, cy - sy * arm, Green, 2.4f);
                    }

                    // the man, bobbing a little on every other frame
                    g.TranslateTransform(ox, oy + (i % 2 == 0 ? 0 : -2));
                    Man(g, angles[i]);

                    // motion lines just outside the fingertip (the tip is 98 above the elbow, which swings by the angle)
                    float a = angles[i];
                    if (Math.Abs(a) > 5) {
                        double rad = a * Math.PI / 180;
                        float tipX = 172 + 98f * (float)Math.Sin(rad), tipY = 162 - 98f * (float)Math.Cos(rad);
                        for (int k = 0; k < 3; k++) {
                            float y = tipY - 6 + k * 14, x = tipX + 16;
                            Stroke(g, x, y, x + 18, y - 9, Amber, 2.2f);
                        }
                    }
                    g.ResetTransform();
                    g.TranslateTransform(ox, oy);
                    Words(g, "AH AH AH!", family, 128, 16, 100, 28);
                    g.Restore(saved);
                }
                Save(bmp, path);
                if (!String.IsNullOrEmpty(preview)) bmp.Save(preview, ImageFormat.Png);
            }
        }
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

$path = Join-Path $out "gag_wag_sheet.tga"
[WagGen]::Make($path, $env:GAG_PREVIEW, $font)
"{0}  {1:N1} MB" -f $path, ((Get-Item $path).Length / 1MB)
