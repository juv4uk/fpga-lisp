param(
    [string]$Repo = "C:\GitHub\fpga-lisp"
)

$ErrorActionPreference = "Stop"

$source = Join-Path $Repo "scripts\fpga_runner_bridge_server.py"
if (-not (Test-Path $source)) {
    throw "bridge source not found: $source"
}

$pythonw = "$env:LOCALAPPDATA\Programs\Python\Python312\pythonw.exe"
if (-not (Test-Path $pythonw)) {
    $pythonw = (Get-Command pythonw.exe -ErrorAction Stop).Source
}

$targetDir = "$env:LOCALAPPDATA\SENS"
$target = Join-Path $targetDir "fpga_runner_bridge_server.py"
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Copy-Item -Force $source $target

$runCommand = '"{0}" "{1}"' -f $pythonw, $target
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
New-Item -Path $runKey -Force | Out-Null
Set-ItemProperty -Path $runKey -Name "SENSFpgaRunnerBridge" -Value $runCommand

Get-CimInstance Win32_Process |
    Where-Object {
        $_.CommandLine -like "*fpga_runner_bridge_server.py*" -and
        $_.ProcessId -ne $PID
    } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Start-Sleep -Milliseconds 300
Start-Process -FilePath $pythonw -ArgumentList @($target) -WindowStyle Hidden
Start-Sleep -Seconds 1

$probe = python -c "import socket,json; s=socket.create_connection(('127.0.0.1',8765),2); s.sendall((json.dumps({'op':'ping'})+'\n').encode()); print(s.recv(4096).decode().strip())"
Write-Host $probe

if ($probe -notmatch '"ok": true') {
    throw "FPGA bridge failed its local ping"
}

Write-Host "FPGA_RUNNER_BRIDGE_INSTALLED target=$target autostart=HKCU port=8765"
