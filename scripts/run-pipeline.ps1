# Full pipeline for the Student Management project:
#   Git -> CI/CD (GitHub Actions) -> Docker -> Kubernetes (Minikube) -> Prometheus -> Grafana
#
# Run from the project root in PowerShell:
#   .\scripts\run-pipeline.ps1                 # everything
#   .\scripts\run-pipeline.ps1 -Stage docker   # one stage: git|test|docker|k8s|monitoring|traffic|cleanup
#
# Prerequisites: git, Python 3.12, Docker Desktop (running), kubectl, minikube.
param(
    [ValidateSet("all", "git", "test", "docker", "k8s", "monitoring", "traffic", "cleanup")]
    [string]$Stage = "all",
    [string]$Message = "Update Student Management pipeline"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)   # always run from the project root
$IMAGE = "studentmgmt:1.0.0"   # must match k8s/deployment.yaml

function Step($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Run($cmd) {
    Write-Host "> $cmd" -ForegroundColor DarkGray
    Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) { throw "Command failed ($LASTEXITCODE): $cmd" }
}
function Want($s) { $Stage -eq "all" -or $Stage -eq $s }

# ---------------------------------------------------------------- 1. GIT
if (Want "git") {
    Step "1. GIT - commit and push (push triggers GitHub Actions CI)"
    Run "git status --short"
    Run "git add ."
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) { Run "git commit -m `"$Message`"" } else { Write-Host "Nothing to commit." }
    Run "git push origin main"
    Write-Host "CI result: https://github.com/atharva-glitch10/Devops-Cie/actions"
    Write-Host "Optional image publish: git tag v1.0.0; git push origin v1.0.0  (runs publish-ghcr.yml)"
}

# ---------------------------------------------------------------- 2. TEST (same steps as .github/workflows/ci.yml)
if (Want "test") {
    Step "2. CI equivalent - install dependencies and run pytest locally"
    if (-not (Test-Path .venv)) { Run "python -m venv .venv" }
    Run ".\.venv\Scripts\python.exe -m pip install -r requirements.txt"
    Run ".\.venv\Scripts\python.exe -m pytest -v"
}

# ---------------------------------------------------------------- 3. DOCKER
if (Want "docker") {
    Step "3. DOCKER - build image and smoke-test the container"
    Run "docker build -t $IMAGE ."
    docker rm -f studentmgmt-smoke 2>$null | Out-Null
    Run "docker run -d --name studentmgmt-smoke -p 5000:5000 $IMAGE"
    try {
        Run ".\.venv\Scripts\python.exe scripts\smoke_test.py http://localhost:5000/health"
        Run "curl.exe -s http://localhost:5000/metrics | Select-Object -First 8"
    }
    finally {
        docker rm -f studentmgmt-smoke | Out-Null
    }
    Run "docker images studentmgmt"
}

# ---------------------------------------------------------------- 4. KUBERNETES
if (Want "k8s") {
    Step "4. KUBERNETES - start Minikube, load image, deploy"
    minikube status 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Run "minikube start --driver=docker" }
    Run "minikube image load $IMAGE"
    Run "kubectl apply -f k8s/"
    Run "kubectl rollout status deployment/student-management --timeout=120s"
    Run "kubectl get deployments,pods,services"
    Write-Host "Open app:  kubectl port-forward service/student-management 8080:80   ->  http://localhost:8080"
}

# ---------------------------------------------------------------- 5/6. PROMETHEUS + GRAFANA
if (Want "monitoring") {
    Step "5-6. PROMETHEUS + GRAFANA - deploy monitoring stack"
    Run "kubectl apply -f monitoring/k8s-monitoring.yaml"
    Run "kubectl rollout status deployment/prometheus --timeout=120s"
    Run "kubectl rollout status deployment/grafana --timeout=120s"
    Run "kubectl get pods,services"
    Write-Host @"

Open each in its own terminal:
  kubectl port-forward service/student-management 8080:80   # app        http://localhost:8080
  kubectl port-forward service/prometheus 9090:9090         # Prometheus http://localhost:9090/targets  (student-management = UP)
  kubectl port-forward service/grafana 3001:3000            # Grafana    http://localhost:3001  (admin / admin)
Grafana: Dashboards > New > Import > upload monitoring/grafana-dashboard.json (data source: Prometheus)
Useful PromQL: students_total | sum by (endpoint) (rate(http_requests_total[1m])) |
               histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[1m])))
"@
}

# ---------------------------------------------------------------- 7. TRAFFIC (needs app port-forward on 8080)
if ($Stage -eq "traffic") {
    Step "7. Generate traffic so the dashboard has data (needs port-forward on 8080)"
    $branches = "Information Technology", "Computer Science", "Mechanical", "Civil"
    1..30 | ForEach-Object {
        $body = @{ name = "Student $_"; email = "s$_@example.com"; branch = $branches[$_ % 4]; year = 1 + ($_ % 4) } | ConvertTo-Json
        try { Invoke-RestMethod -Method Post -Uri http://localhost:8080/api/students -ContentType "application/json" -Body $body | Out-Null } catch {}
        Invoke-RestMethod http://localhost:8080/api/students | Out-Null
    }
    try { Invoke-WebRequest http://localhost:8080/nope -UseBasicParsing | Out-Null } catch {}   # a 404 for the status panel
    Run "curl.exe -s http://localhost:8080/metrics | Select-String students_total"
}

# ---------------------------------------------------------------- CLEANUP
if ($Stage -eq "cleanup") {
    Step "CLEANUP"
    kubectl delete -f monitoring/k8s-monitoring.yaml --ignore-not-found
    kubectl delete -f k8s/ --ignore-not-found
    Write-Host "Optionally: minikube stop   (or: minikube delete)"
}
