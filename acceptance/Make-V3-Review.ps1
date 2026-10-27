# Crop/downscale actual simulator screenshots and export measurements; no generated UI.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$root=Split-Path $PSScriptRoot -Parent
$folder=Join-Path $root 'evidence/v3'
function Read-Metrics($name,$stage){
 foreach($line in (Get-Content (Join-Path $folder $name))){
  if($line.StartsWith('METRIC|')){$p=$line -split '\|'; [pscustomobject]@{Stage=$stage;Scene=$p[1];Text=$p[2];X=[double]$p[3];Y=[double]$p[4];Width=[double]$p[5];Height=[double]$p[6];FontSize=[int]$p[7]}}
 }
}
$before=@(Read-Metrics 'before-metrics.txt' 'V2'); $after=@(Read-Metrics 'after-metrics.txt' 'V3')
@($before+$after) | Export-Csv (Join-Path $folder 'text-bounds.csv') -NoTypeInformation
foreach($stage in @('V2','V3')){
 $rows=if($stage -eq 'V2'){$before}else{$after}
 $running=@($rows | Where-Object Scene -eq 'running')
 $area=($running | ForEach-Object {$_.Width*$_.Height} | Measure-Object -Sum).Sum
 "${stage}: running text boxes=$($running.Count); box area=$area px2; circle occupancy=$([math]::Round(100*$area/([math]::PI*227*227),2))%"
}
foreach($pair in @(@('before-running.png','v2'),@('03-running.png','v3'),@('before-menu.png','v2-menu'),@('07-actions.png','v3-menu'))){
 $capture=[Drawing.Bitmap]::FromFile((Join-Path $folder $pair[0]))
 try {
  if($capture.Width -ne 698 -or $capture.Height -ne 995){throw 'Inspect display origin: capture geometry changed.'}
  # Observed native display origin in the unscaled FR965 skin, not guessed from another app.
  $dial=$capture.Clone((New-Object Drawing.Rectangle(122,285,454,454)),[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
   $dial.Save((Join-Path $folder ($pair[1]+'-display.png')),[Drawing.Imaging.ImageFormat]::Png)
   $thumb=New-Object Drawing.Bitmap 134,134; $thumb.SetResolution(96,96)
   $g=[Drawing.Graphics]::FromImage($thumb); $path=New-Object Drawing.Drawing2D.GraphicsPath
   try {
    $g.Clear([Drawing.Color]::Transparent); $path.AddEllipse(0,0,134,134); $g.SetClip($path)
    $g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($dial,0,0,134,134)
    $thumb.Save((Join-Path $folder ($pair[1]+'-134px.png')),[Drawing.Imaging.ImageFormat]::Png)
   } finally {$path.Dispose();$g.Dispose();$thumb.Dispose()}
  } finally {$dial.Dispose()}
 } finally {$capture.Dispose()}
}
