# Academic Report Template

Fill the `[...]` placeholders. **Record only results you personally verified.** Anything not yet run goes under "Planned", not "Results".

---

## 1. Title page

**End-to-End DevOps Pipeline for a Student Management System Using Git, GitHub Actions, Docker, Kubernetes, Prometheus and Grafana**

Submitted by: [Name] · Roll No: [Roll] · Class: [TY B.Tech IT] · Division: [Div]
Course: DevOps for Scalable Systems (Group Classroom CIE-01)
Faculty: [Faculty name] · Institution: [Institution] · Academic year: [Year]

## 2. Abstract

[150-200 words.] Describe: the problem (manual build/deploy/monitor is slow), the solution (one Flask app moved through Git, GitHub Actions, Docker, Kubernetes, Prometheus, Grafana), what is automated vs manual, and the outcome you verified. Example skeleton: *"This project implements ... The pipeline automatically tests and builds the application on every push. The container is deployed on a local Minikube cluster and monitored with Prometheus and Grafana. [State your verified results here.]"*

## 3. Introduction

Define DevOps, CI/CD, containerisation, orchestration and observability in 1-2 sentences each; explain why they matter for scalable systems.

## 4. Problem statement

Developers need a repeatable way to test, package, deploy and observe an application. Doing it by hand causes inconsistent environments, missed bugs and no visibility into runtime behaviour.

## 5. Objectives

1. Build a Student Management web application with API, validation, health and metrics endpoints.
2. Version it with Git and host it on GitHub.
3. Automate tests and image build using GitHub Actions.
4. Containerise with Docker.
5. Deploy with Kubernetes (Minikube) including probes, scaling, rolling update and rollback.
6. Monitor with Prometheus and visualise with Grafana.

## 6. Software and hardware requirements

| Item | Used (fill in your actual versions) |
|---|---|
| OS | Windows [10/11] |
| RAM / CPU | [≥ 8 GB recommended] / [x cores], virtualization enabled |
| Python | [version] |
| Git | [version] |
| Docker Desktop | [version] |
| kubectl / Minikube | [versions] |
| Flask / prometheus-client / pytest / gunicorn | see `requirements.txt` |
| Prometheus / Grafana images | `prom/prometheus:v2.54.1`, `grafana/grafana:11.2.0` |

## 7. System architecture

Insert the Mermaid diagram from README (render it or redraw it) and describe each arrow: developer → GitHub → Actions; image → Minikube; Service → Pod; Prometheus → `/metrics`; Grafana → Prometheus.

## 8. Implementation methodology

Describe the order you followed: application → tests → Git/GitHub → CI → Docker → Kubernetes → Prometheus → Grafana → integration. State design decisions: 1 replica due to SQLite; static Prometheus target; manual image loading; gunicorn with one worker.

## 9. Tool-by-tool implementation

For each of **Git/GitHub, GitHub Actions, Docker, Kubernetes, Prometheus, Grafana** write: purpose, files involved, key commands, how you verified it, one problem you hit and how you solved it. (Source material: `docs/SETUP_GUIDE.md`.)

## 10. Testing and results

### 10.1 Planned tests
Use the list in `docs/VERIFICATION_CHECKLIST.md`.

### 10.2 Verified results (fill in only what you ran)

| Check | Date | Result (pass/fail) | Evidence (figure no.) |
|---|---|---|---|
| pytest | [ ] | [ ] | Fig. [ ] |
| GitHub Actions run | [ ] | [ ] | Fig. [ ] |
| Docker build/run | [ ] | [ ] | Fig. [ ] |
| Kubernetes deployment | [ ] | [ ] | Fig. [ ] |
| Rolling update / rollback | [ ] | [ ] | Fig. [ ] |
| Prometheus target UP | [ ] | [ ] | Fig. [ ] |
| Grafana dashboard with live data | [ ] | [ ] | Fig. [ ] |

## 11. Screenshots to capture

1. App home page with at least two students; validation error state.
2. `python -m pytest -v` output.
3. GitHub repo page and commit history/branch.
4. GitHub Actions run (green) and, optionally, a failed run you then fixed.
5. `docker images`, `docker ps`, `docker logs`.
6. `kubectl get deployments,pods,services`.
7. `kubectl describe pod` (probes, limits).
8. Rolling update (`rollout status`, `rollout history`) and rollback.
9. Prometheus Targets page (UP) and a query graph.
10. Grafana data-source test and the dashboard with live data.

## 12. Advantages

Repeatable builds, early bug detection, environment consistency, self-healing and easy rollback via Kubernetes, and real-time visibility via metrics. All tools used are free and open source.

## 13. Limitations

SQLite and `emptyDir` are not durable or multi-replica safe; no authentication or TLS; deployment to the cluster is manual; static Prometheus targets; single-node local cluster; monitoring data not persisted.

## 14. Future scope

PostgreSQL with persistent volume, Ingress + TLS, Helm, GHCR + automated deploy / GitOps, Alertmanager rules, autoscaling (HPA), authentication, centralised logging.

## 15. Conclusion

[Summarise what you built and verified; refer to section 10.2 for evidence. Do not claim anything you did not verify.]

## 16. References

- Git documentation - https://git-scm.com/doc
- GitHub Actions documentation - https://docs.github.com/actions
- Docker documentation - https://docs.docker.com
- Kubernetes documentation - https://kubernetes.io/docs
- Minikube documentation - https://minikube.sigs.k8s.io/docs
- Prometheus documentation - https://prometheus.io/docs
- Grafana documentation - https://grafana.com/docs
- Flask documentation - https://flask.palletsprojects.com
- prometheus-client (Python) - https://github.com/prometheus/client_python
