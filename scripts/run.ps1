param([switch]$Tests)
$ErrorActionPreference = 'Stop'
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    $jdk = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory | Sort-Object Name -Descending | Select-Object -First 1
    $env:PATH = "$($jdk.FullName)\bin;$env:PATH"
}
if ($Tests) {
    $result = & "$sdk\bin\monkeydo.bat" bin/navlog-tests.prg fr965 /t 2>&1
    $result | Tee-Object -FilePath bin/test-results.log
    if (($result -join "`n") -notmatch 'PASSED \(passed=\d+, failed=0, errors=0\)') { throw 'Simulator test suite failed or did not finish.' }
}
else { & "$sdk\bin\monkeydo.bat" bin/navlog.prg fr965 }
