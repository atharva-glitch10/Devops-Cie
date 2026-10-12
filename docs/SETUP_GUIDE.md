# Setup and Tool Integration Guide (Windows 10/11, PowerShell)

Commands are for **PowerShell**. Where Linux/macOS differs it is noted. In Windows PowerShell 5.1, `curl` is an alias for `Invoke-WebRequest`, so use `curl.exe`.

---

## Part 1 - Prerequisites

| Software | Install | Verify |
|---|---|---|
| Python 3.12 | https://www.python.org/downloads/ (tick "Add to PATH") | `python --version` |
| Git | https://git-scm.com/download/win | `git --version` |
| VS Code | https://code.visualstudio.com | open it |
| Docker Desktop | https://www.docker.com/products/docker-desktop (needs WSL 2 backend) | `docker --version` and `docker run hello-world` |
| kubectl | `winget install Kubernetes.kubectl` (also bundled with Docker Desktop) | `kubectl version --client` |
| Minikube | `winget install Kubernetes.minikube` (reopen PowerShell) | `minikube version` |
| GitHub account | https://github.com | - |

**Prerequisites that commonly break things**

- Virtualisation must be enabled in BIOS/UEFI. Check: Task Manager → Performance → CPU → "Virtualization: Enabled".
- WSL 2: `wsl --install` in an admin PowerShell, then reboot.
- Docker Desktop must be **running** (whale icon steady) before any `docker` command. Error `failed to connect to the docker API ... dockerDesktopLinuxEngine` means it is not running.
- Use Minikube's `docker` driver. You do **not** need Docker Desktop's built-in Kubernetes enabled.

---

## Part 2 - Run the app locally

```powershell
cd D:\path\to\StudentManagement
python -m venv .venv
.\.venv\Scripts\Activate.ps1        # Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
python -m pytest -v                 # expect all tests to pass
python app.py                       # open http://127.0.0.1:5000
```

If activation is blocked: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

Test the API (second terminal):

```powershell
curl.exe http://127.0.0.1:5000/health
curl.exe http://127.0.0.1:5000/api/students
curl.exe -X POST http://127.0.0.1:5000/api/students -H "Content-Type: application/json" -d "{\"name\":\"Asha Patil\",\"email\":\"asha@example.com\",\"branch\":\"Information Technology\",\"year\":3}"
curl.exe http://127.0.0.1:5000/metrics
```

Validation check (expect HTTP 400): same POST with `\"year\":9`.

Common problems: `ModuleNotFoundError` → venv not activated; `Address already in use` → set `$env:PORT="5001"` before `python app.py`.

---

## Part 3 - Git and GitHub

| # | Do | Command | Why / expected |
|---|---|---|---|
| 1 | Identity | `git config --global user.name "Your Name"`<br>`git config --global user.email "you@example.com"` | Labels your commits. Verify: `git config --global --list` |
| 2 | Init | `git init -b main` | Creates the repo with a `main` branch |
| 3 | Check ignores | `git status` | `.venv`, `*.db` must **not** be listed. `.gitignore` already covers them |
| 4 | Commit | `git add .`<br>`git commit -m "Initial commit: Student Management System"` | Snapshot. Verify: `git log --oneline` |
| 5 | Create remote repo | github.com → New repository → name `StudentManagement` → **do not** add README/.gitignore | An empty repo avoids merge conflicts |
| 6 | Connect | `git remote add origin https://github.com/<your-username>/StudentManagement.git` | Verify: `git remote -v` |
| 7 | Push | `git push -u origin main` | Browser/credential-manager login opens. Use the login flow; never paste tokens into files |
| 8 | Feature branch | `git switch -c feature/ui-tweak` | Isolated work |
| 9 | Change + commit | edit `templates/index.html`, then `git add -A`, `git commit -m "Tweak UI text"` | |
| 10 | Push branch | `git push -u origin feature/ui-tweak` | GitHub offers "Compare & pull request" |
| 11 | PR + merge | Open PR into `main` (CI runs on the PR), merge it, then `git switch main; git pull` | |

If push is rejected: `git pull --rebase origin main`, then push again. If authentication fails: sign in again via Git Credential Manager (`git credential-manager github login`).

---

## Part 4 - GitHub Actions (CI)

The workflow is already at `.github/workflows/ci.yml`. It runs on push and pull request to `main`: checkout → Python 3.12 → `pip install` → `pytest` → `docker build` → run container and `curl /health`.

**Verify:** GitHub repo → **Actions** tab → latest "CI" run → both jobs (`Test (pytest)`, `Build Docker image`) show a green tick. Click a job to see each step's log.

**If it fails**

1. Open the failed run → click the red step → read the last lines of the log.
2. `pytest` failure: run `python -m pytest -v` locally and fix.
3. `pip install` failure: check `requirements.txt` spelling/versions.
4. Workflow not appearing: the file must be exactly `.github/workflows/ci.yml` and pushed to the default branch.
5. Nothing triggers: you pushed to a branch other than `main` without opening a PR; or Actions is disabled (Settings → Actions → General).

**CI vs CD**

- *Continuous Integration*: every change is automatically built and tested.
- *Continuous Delivery*: every passing build produces a deployable artifact, release is a manual decision.
- *Continuous Deployment*: every passing build is deployed automatically with no human step.

This project does CI. Deployment to Minikube is manual. Optional: `publish-ghcr.yml` pushes the image to GHCR when you push a tag (`git tag v1.0.0; git push origin v1.0.0`). To run it in Kubernetes, make the package public (or create an `imagePullSecret`), then change the image in `k8s/deployment.yaml` to `ghcr.io/<owner-lowercase>/<repo-lowercase>:v1.0.0`. It needs no stored secrets because it uses the built-in `GITHUB_TOKEN`.

---

## Part 5 - Docker

| # | Command | What / expected | If it fails |
|---|---|---|---|
| 1 | `docker build -t studentmgmt:1.0.0 .` | Builds the image from the Dockerfile; ends with "naming to ...studentmgmt:1.0.0" | Docker Desktop not running; run from the folder containing the Dockerfile |
| 2 | `docker images studentmgmt` | Lists the image | - |
| 3 | `docker run -d --name studentmgmt -p 5000:5000 studentmgmt:1.0.0` | Starts a container, maps host 5000 → container 5000 | "port is already allocated": use `-p 5001:5000` |
| 4 | open http://localhost:5000 | App page | `docker logs studentmgmt` |
| 5 | `curl.exe http://localhost:5000/health` | `{"database":"reachable","status":"ok"}` | Check `-p` flag; app must bind `0.0.0.0` (the image does) |
| 6 | `docker logs studentmgmt` | gunicorn startup + errors | - |
| 7 | `docker ps` | Status column shows `healthy` after ~30 s | - |
| 8 | `docker stop studentmgmt; docker rm studentmgmt` | Cleans up | - |
| 9 | After a code change: repeat step 1 (use a new tag, e.g. `1.0.1`), then stop/rm/run | New image from new code | - |

**Image vs container:** an image is a read-only template (like a class); a container is a running instance of it (like an object).

Data note: the DB is at `/data/students.db` inside the container and disappears with `docker rm` unless you mount a volume (`-v studentmgmt-data:/data`).

---

## Part 6 - Kubernetes with Minikube

```powershell
minikube start --driver=docker       # first start downloads images; takes minutes
kubectl get nodes                    # expect STATUS Ready
```

**Why `minikube image load`?** Minikube runs its own container runtime inside its node. It cannot see images in your Docker Desktop. The manifest uses `imagePullPolicy: IfNotPresent` so Kubernetes uses the loaded image instead of trying to download `studentmgmt` from Docker Hub.

```powershell
docker build -t studentmgmt:1.0.0 .
minikube image load studentmgmt:1.0.0
minikube image ls | Select-String studentmgmt      # confirms it is inside Minikube

kubectl apply -f k8s/
kubectl get deployments,pods,services
kubectl rollout status deployment/student-management
```

Expect Pod `1/1 Running`. Details: `kubectl describe pod -l app=student-management`, `kubectl logs deployment/student-management`, `kubectl get events --sort-by=.lastTimestamp`.

**Access** (keep this terminal open):

```powershell
kubectl port-forward service/student-management 8080:80
# http://localhost:8080  and  curl.exe http://localhost:8080/health
```

Alternative: `minikube service student-management --url` (also must stay open with the docker driver).

**Scale** (works, but see data caveat):

```powershell
kubectl scale deployment/student-management --replicas=2
kubectl get pods
kubectl scale deployment/student-management --replicas=1
```

With SQLite each Pod has its **own** database, so two replicas show different student lists. Scale only to demonstrate the mechanism, then return to 1.

**Rolling update**

```powershell
# make a visible change (e.g. edit the navbar text in templates/index.html)
docker build -t studentmgmt:1.0.1 .
minikube image load studentmgmt:1.0.1
kubectl set image deployment/student-management app=studentmgmt:1.0.1
kubectl rollout status deployment/student-management
kubectl rollout history deployment/student-management
```

Restart the port-forward afterwards (it is bound to the old Pod). Data stored in the old Pod is gone (emptyDir).

**Rollback**

```powershell
kubectl rollout undo deployment/student-management
kubectl rollout status deployment/student-management
```

Always use a **new tag** for each build; `minikube image load` with an existing tag may keep the old image.

**Clean up**

```powershell
kubectl delete -f monitoring/k8s-monitoring.yaml
kubectl delete -f k8s/
minikube stop            # or: minikube delete
```

**Object cheat-sheet:** *container* = one running process in an image; *Pod* = smallest deployable unit, wraps one or more containers; *Deployment* = keeps N Pods running and handles updates/rollbacks; *Service* = stable name/IP that load-balances to matching Pods.

---

## Part 7 - Prometheus

Application metrics (requests, latency, students) come from the **app**. Operating-system/node metrics (CPU, disk of the machine) would need a separate exporter like node-exporter, which is not part of this project. The `process_*` and `python_*` metrics the library adds are about the app's own process.

### Option A: inside Minikube (matches the Kubernetes demo)

```powershell
kubectl apply -f monitoring/k8s-monitoring.yaml
kubectl get pods                                   # prometheus and grafana Running
kubectl port-forward service/prometheus 9090:9090  # new terminal, keep open
```

How it reaches the app: the ConfigMap `prometheus-config` has the static target `student-management.default.svc.cluster.local:80`, the cluster-internal DNS name of the app's Service. Static config was chosen over Kubernetes service discovery because it needs no RBAC and is easy to explain; the limitation is that targets are not discovered automatically.

### Option B: plain Docker

```powershell
docker compose up -d --build
```

Prometheus uses `monitoring/prometheus.yml` with target `app:5000` (Compose service name; `localhost` would point to the Prometheus container itself).

### Verify (both options, Prometheus at http://localhost:9090)

1. Status → Targets: job `student-management` is **UP**. CLI: `(Invoke-RestMethod http://localhost:9090/api/v1/targets).data.activeTargets | Select-Object scrapeUrl, health`.
2. Graph tab: run `http_requests_total`.
3. Generate traffic, run the query again, and the numbers should have increased:

```powershell
1..30 | ForEach-Object { Invoke-WebRequest http://localhost:8080/ -UseBasicParsing | Out-Null }
```

(Use port 5000 for Option B.) If the target is DOWN: see troubleshooting table in [DEMO_SCRIPT.md](DEMO_SCRIPT.md).

---

## Part 8 - Grafana

1. Start: Option A `kubectl port-forward service/grafana 3000:3000`; Option B already running.
2. Open http://localhost:3000 and log in `admin` / `admin` (change password when asked; local use only).
3. Data source: both setups **provision** a data source named `Prometheus` with uid `prometheus`. Verify: Connections → Data sources → Prometheus → **Save & test** → "Successfully queried the Prometheus API".
   - Manual alternative: Add data source → Prometheus → URL `http://prometheus:9090` (same URL works in both options because both services are named `prometheus`).
4. Dashboard: Option B auto-loads it. Option A: Dashboards → New → Import → Upload `monitoring/grafana-dashboard.json` → Import.
5. Generate traffic (see Part 7) and watch panels update (dashboard refreshes every 5 s).

**What each panel means**

| Panel | Query | Meaning |
|---|---|---|
| Prometheus target up | `up{job="student-management"}` | 1 = last scrape worked |
| Total HTTP requests | `sum(http_requests_total)` | Requests handled since app start |
| Students stored | `students_total` | Rows in the DB at last scrape |
| Rejected submissions | `student_validation_errors_total` | Invalid/duplicate submissions |
| Request rate per endpoint | `sum by (endpoint)(rate(http_requests_total[1m]))` | Requests/second per route |
| Requests by status code | `sum by (status)(rate(...))` | Spot 4xx/5xx |
| Latency p50/p95 | `histogram_quantile(...)` | Half / 95 % of requests were faster than this |
| Total requests over time | `sum by (endpoint)(http_requests_total)` | Raw counter growth |

No data? Check time range (top right), Prometheus target is UP, and that you generated traffic (`/health` and `/metrics` are intentionally not counted).

---

## Part 9 - End-to-end flow

1. Edit code → `git commit` → `git push` (branch/PR).
2. GitHub Actions runs tests and builds the image (automated).
3. `docker build -t studentmgmt:<new-tag> .` → `minikube image load` → `kubectl set image ...` (manual).
4. Kubernetes performs a rolling update; readiness probe gates traffic.
5. Prometheus scrapes the new Pod (same Service name, so no config change).
6. Grafana shows traffic you generate.

---

## Part 10 - Common problems

| Symptom | Likely cause | Fix |
|---|---|---|
| `failed to connect to the docker API` | Docker Desktop not running | Start it, wait for "Engine running" |
| `minikube start` fails with virtualization/driver error | Virtualization off, or Docker not running | Enable in BIOS; start Docker; `--driver=docker` |
| Pod `ErrImagePull` / `ImagePullBackOff` | Image not loaded in Minikube or tag mismatch | `minikube image load <tag>`; match `image:` in deployment |
| Pod `CrashLoopBackOff` | App crashes at start | `kubectl logs <pod> --previous` |
| Pod Running but `0/1` Ready | Readiness probe failing | `kubectl describe pod`; check `/health` |
| Port-forward returns nothing after update | Bound to old Pod | Ctrl+C and rerun port-forward |
| Grafana "No data" | Wrong time range / target down / no traffic | See Part 8 |
| `kubectl` connects to `localhost:8080` | No cluster context | `minikube start`; `kubectl config current-context` |
