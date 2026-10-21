$code = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public class LauncherIconExporter
{
    public static Bitmap LoadBitmapNoLock(string path)
    {
        using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
        {
            var orig = Image.FromStream(fs);
            var clone = new Bitmap(orig.Width, orig.Height, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(clone))
            {
                g.DrawImage(orig, 0, 0, orig.Width, orig.Height);
            }
            orig.Dispose();
            return clone;
        }
    }

    public static Bitmap ResizeImage(Bitmap src, int width, int height)
    {
        Bitmap dest = new Bitmap(width, height, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(dest))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.DrawImage(src, 0, 0, width, height);
        }
        return dest;
    }
}
"@

Add-Type -TypeDefinition $code -ReferencedAssemblies "System.Drawing.dll"

$masterPng = "d:\DoAn_LTTBDDNC\money_tracker_app\assets\images\mono_logo_master_1024.png"
$fgPng = "d:\DoAn_LTTBDDNC\money_tracker_app\assets\images\app_icon_liquid_glass_foreground.png"

$masterBmp = [LauncherIconExporter]::LoadBitmapNoLock($masterPng)
$fgBmp = [LauncherIconExporter]::LoadBitmapNoLock($fgPng)

Write-Output "Master loaded: $($masterBmp.Width)x$($masterBmp.Height)"
Write-Output "Foreground loaded: $($fgBmp.Width)x$($fgBmp.Height)"

# 1. Update app_icon_liquid_glass.png
$appIconPath = "d:\DoAn_LTTBDDNC\money_tracker_app\assets\images\app_icon_liquid_glass.png"
$masterBmp.Save($appIconPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output "1. Updated $appIconPath"

# 2. Android Mipmaps
$androidMipmaps = @{
    "mipmap-mdpi" = @{ "launcher" = 48; "fg" = 108 }
    "mipmap-hdpi" = @{ "launcher" = 72; "fg" = 162 }
    "mipmap-xhdpi" = @{ "launcher" = 96; "fg" = 216 }
    "mipmap-xxhdpi" = @{ "launcher" = 144; "fg" = 324 }
    "mipmap-xxxhdpi" = @{ "launcher" = 192; "fg" = 432 }
}

foreach ($folder in $androidMipmaps.Keys) {
    $dir = "d:\DoAn_LTTBDDNC\money_tracker_app\android\app\src\main\res\$folder"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    
    $lSize = $androidMipmaps[$folder]["launcher"]
    $fSize = $androidMipmaps[$folder]["fg"]
    
    $lBmp = [LauncherIconExporter]::ResizeImage($masterBmp, $lSize, $lSize)
    $lPath = "$dir\ic_launcher.png"
    $lBmp.Save($lPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $lBmp.Dispose()
    
    $fBmp = [LauncherIconExporter]::ResizeImage($fgBmp, $fSize, $fSize)
    $fPath = "$dir\ic_launcher_foreground.png"
    $fBmp.Save($fPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $fBmp.Dispose()

    Write-Output "  Exported $folder (launcher: ${lSize}px, fg: ${fSize}px)"
}

# 3. iOS AppIcon set
$iosSizes = @(
    @{ "name" = "Icon-App-1024x1024@1x.png"; "size" = 1024 },
    @{ "name" = "Icon-App-83.5x83.5@2x.png"; "size" = 167 },
    @{ "name" = "Icon-App-76x76@2x.png";     "size" = 152 },
    @{ "name" = "Icon-App-76x76@1x.png";     "size" = 76 },
    @{ "name" = "Icon-App-60x60@3x.png";     "size" = 180 },
    @{ "name" = "Icon-App-60x60@2x.png";     "size" = 120 },
    @{ "name" = "Icon-App-40x40@3x.png";     "size" = 120 },
    @{ "name" = "Icon-App-40x40@2x.png";     "size" = 80 },
    @{ "name" = "Icon-App-40x40@1x.png";     "size" = 40 },
    @{ "name" = "Icon-App-29x29@3x.png";     "size" = 87 },
    @{ "name" = "Icon-App-29x29@2x.png";     "size" = 58 },
    @{ "name" = "Icon-App-29x29@1x.png";     "size" = 29 },
    @{ "name" = "Icon-App-20x20@3x.png";     "size" = 60 },
    @{ "name" = "Icon-App-20x20@2x.png";     "size" = 40 },
    @{ "name" = "Icon-App-20x20@1x.png";     "size" = 20 }
)

$iosDir = "d:\DoAn_LTTBDDNC\money_tracker_app\ios\Runner\Assets.xcassets\AppIcon.appiconset"
foreach ($item in $iosSizes) {
    $s = $item["size"]
    $iBmp = [LauncherIconExporter]::ResizeImage($masterBmp, $s, $s)
    $iPath = "$iosDir\$($item['name'])"
    $iBmp.Save($iPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $iBmp.Dispose()
    Write-Output "  Exported iOS: $($item['name']) (${s}px)"
}

$masterBmp.Dispose()
$fgBmp.Dispose()
Write-Output "ALL ICONS EXPORTED SUCCESSFULLY!"
