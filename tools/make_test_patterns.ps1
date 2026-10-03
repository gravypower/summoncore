# Generates the /st comic test textures: Media\comic_test_<size>.tga (24-bit uncompressed TGA,
# power-of-two squares). Output is git-ignored; rerun this script to recreate it.
#   powershell -ExecutionPolicy Bypass -File tools\make_test_patterns.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "Media"
New-Item -ItemType Directory -Force $out | Out-Null

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;

public static class TgaGen {
    public static void Make(int n, string path) {
        using (var bmp = new Bitmap(n, n, PixelFormat.Format24bppRgb))
        using (var g = Graphics.FromImage(bmp)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            g.Clear(Color.FromArgb(255, 222, 60));

            // Halftone dots grow toward the bottom-right.
            int cells = 32;
            float s = (float)n / cells;
            using (var red = new SolidBrush(Color.FromArgb(220, 40, 40))) {
                for (int y = 0; y < cells; y++)
                    for (int x = 0; x < cells; x++) {
                        float r = s * 0.48f * (x + y) / (2f * (cells - 1));
                        g.FillEllipse(red, (x + 0.5f) * s - r, (y + 0.5f) * s - r, 2 * r, 2 * r);
                    }
            }

            // Diagonal line to show edge aliasing.
            using (var pen = new Pen(Color.Black, Math.Max(1f, n / 256f)))
                g.DrawLine(pen, 0, 0, n, n);

            // Corner squares: orientation and tiling seams.
            int c = n / 8;
            g.FillRectangle(new SolidBrush(Color.FromArgb(230, 0, 0)), 0, 0, c, c);
            g.FillRectangle(new SolidBrush(Color.FromArgb(0, 170, 0)), n - c, 0, c, c);
            g.FillRectangle(new SolidBrush(Color.FromArgb(0, 60, 230)), 0, n - c, c, c);
            g.FillRectangle(new SolidBrush(Color.FromArgb(255, 0, 255)), n - c, n - c, c, c);

            // Centre label.
            float fs = n / 7f;
            using (var font = new Font("Arial Black", fs, FontStyle.Regular, GraphicsUnit.Pixel))
            using (var sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center }) {
                var box = new RectangleF(n * 0.14f, n * 0.38f, n * 0.72f, n * 0.24f);
                g.FillRectangle(Brushes.White, box);
                using (var pen = new Pen(Color.Black, Math.Max(2f, n / 128f))) g.DrawRectangle(pen, box.X, box.Y, box.Width, box.Height);
                g.DrawString(n + " px", font, Brushes.Black, box, sf);
            }

            // Fine 1px stripes along the bottom: they shimmer or blur if the image is downscaled badly.
            int band = n / 16;
            for (int x = 0; x < n; x++) {
                var col = (x % 2 == 0) ? Color.Black : Color.White;
                using (var p = new Pen(col, 1f)) g.DrawLine(p, x + 0.5f, n - band - c, x + 0.5f, n - c - 1);
            }

            // Thick comic panel border.
            using (var pen = new Pen(Color.Black, Math.Max(2f, n / 48f))) {
                float h = pen.Width / 2f;
                g.DrawRectangle(pen, h, h, n - pen.Width, n - pen.Width);
            }

            WriteTga(bmp, path);
        }
    }

    // Uncompressed 24-bit TGA, rows stored bottom-up.
    static void WriteTga(Bitmap bmp, string path) {
        int n = bmp.Width;
        var data = bmp.LockBits(new Rectangle(0, 0, n, n), ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
        try {
            using (var fs = new FileStream(path, FileMode.Create, FileAccess.Write))
            using (var w = new BinaryWriter(fs)) {
                w.Write((byte)0); w.Write((byte)0); w.Write((byte)2);
                w.Write((short)0); w.Write((short)0); w.Write((byte)0);
                w.Write((short)0); w.Write((short)0);
                w.Write((short)n); w.Write((short)n);
                w.Write((byte)24); w.Write((byte)0);
                var row = new byte[n * 3];
                for (int y = n - 1; y >= 0; y--) {
                    IntPtr p = IntPtr.Add(data.Scan0, y * data.Stride);
                    System.Runtime.InteropServices.Marshal.Copy(p, row, 0, row.Length);
                    w.Write(row);
                }
            }
        } finally { bmp.UnlockBits(data); }
    }
}
"@

foreach ($n in 256, 512, 1024, 2048) {
    $path = Join-Path $out "comic_test_$n.tga"
    [TgaGen]::Make($n, $path)
    "{0}  {1:N1} MB" -f $path, ((Get-Item $path).Length / 1MB)
}
