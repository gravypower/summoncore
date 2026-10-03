# Generates the placeholder finger-wag sprite sheet: Media\gag_wag_sheet.tga
# 1024x512, 4 columns x 2 rows of 256x256 frames, 32-bit TGA with alpha. Replace it with your own
# art (same layout, or change the sheet entry in Gag.lua) when the friend-recorded frames are ready.
#   powershell -ExecutionPolicy Bypass -File tools\make_gag_sheet.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "Media"
New-Item -ItemType Directory -Force $out | Out-Null

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

public static class WagGen {
    static GraphicsPath Round(float x, float y, float w, float h, float r) {
        var p = new GraphicsPath();
        p.AddArc(x, y, 2 * r, 2 * r, 180, 90);
        p.AddArc(x + w - 2 * r, y, 2 * r, 2 * r, 270, 90);
        p.AddArc(x + w - 2 * r, y + h - 2 * r, 2 * r, 2 * r, 0, 90);
        p.AddArc(x, y + h - 2 * r, 2 * r, 2 * r, 90, 90);
        p.CloseFigure();
        return p;
    }

    public static void Make(string path) {
        const int cell = 256, cols = 4, rows = 2;
        float[] angles = { -30, -15, 0, 15, 30, 15, 0, -15 };
        using (var bmp = new Bitmap(cell * cols, cell * rows, PixelFormat.Format32bppArgb))
        using (var g = Graphics.FromImage(bmp)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);
            var skin = new SolidBrush(Color.FromArgb(240, 190, 150));
            var nail = new SolidBrush(Color.FromArgb(255, 225, 215));
            var ink = new Pen(Color.Black, 6f) { LineJoin = LineJoin.Round };
            var motion = new Pen(Color.FromArgb(255, 60, 60), 7f) { StartCap = LineCap.Round, EndCap = LineCap.Round };
            for (int i = 0; i < angles.Length; i++) {
                int ox = (i % cols) * cell, oy = (i / cols) * cell;
                var saved = g.Save();
                g.SetClip(new Rectangle(ox, oy, cell, cell));
                // Motion arcs on the side the finger is moving toward.
                float a = angles[i];
                if (Math.Abs(a) > 5) {
                    float dir = a > 0 ? 1 : -1;
                    for (int k = 0; k < 3; k++) {
                        float y = oy + 40 + k * 26;
                        float x = ox + 128 + dir * 100;
                        g.DrawLine(motion, x, y, x + dir * 22, y - 12);
                    }
                }
                g.TranslateTransform(ox + 128, oy + 236);
                g.RotateTransform(a);
                using (var finger = Round(-17, -200, 34, 150, 17)) { g.FillPath(skin, finger); g.DrawPath(ink, finger); }
                g.FillEllipse(nail, -11, -192, 22, 28);
                using (var fist = Round(-52, -72, 104, 84, 26)) { g.FillPath(skin, fist); g.DrawPath(ink, fist); }
                using (var thumb = Round(-78, -58, 48, 30, 14)) { g.FillPath(skin, thumb); g.DrawPath(ink, thumb); }
                for (int k = 0; k < 3; k++) g.DrawLine(new Pen(Color.Black, 4f), -30 + k * 30, -24, -30 + k * 30, -4);
                g.Restore(saved);
            }
            Save(bmp, path);
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
[WagGen]::Make($path)
"{0}  {1:N1} MB" -f $path, ((Get-Item $path).Length / 1MB)
