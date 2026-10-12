# Verification Checklist

Tick each box **only after you have run the check yourself**. Output shown is an *example* of what to expect, not a recorded result.

| # | Check | How to verify | Example expected result | Done |
|---|---|---|---|---|
| 1 | App starts | `python app.py` | `Running on http://127.0.0.1:5000` | ☐ |
| 2 | Students can be viewed | Open http://127.0.0.1:5000 | Table, "No students yet" when empty | ☐ |
| 3 | Student can be added | Use the form | Green "Student added successfully", row appears | ☐ |
| 4 | Validation works | Submit year `9` via API or bad email in form | HTTP 400 / red field messages | ☐ |
| 5 | Duplicate email rejected | Add same email twice | HTTP 409 / "already exists" | ☐ |
| 6 | Tests pass | `python -m pytest -v` | All tests `PASSED` | ☐ |
| 7 | Health endpoint | `curl.exe http://127.0.0.1:5000/health` | `{"database":"reachable","status":"ok"}` | ☐ |
| 8 | Metrics endpoint | `curl.exe http://127.0.0.1:5000/metrics` | Lines starting `http_requests_total`, `students_total` | ☐ |
| 9 | Code is on GitHub | `git remote -v`, check repo page | Files visible on GitHub | ☐ |
| 10 | Workflow succeeds | GitHub → Actions → CI | Both jobs green | ☐ |
| 11 | Workflow fails on a broken test (optional proof) | Break an assertion on a branch, push, open PR | Red ✗ on the PR; revert | ☐ |
| 12 | Docker image builds | `docker build -t studentmgmt:1.0.0 .` | Build finishes without error; `docker images studentmgmt` lists it | ☐ |
| 13 | Container runs | `docker run -d --name studentmgmt -p 5000:5000 studentmgmt:1.0.0`; `docker ps` | Status `Up ... (healthy)` | ☐ |
| 14 | Container serves app | `curl.exe http://localhost:5000/health` | status ok | ☐ |
| 15 | Runs as non-root | `docker exec studentmgmt id` | `uid=10001(appuser)` | ☐ |
| 16 | Cluster is up | `kubectl get nodes` | `Ready` | ☐ |
| 17 | Image is in Minikube | `minikube image ls \| Select-String studentmgmt` | Shows `studentmgmt:1.0.0` | ☐ |
| 18 | Resources healthy | `kubectl get deployments,pods,services` | Deployment `1/1`, Pod `1/1 Running`, Service has NodePort | ☐ |
| 19 | App reachable via K8s | `kubectl port-forward service/student-management 8080:80`; open http://localhost:8080 | App page loads | ☐ |
| 20 | Rolling update | `kubectl set image deployment/student-management app=studentmgmt:1.0.1` + `kubectl rollout status ...` | `successfully rolled out` | ☐ |
| 21 | Rollback | `kubectl rollout undo deployment/student-management` | Returns to previous image: `kubectl get deploy student-management -o jsonpath="{.spec.template.spec.containers[0].image}"` | ☐ |
| 22 | Prometheus target UP | http://localhost:9090/targets | `student-management` UP | ☐ |
| 23 | Counters change | Query `sum(http_requests_total)`, generate traffic, query again | Value increases | ☐ |
| 24 | Grafana data source works | Connections → Data sources → Save & test | "Successfully queried the Prometheus API" | ☐ |
| 25 | Grafana shows real data | Open dashboard, generate traffic | Request-rate and total panels move | ☐ |
| 26 | Clean-up | `kubectl delete -f k8s/`; `docker rm -f studentmgmt` | Resources gone | ☐ |

Evidence to capture (screenshots/log text) is listed in [REPORT.md](REPORT.md) section 11.
