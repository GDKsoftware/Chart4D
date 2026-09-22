# Renders the palette bitmaps for the design-time package from assets\chart4d-mark-256.png.
# Magenta is the classic .dcr transparency key, so the glyph sits on a magenta background.
# Run from anywhere; output goes next to this script, in 24\ and 32\.

Add-Type -AssemblyName System.Drawing

$scriptDir = $PSScriptRoot
$sourcePath = Join-Path (Split-Path (Split-Path $scriptDir -Parent) -Parent) 'assets\chart4d-mark-256.png'

if (-not (Test-Path $sourcePath)) {
    throw "Source mark not found at $sourcePath"
}

function New-PaletteBitmap([int]$size, [string]$outputPath) {
    $source = [System.Drawing.Image]::FromFile($sourcePath)
    try {
        $bitmap = New-Object System.Drawing.Bitmap($size, $size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::FromArgb(255, 255, 0, 255))
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

            # A one pixel inset keeps the antialiased edge off the bitmap border.
            $inset = 1
            $graphics.DrawImage($source, $inset, $inset, $size - (2 * $inset), $size - (2 * $inset))
        } finally {
            $graphics.Dispose()
        }

        $directory = Split-Path $outputPath -Parent
        if (-not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory | Out-Null
        }

        # brcc32 rejects a 32-bit BMP, which is what System.Drawing writes by default.
        $bounds = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
        $bitmap24 = $bitmap.Clone($bounds, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $bitmap24.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
        $bitmap24.Dispose()
        $bitmap.Dispose()
        Write-Host "wrote $outputPath"
    } finally {
        $source.Dispose()
    }
}

New-PaletteBitmap 24 (Join-Path $scriptDir '24\TCHART4D.bmp')
New-PaletteBitmap 32 (Join-Path $scriptDir '32\TCHART4D.bmp')
