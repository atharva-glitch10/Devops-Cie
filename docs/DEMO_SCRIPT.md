# Demonstration Script (8-10 minutes per group)

Matches the CIE-01 rubric: each student demonstrates one primary tool (9 marks each), then the group shows integration and troubleshooting (14 marks). **Rotate the tool allocation between groups; confirm yours with your faculty.**

## Before the viva (prepare 10 minutes earlier)

Have these already running so the demo is not spent waiting:

```powershell
# Docker Desktop must already be running
minikube start --driver=docker
docker build -t studentmgmt:1.0.0 .
minikube image load studentmgmt:1.0.0
kubectl apply -f k8s/ ; kubectl apply -f monitoring/k8s-monitoring.yaml
kubectl get pods        # all Running
```

Open terminals: **T1** project folder (git/docker), **T2** `kubectl port-forward service/student-management 8080:80`, **T3** `kubectl port-forward service/prometheus 9090:9090`, **T4** `kubectl port-forward service/grafana 3000:3000`. Browser tabs: GitHub repo/Actions, app :8080, Prometheus :9090, Grafana :3000 (dashboard imported).

## Introduction (say this, ~30 s)

> "Our project is a Student Management System built with Flask. We use one application across the whole DevOps lifecycle. Git and GitHub hold the code, GitHub Actions runs tests and builds a Docker image on every push, Docker packages the app, Kubernetes on Minikube runs it, Prometheus scrapes its metrics endpoint, and Grafana shows those metrics. Each of us will demonstrate one tool and then we will show the integration."

## Timeline

| Time | Who | Terminal / UI | Do | Examiner should see | Say |
|---|---|---|---|---|---|
| 0-1 | All | - | Each states name, tool, role | - | Roles: Source control / CI-CD / Containers / Orchestration owner |
| 1-2 | Git owner | T1 | `git log --oneline -5`; `git branch -a`; `git status` | Commits, a feature branch | Commit = snapshot; branch = isolated work; push shares to GitHub |
| 1-2 (demo) | Git owner | T1 | Make a one-line edit, `git add -A; git commit -m "Demo change"; git push` | Push succeeds | Explain add → commit → push |
| 2-3 | CI/CD owner | Browser: Actions | Open the run triggered by the push; expand the test and docker steps | Green jobs, pytest output | Trigger: push/PR to main; test job gates the docker job; this is CI, deployment is manual |
| 3-4 | Docker owner | T1 | Show `Dockerfile`; `docker images studentmgmt`; `docker run -d --name demo -p 5001:5000 studentmgmt:1.0.0`; `curl.exe localhost:5001/health`; `docker logs demo`; `docker rm -f demo` | Health JSON, logs | Image = template, container = running instance; non-root user; binds 0.0.0.0 |
| 4-5 | K8s owner | T1 + browser :8080 | `kubectl get deploy,pods,svc`; open app; `kubectl scale deployment/student-management --replicas=2`, `kubectl get pods`, scale back to 1 | Pods Running, app loads | Deployment keeps desired Pods; Service gives stable access; probes decide readiness; SQLite is why replicas=1 normally |
| 5-6 | Monitoring owner(s) | Prometheus :9090 | Status → Targets (UP); query `sum(http_requests_total)` | Target UP, value | Prometheus pulls `/metrics` every 5 s from the Service DNS name |
| 6-7 | Monitoring owner(s) | T1 then Grafana :3000 | `1..40 \| % { Invoke-WebRequest http://localhost:8080/ -UseBasicParsing \| Out-Null }`; show dashboard | Panels move | Counters → rate → panels; p95 latency meaning |
| 7-9 | Faculty picks fault | see drills below | Diagnose with team | Correct diagnosis + fix | Think: symptom → logs/describe → cause → fix |
| 9-10 | Viva | - | Answer 1-2 questions | - | See [VIVA.md](VIVA.md) |

## Integration walkthrough (the "5-7 min" slot, ~1 min)

Show the chain in order: commit/push (Git) → Actions run (CI) → image (`docker images`) → Pod running that image (`kubectl get deploy student-management -o jsonpath="{.spec.template.spec.containers[0].image}"`) → target UP (Prometheus) → panel moving (Grafana). Be explicit: **the CI part is automated; loading the image into Minikube and `kubectl` are manual.**

## Troubleshooting drills (practise these, matches the rubric's scenarios)

| Scenario | Safe way to create it | Diagnose | Fix |
|---|---|---|---|
| Git push does not trigger CI | Push to a branch with no PR, or look for a workflow file in the wrong path | Actions tab shows no run; check branch name and `.github/workflows/ci.yml` path; Settings → Actions enabled? | Push to `main` or open a PR; fix path |
| CI build fails | On a branch, change an assertion in `tests/test_app.py` and push | Actions → failed step → log shows pytest assertion | Fix test/code, push |
| Container runs but app inaccessible | `docker run -d --name bad studentmgmt:1.0.0` (no `-p`) | `docker ps` PORTS column only shows `5000/tcp`, no host mapping; `curl` fails | Re-run with `-p 5000:5000` |
| Pod `ImagePullBackOff` | `kubectl set image deployment/student-management app=studentmgmt:9.9.9` | `kubectl get pods`; `kubectl describe pod <pod>` Events: failed to pull image | `kubectl rollout undo deployment/student-management` or load the correct tag |
| Pod `CrashLoopBackOff` | `kubectl set env deployment/student-management DATABASE_PATH=/nonexistent/x/students.db` | `kubectl logs <pod> --previous` shows PermissionError creating the directory | `kubectl rollout undo deployment/student-management` |
| Prometheus target DOWN | `kubectl scale deployment/student-management --replicas=0` | Prometheus Targets page shows DOWN and error; `kubectl get endpoints student-management` is empty | `kubectl scale deployment/student-management --replicas=1` |
| Grafana panel shows no data | Set the dashboard time range to a window before the app ran, or stop generating traffic and use `rate()` panels | Check time range, check target UP, run the PromQL in Prometheus directly | Correct range; generate traffic; fix metric name |

After a drill, run `kubectl get pods` and confirm everything is back to Running. Remember that restoring a Pod restarts the app and **empties the demo database** (emptyDir).

## Likely follow-up questions

Why one replica? (SQLite file per Pod.) Why NodePort/port-forward? (Local Minikube, no cloud load balancer.) How does Prometheus find the app? (Static target = Service DNS name.) What is automated? (Tests and image build only.)
