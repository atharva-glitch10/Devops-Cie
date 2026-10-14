# One-shot, repeatable demo preparation. Safe to run as many times as you like, from ANY folder:
#   powershell -ExecutionPolicy Bypass -File "D:\devops cie\StudentManagement\scripts\prepare-demo.ps1"
# Result: image built, Minikube running app + Prometheus + Grafana, port-forwards open,
#         dashboard imported, traffic generated. Ends with a PASS/FAIL table.
# Needs: Docker Desktop running, minikube, kubectl.

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root                      # fixes "path does not exist" when started from the wrong folder
$IMAGE = "studentmgmt:1.0.0"

function Step($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Run($cmd) {
    Write-Host "> $cmd" -ForegroundColor DarkGray
    Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) { throw "FAILED: $cmd" }
}
function Wait-Http($url, $seconds = 60) {
    $end = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $end) {
        try { if ((Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 3).StatusCode -eq 200) { return $true } } catch {}
        Start-Sleep -Seconds 2
    }
    return $false
}

Step "0. Pre-checks"
cmd /c "docker info >nul 2>&1"
if ($LASTEXITCODE -ne 0) { throw "Docker Desktop is not running. Start it, wait for the whale icon to settle, re-run." }
cmd /c "minikube status >nul 2>&1"
if ($LASTEXITCODE -ne 0) { Run "minikube start --driver=docker" }
Run "kubectl config use-context minikube"

Step "1. Docker: build image"
Run "docker build -t $IMAGE ."
cmd /c "docker rm -f demo studentmgmt-smoke >nul 2>&1"; $global:LASTEXITCODE = 0

Step "2. Docker: container smoke test (waits for startup, so no 'Empty reply')"
Run "docker run -d --name demo -p 5001:5000 $IMAGE"
if (-not (Wait-Http "http://localhost:5001/health" 40)) { docker logs demo; throw "container never became healthy" }
Write-Host (curl.exe -s http://localhost:5001/health)
cmd /c "docker rm -f demo >nul 2>&1"; $global:LASTEXITCODE = 0

Step "3. Kubernetes: load image and deploy app"
Run "minikube image load $IMAGE"
Run "kubectl apply -f k8s/"
Run "kubectl rollout restart deployment/student-management"   # pick up the freshly loaded image, clean demo DB
Run "kubectl rollout status deployment/student-management --timeout=120s"

Step "4. Kubernetes: deploy Prometheus + Grafana"
Run "kubectl apply -f monitoring/k8s-monitoring.yaml"
Run "kubectl rollout status deployment/prometheus --timeout=120s"
Run "kubectl rollout status deployment/grafana --timeout=120s"

Step "5. Port-forwards (3 minimized windows; close them or run cleanup to stop)"
Get-CimInstance Win32_Process -Filter "Name='kubectl.exe'" |
    Where-Object { $_.CommandLine -match "port-forward" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
$forwards = @(
    @{ svc = "student-management"; ports = "8080:80" },
    @{ svc = "prometheus";         ports = "9090:9090" },
    @{ svc = "grafana";            ports = "3001:3000" }
)
foreach ($f in $forwards) {
    Start-Process kubectl -ArgumentList "port-forward", "service/$($f.svc)", $f.ports -WindowStyle Minimized
}

$ok = [ordered]@{}
$ok["App        http://localhost:8080"]  = Wait-Http "http://localhost:8080/health"
$ok["Prometheus http://localhost:9090"]  = Wait-Http "http://localhost:9090/-/ready"
$ok["Grafana    http://localhost:3001"]  = Wait-Http "http://localhost:3001/api/health"

Step "6. Grafana: import dashboard via API"
try {
    $dash = Get-Content monitoring\grafana-dashboard.json -Raw | ConvertFrom-Json
    $body = @{ dashboard = $dash; overwrite = $true } | ConvertTo-Json -Depth 50
    $cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:admin"))
    Invoke-RestMethod -Method Post -Uri http://localhost:3001/api/dashboards/db -ContentType "application/json" `
        -Headers @{ Authorization = "Basic $cred" } -Body $body | Out-Null
    $ok["Grafana dashboard imported"] = $true
} catch {
    Write-Host "Dashboard import failed ($($_.Exception.Message)). Import monitoring\grafana-dashboard.json manually." -ForegroundColor Yellow
    $ok["Grafana dashboard imported"] = $false
}

Step "7. Seed data and traffic so panels have values"
$branches = "Information Technology", "Computer Science", "Mechanical", "Civil"
1..8 | ForEach-Object {
    $b = @{ name = "Demo Student $_"; email = "demo$_@example.com"; branch = $branches[$_ % 4]; year = 1 + ($_ % 4) } | ConvertTo-Json
    try { Invoke-RestMethod -Method Post -Uri http://localhost:8080/api/students -ContentType "application/json" -Body $b | Out-Null } catch {}
}
1..40 | ForEach-Object { Invoke-WebRequest http://localhost:8080/ -UseBasicParsing | Out-Null }
try { Invoke-WebRequest http://localhost:8080/nope -UseBasicParsing | Out-Null } catch {}
Start-Sleep -Seconds 10   # let Prometheus scrape (interval is 5s)
try {
    $q = Invoke-RestMethod "http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22student-management%22%7D"
    $ok["Prometheus target student-management UP"] = ($q.data.result[0].value[1] -eq "1")
} catch { $ok["Prometheus target student-management UP"] = $false }

Step "RESULT"
$ok.GetEnumerator() | ForEach-Object {
    $mark = if ($_.Value) { "PASS" } else { "FAIL" }
    $color = if ($_.Value) { "Green" } else { "Red" }
    Write-Host ("[{0}] {1}" -f $mark, $_.Key) -ForegroundColor $color
}
kubectl get deploy,pods,svc
Write-Host "`nGrafana login admin/admin -> Dashboards -> 'Student Management - Application Metrics'" -ForegroundColor Cyan

