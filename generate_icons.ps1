Add-Type -AssemblyName System.Drawing

function Create-RoundedPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-CapsulePath([System.Drawing.Graphics]$g, [float]$x1, [float]$y1, [float]$x2, [float]$y2, [float]$thickness, [System.Drawing.Brush]$brush) {
    $dx = $x2 - $x1
    $dy = $y2 - $y1
    $dist = [math]::Sqrt($dx * $dx + $dy * $dy)
    if ($dist -lt 1.0) { return }
    $angle = [math]::Atan2($dy, $dx) * 180.0 / [math]::PI

    $state = $g.Save()
    $g.TranslateTransform($x1, $y1)
    $g.RotateTransform($angle)

    $r = $thickness / 2.0
    $rect = New-Object System.Drawing.RectangleF (-$r), (-$r), ($dist + $thickness), $thickness
    $path = Create-RoundedPath $rect.X $rect.Y $rect.Width $rect.Height $r
    $g.FillPath($brush, $path)
    $path.Dispose()

    $g.Restore($state)
}

function Draw-3DTactileMonoM([System.Drawing.Graphics]$g, [float]$cx, [float]$cy, [float]$scale) {
    $mW = 540.0 * $scale
    $mH = 440.0 * $scale
    $pillW = 108.0 * $scale
    $halfPill = $pillW / 2.0

    $topY = $cy - ($mH / 2.0)
    $bottomY = $cy + ($mH / 2.0)
    $xLeft = $cx - ($mW / 2.0) + $halfPill
    $xRight = $cx + ($mW / 2.0) - $halfPill
    $xCenter = $cx
    $yDip = $topY + ($mH * 0.68)

    $pTopLeft = New-Object System.Drawing.PointF $xLeft, ($topY + $halfPill * 0.4)
    $pTopRight = New-Object System.Drawing.PointF $xRight, ($topY + $halfPill * 0.4)
    $pCenterDip = New-Object System.Drawing.PointF $xCenter, $yDip

    # 1. Soft Drop Shadow under M onto Teal Background
    $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(95, 19, 54, 51))
    $sOffY = 24.0 * $scale
    
    # Left & Right Legs Shadow
    $leftLegShadow = Create-RoundedPath ($xLeft - $halfPill) ($topY + $sOffY) $pillW $mH $halfPill
    $rightLegShadow = Create-RoundedPath ($xRight - $halfPill) ($topY + $sOffY) $pillW $mH $halfPill
    $g.FillPath($shadowBrush, $leftLegShadow)
    $g.FillPath($shadowBrush, $rightLegShadow)
    $leftLegShadow.Dispose()
    $rightLegShadow.Dispose()

    Draw-CapsulePath $g $pTopLeft.X ($pTopLeft.Y + $sOffY) $pCenterDip.X ($pCenterDip.Y + $sOffY) $pillW $shadowBrush
    Draw-CapsulePath $g $pCenterDip.X ($pCenterDip.Y + $sOffY) $pTopRight.X ($pTopRight.Y + $sOffY) $pillW $shadowBrush
    $shadowBrush.Dispose()

    # 2. Left & Right Pillars (Vertical Legs)
    $legRect = New-Object System.Drawing.RectangleF ($xLeft - $halfPill), $topY, ($xRight - $xLeft + $pillW), $mH
    $legBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $legRect,
        [System.Drawing.Color]::FromArgb(255, 255, 255, 255),
        [System.Drawing.Color]::FromArgb(255, 226, 237, 233),
        55.0
    )
    $leftLegPath = Create-RoundedPath ($xLeft - $halfPill) $topY $pillW $mH $halfPill
    $rightLegPath = Create-RoundedPath ($xRight - $halfPill) $topY $pillW $mH $halfPill
    $g.FillPath($legBrush, $leftLegPath)
    $g.FillPath($legBrush, $rightLegPath)
    $leftLegPath.Dispose()
    $rightLegPath.Dispose()
    $legBrush.Dispose()

    # 3. Contact Shadows between diagonals and legs
    $contactBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55, 19, 54, 51))
    Draw-CapsulePath $g $pTopLeft.X $pTopLeft.Y $pCenterDip.X $pCenterDip.Y $pillW $contactBrush
    Draw-CapsulePath $g $pCenterDip.X $pCenterDip.Y $pTopRight.X $pTopRight.Y $pillW $contactBrush
    $contactBrush.Dispose()

    # 4. Right Diagonal Stroke
    $diag2Brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.RectangleF $pCenterDip.X, $pTopRight.Y, ($pTopRight.X - $pCenterDip.X), ($pCenterDip.Y - $pTopRight.Y)),
        [System.Drawing.Color]::FromArgb(255, 255, 255, 255),
        [System.Drawing.Color]::FromArgb(255, 224, 236, 231),
        45.0
    )
    Draw-CapsulePath $g $pCenterDip.X $pCenterDip.Y $pTopRight.X $pTopRight.Y $pillW $diag2Brush
    $diag2Brush.Dispose()

    # 5. Fold Shadow at center vertex
    $foldBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45, 19, 54, 51))
    Draw-CapsulePath $g $pTopLeft.X $pTopLeft.Y $pCenterDip.X $pCenterDip.Y $pillW $foldBrush
    $foldBrush.Dispose()

    # 6. Left Diagonal Stroke (Top layer overlay)
    $diag1Brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.RectangleF $pTopLeft.X, $pTopLeft.Y, ($pCenterDip.X - $pTopLeft.X), ($pCenterDip.Y - $pTopLeft.Y)),
        [System.Drawing.Color]::FromArgb(255, 255, 255, 255),
        [System.Drawing.Color]::FromArgb(255, 228, 238, 234),
        135.0
    )
    Draw-CapsulePath $g $pTopLeft.X $pTopLeft.Y $pCenterDip.X $pCenterDip.Y $pillW $diag1Brush
    $diag1Brush.Dispose()

    # 7. Specular Spine Highlights
    $spinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(190, 255, 255, 255), (14.0 * $scale))
    $spinePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $spinePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    $g.DrawLine($spinePen, ($xLeft - $pillW * 0.15), ($topY + $halfPill * 1.2), ($xLeft - $pillW * 0.15), ($bottomY - $halfPill * 1.2))
    $g.DrawLine($spinePen, ($xRight - $pillW * 0.15), ($topY + $halfPill * 1.2), ($xRight - $pillW * 0.15), ($bottomY - $halfPill * 1.2))
    $g.DrawLine($spinePen, ($pTopLeft.X + $halfPill * 0.2), ($pTopLeft.Y + $halfPill * 0.4), ($pCenterDip.X - $halfPill * 0.2), ($pCenterDip.Y - $halfPill * 0.4))
    $spinePen.Dispose()
}

# ═════════════════════════════════════════════════════════════════════
# 1. GENERATE MASTER ICON 1024 x 1024
# ═════════════════════════════════════════════════════════════════════
$masterBmp = New-Object System.Drawing.Bitmap 1024, 1024, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($masterBmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# Background: Ambient deep dark slate / teal floor
$bgRect = New-Object System.Drawing.Rectangle 0, 0, 1024, 1024
$bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $bgRect,
    [System.Drawing.Color]::FromArgb(255, 11, 24, 23),
    [System.Drawing.Color]::FromArgb(255, 5, 13, 12),
    45.0
)
$g.FillRectangle($bgBrush, $bgRect)
$bgBrush.Dispose()

# Ambient Teal Glow Aura behind squircle
$glowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40, 67, 136, 131))
for ($i = 60; $i -ge 10; $i -= 10) {
    $g.FillEllipse($glowBrush, (512 - 400 - $i), (512 - 400 - $i), ((400 + $i)*2), ((400 + $i)*2))
}
$glowBrush.Dispose()

# 3D Tactile Squircle Badge: 760 x 760 at (132, 132)
$badgeX = 132.0
$badgeY = 132.0
$badgeW = 760.0
$badgeH = 760.0
$badgeR = 210.0
$badgePath = Create-RoundedPath $badgeX $badgeY $badgeW $badgeH $badgeR

# Drop Shadow under Badge
$badgeShadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(110, 0, 0, 0))
$badgeShadowPath = Create-RoundedPath ($badgeX + 6) ($badgeY + 32) $badgeW $badgeH $badgeR
$g.FillPath($badgeShadowBrush, $badgeShadowPath)
$badgeShadowBrush.Dispose()
$badgeShadowPath.Dispose()

# Fill 3D Soft Tactile Radial Gradient Body in MONO Signature Teal (#438883)
$badgeBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($badgePath)
$badgeBrush.CenterPoint = New-Object System.Drawing.PointF (512.0 - 100.0), (512.0 - 110.0)
$badgeBrush.CenterColor = [System.Drawing.Color]::FromArgb(255, 118, 196, 190) # #76C4BE soft bright center
$badgeBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(255, 34, 81, 77)) # #22514D rich tactile edge
$g.FillPath($badgeBrush, $badgePath)
$badgeBrush.Dispose()

# Soft Top Specular Lens Highlight
$lensPath = Create-RoundedPath ($badgeX + 6) ($badgeY + 6) ($badgeW - 12) ($badgeH * 0.46) ($badgeR * 0.95)
$lensBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.RectangleF $badgeX, $badgeY, $badgeW, ($badgeH * 0.46)),
    [System.Drawing.Color]::FromArgb(90, 255, 255, 255),
    [System.Drawing.Color]::FromArgb(0, 255, 255, 255),
    90.0
)
$g.FillPath($lensBrush, $lensPath)
$lensBrush.Dispose()
$lensPath.Dispose()

# Diagonal Sheen Streak
$sheenPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$sheenPath.AddPolygon(@(
    [System.Drawing.PointF]::new(340, 130),
    [System.Drawing.PointF]::new(480, 130),
    [System.Drawing.PointF]::new(260, 890),
    [System.Drawing.PointF]::new(120, 890)
))
$g.SetClip($badgePath)
$sheenBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle 120, 130, 360, 760),
    [System.Drawing.Color]::FromArgb(0, 255, 255, 255),
    [System.Drawing.Color]::FromArgb(75, 255, 255, 255),
    0.0
)
$g.FillPath($sheenBrush, $sheenPath)
$g.ResetClip()
$sheenBrush.Dispose()
$sheenPath.Dispose()

# Draw 3D Tactile Letter "M" of MONO
Draw-3DTactileMonoM $g 512.0 512.0 1.0

# Seamless Outer Highlight Border
$borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150, 255, 255, 255), 10.0)
$g.DrawPath($borderPen, $badgePath)
$borderPen.Dispose()
$badgePath.Dispose()
$g.Dispose()

# Save Master 1024x1024
$masterIconPath = "d:\DoAn_LTTBDDNC\money_tracker_app\assets\images\app_icon_liquid_glass.png"
$masterBmp.Save($masterIconPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output "Master Icon saved to $masterIconPath"

# ═════════════════════════════════════════════════════════════════════
# 2. GENERATE ADAPTIVE FOREGROUND (Transparent BG, Safe Zone)
# ═════════════════════════════════════════════════════════════════════
$fgBmp = New-Object System.Drawing.Bitmap 1024, 1024, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$fgG = [System.Drawing.Graphics]::FromImage($fgBmp)
$fgG.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$fgG.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$fgG.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$fgScale = 0.76
$fgDestW = 1024 * $fgScale
$fgDestH = 1024 * $fgScale
$fgDestX = (1024 - $fgDestW) / 2
$fgDestY = (1024 - $fgDestH) / 2

$fgG.DrawImage($masterBmp, (New-Object System.Drawing.RectangleF $fgDestX, $fgDestY, $fgDestW, $fgDestH))
$fgG.Dispose()

$fgIconPath = "d:\DoAn_LTTBDDNC\money_tracker_app\assets\images\app_icon_liquid_glass_foreground.png"
$fgBmp.Save($fgIconPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output "Adaptive Foreground saved to $fgIconPath"

# ═════════════════════════════════════════════════════════════════════
# 3. EXPORT TO ANDROID MIPMAPS
# ═════════════════════════════════════════════════════════════════════
$androidMipmaps = @{
    "mipmap-mdpi" = @{ "launcher" = 48; "fg" = 108 }
    "mipmap-hdpi" = @{ "launcher" = 72; "fg" = 162 }
    "mipmap-xhdpi" = @{ "launcher" = 96; "fg" = 216 }
    "mipmap-xxhdpi" = @{ "launcher" = 144; "fg" = 324 }
    "mipmap-xxxhdpi" = @{ "launcher" = 192; "fg" = 432 }
}

foreach ($folder in $androidMipmaps.Keys) {
    $dir = "d:\DoAn_LTTBDDNC\money_tracker_app\android\app\src\main\res\$folder"
    if (Test-Path $dir) {
        $lSize = $androidMipmaps[$folder]["launcher"]
        $fgSize = $androidMipmaps[$folder]["fg"]

        # Launcher icon
        $lBmp = New-Object System.Drawing.Bitmap $lSize, $lSize
        $lg = [System.Drawing.Graphics]::FromImage($lBmp)
        $lg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $lg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $lg.DrawImage($masterBmp, 0, 0, $lSize, $lSize)
        $lg.Dispose()
        $lBmp.Save("$dir\ic_launcher.png", [System.Drawing.Imaging.ImageFormat]::Png)
        $lBmp.Dispose()

        # Foreground icon
        $fBmp = New-Object System.Drawing.Bitmap $fgSize, $fgSize
        $flg = [System.Drawing.Graphics]::FromImage($fBmp)
        $flg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $flg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $flg.DrawImage($fgBmp, 0, 0, $fgSize, $fgSize)
        $flg.Dispose()
        $fBmp.Save("$dir\ic_launcher_foreground.png", [System.Drawing.Imaging.ImageFormat]::Png)
        $fBmp.Dispose()

        Write-Output "Updated Android $folder"
    }
}

# ═════════════════════════════════════════════════════════════════════
# 4. EXPORT TO IOS APPICON.APPICONSET
# ═════════════════════════════════════════════════════════════════════
$iosSizes = @(
    @{ Name = "Icon-App-1024x1024@1x.png"; Size = 1024 },
    @{ Name = "Icon-App-20x20@1x.png"; Size = 20 },
    @{ Name = "Icon-App-20x20@2x.png"; Size = 40 },
    @{ Name = "Icon-App-20x20@3x.png"; Size = 60 },
    @{ Name = "Icon-App-29x29@1x.png"; Size = 29 },
    @{ Name = "Icon-App-29x29@2x.png"; Size = 58 },
    @{ Name = "Icon-App-29x29@3x.png"; Size = 87 },
    @{ Name = "Icon-App-40x40@1x.png"; Size = 40 },
    @{ Name = "Icon-App-40x40@2x.png"; Size = 80 },
    @{ Name = "Icon-App-40x40@3x.png"; Size = 120 },
    @{ Name = "Icon-App-60x60@2x.png"; Size = 120 },
    @{ Name = "Icon-App-60x60@3x.png"; Size = 180 },
    @{ Name = "Icon-App-76x76@1x.png"; Size = 76 },
    @{ Name = "Icon-App-76x76@2x.png"; Size = 152 },
    @{ Name = "Icon-App-83.5x83.5@2x.png"; Size = 167 }
)

$iosDir = "d:\DoAn_LTTBDDNC\money_tracker_app\ios\Runner\Assets.xcassets\AppIcon.appiconset"
if (Test-Path $iosDir) {
    foreach ($item in $iosSizes) {
        $s = [int]$item["Size"]
        $targetPath = "$iosDir\" + $item["Name"]
        $iBmp = New-Object System.Drawing.Bitmap $s, $s
        $ig = [System.Drawing.Graphics]::FromImage($iBmp)
        $ig.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $ig.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $ig.DrawImage($masterBmp, 0, 0, $s, $s)
        $ig.Dispose()
        $iBmp.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $iBmp.Dispose()
    }
    Write-Output "Updated iOS AppIcon.appiconset"
}

$masterBmp.Dispose()
$fgBmp.Dispose()
Write-Output "All 3D Tactile MONO App Icons successfully regenerated!"
