param([switch]$Tests)
$ErrorActionPreference = 'Stop'
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    $jdk = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory | Sort-Object Name -Descending | Select-Object -First 1
    $env:PATH = "$($jdk.FullName)\bin;$env:PATH"
}
if ($Tests) { & "$sdk\bin\monkeydo.bat" bin/navlog-tests.prg fr965 /t }
else { & "$sdk\bin\monkeydo.bat" bin/navlog.prg fr965 }
