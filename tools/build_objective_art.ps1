# Export existing source artwork at design-pixel sizes. No game/cache access.
Add-Type -AssemblyName System.Drawing
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$out = Join-Path $PSScriptRoot '../art/objectives'
[System.IO.Directory]::CreateDirectory($out) | Out-Null
foreach ($name in @('questu','questd','skillu','skilld')) {
    $source = Join-Path $repo ('local-changes/button-images/' + $name + '.res/image/image_0.png')
    $image = [System.Drawing.Image]::FromFile($source)
    $scaled = New-Object System.Drawing.Bitmap 81,34
    $g = [System.Drawing.Graphics]::FromImage($scaled)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($image,0,0,81,34)
    $scaled.Save((Join-Path $out ($name+'.png')),[System.Drawing.Imaging.ImageFormat]::Png)
    if ($name.StartsWith('quest')) {
        $frame = New-Object System.Drawing.Bitmap 34,34
        $fg = [System.Drawing.Graphics]::FromImage($frame)
        $fg.Clear([System.Drawing.Color]::FromArgb(210,30,34,20))
        foreach ($xx in @(0,1,2)) {
            foreach ($yy in @(0,1,2)) {
                if ($xx -eq 1 -and $yy -eq 1) { continue }
                $sx = @(0,4,77)[$xx]; $sw = @(4,73,4)[$xx]
                $sy = @(0,4,30)[$yy]; $sh = @(4,26,4)[$yy]
                $dx = @(0,4,30)[$xx]; $dw = @(4,26,4)[$xx]
                $dy = @(0,4,30)[$yy]; $dh = @(4,26,4)[$yy]
                $fg.DrawImage($scaled,(New-Object System.Drawing.Rectangle $dx,$dy,$dw,$dh),$sx,$sy,$sw,$sh,[System.Drawing.GraphicsUnit]::Pixel)
            }
        }
        $frame.Save((Join-Path $out ($name.Replace('quest','current')+'.png')),[System.Drawing.Imaging.ImageFormat]::Png)
        $fg.Dispose(); $frame.Dispose()
    }
    $g.Dispose(); $scaled.Dispose(); $image.Dispose()
}
Write-Output 'Exported four original tab faces and two current-credo frames.'
foreach ($name in @('rbtn-questobj','rbtn-questobj-d','rbtn-questobj-h','rbtn-questobj-dh')) {
    $source = Join-Path $repo ('resources/src/local/gfx/hud/'+$name+'.res/image/image_0.png')
    $image = [System.Drawing.Image]::FromFile($source)
    $scaled = New-Object System.Drawing.Bitmap 40,40
    $g = [System.Drawing.Graphics]::FromImage($scaled)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($image,0,0,40,40)
    $scaled.Save((Join-Path $out ($name+'.png')),[System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose();$scaled.Dispose();$image.Dispose()
}
Write-Output 'Exported four original circular objectives-button faces.'
$frames = Join-Path $repo 'build/quest-ui-frame-source'
if (Test-Path -LiteralPath $frames) {
    foreach ($file in (Get-ChildItem -LiteralPath $frames -Filter '*.png' -File)) {
        $image = [System.Drawing.Image]::FromFile($file.FullName)
        $scaled = New-Object System.Drawing.Bitmap ([int]($image.Width/4)),([int]($image.Height/4))
        $g = [System.Drawing.Graphics]::FromImage($scaled)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($image,0,0,$scaled.Width,$scaled.Height)
        $scaled.Save((Join-Path $out ('frame-'+$file.Name)),[System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose();$scaled.Dispose();$image.Dispose()
    }
    Write-Output 'Exported eight native frame pieces.'
}
