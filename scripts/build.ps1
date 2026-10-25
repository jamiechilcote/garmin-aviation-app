param([switch]$Tests, [switch]$Release)
$ErrorActionPreference = 'Stop'
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
$java = Get-Command java -ErrorAction SilentlyContinue
if (-not $java) {
    $jdk = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory | Sort-Object Name -Descending | Select-Object -First 1
    $env:PATH = "$($jdk.FullName)\bin;$env:PATH"
}
New-Item -ItemType Directory -Force bin,.private | Out-Null
$key = Join-Path $PSScriptRoot '..\.private\developer_key.der'
if (-not (Test-Path $key)) {
    $rsa = [System.Security.Cryptography.RSA]::Create(4096)
    [System.IO.File]::WriteAllBytes($key, $rsa.ExportPkcs8PrivateKey())
    $rsa.Dispose()
}
$output = if ($Tests) { 'bin/navlog-tests.prg' } elseif ($Release) { 'bin/navlog-device.prg' } else { 'bin/navlog.prg' }
$arguments = @('-f','monkey.jungle','-d','fr965','-o',$output,'-y',$key,'-w')
if ($Tests) { $arguments += '-t' }
if ($Release) { $arguments += '-r' }
& "$sdk\bin\monkeyc.bat" @arguments
if ($LASTEXITCODE -ne 0) { throw "Compiler failed ($LASTEXITCODE)" }
