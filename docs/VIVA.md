# Viva Preparation (38 questions)

## DevOps and CI/CD

1. **What is DevOps?** A culture and set of practices that joins development and operations so software is built, tested, released and monitored quickly and reliably, with heavy automation.
2. **What is CI, CD (delivery), CD (deployment)?** CI: every change is built and tested automatically. Continuous delivery: every passing build is ready to release, a human approves. Continuous deployment: every passing build is released automatically.
3. **Which of these does your project implement?** CI (tests + image build). Deployment to Minikube is manual, so it is not continuous deployment.
4. **Why automate tests in a pipeline?** Same checks every time, fast feedback, bad changes are caught before they reach users.

## Git and GitHub

5. **Git vs GitHub?** Git is the version-control tool on your machine; GitHub is a hosting service for Git repositories with PRs and Actions.
6. **What do `add`, `commit`, `push` do?** `add` stages changes, `commit` records a snapshot locally, `push` uploads commits to the remote.
7. **Why use branches and pull requests?** Isolate work and let CI and reviewers check it before merging to `main`.
8. **What must never be committed?** Passwords, tokens, keys, `.env` files, database files, virtual environments. That is why `.gitignore` exists.

## GitHub Actions

9. **What triggers your workflow?** Push and pull_request events on `main`.
10. **Explain the workflow structure.** A workflow has jobs; jobs have steps; each job runs on a fresh runner. Our `docker` job `needs: test`, so it only runs if tests pass.
11. **How do you debug a failed run?** Open the run, find the red step, read its log, reproduce locally, fix, push.
12. **Why can't GitHub Actions deploy straight to your Minikube?** The runner is on GitHub's cloud and cannot reach your laptop's private cluster; it would also need credentials and a registry.

## Docker

13. **Image vs container?** Image: read-only template. Container: running instance of an image.
14. **Why copy `requirements.txt` before the code in the Dockerfile?** Layer caching: dependencies are only reinstalled when requirements change.
15. **Why does the app bind to `0.0.0.0`?** `127.0.0.1` inside a container is only reachable from inside that container; `0.0.0.0` lets port mapping from outside work.
16. **Why run as a non-root user?** Limits damage if the app is compromised.
17. **Why gunicorn instead of `flask run`?** Flask's built-in server is for development only; gunicorn is a production-grade WSGI server.
18. **What does `.dockerignore` do?** Keeps unneeded or sensitive files (`.git`, `.env`, `.venv`, DB files) out of the build context and image.

## Kubernetes

19. **Pod vs Deployment vs Service vs container?** Container: process from an image. Pod: wrapper around one or more containers. Deployment: manages replicas and rolling updates for Pods. Service: stable network endpoint load-balancing to Pods by label.
20. **What are readiness and liveness probes?** Readiness: is the Pod ready to receive traffic? If failing, it is removed from Service endpoints. Liveness: is it still alive? If failing, the container is restarted.
21. **What are requests and limits?** Requests are what the scheduler reserves; limits are the maximum allowed. Exceeding the memory limit gets the container killed.
22. **How does a rolling update work?** New Pods are created and become ready before old ones are removed (`maxSurge 1`, `maxUnavailable 0`), so there is no downtime.
23. **How do you roll back?** `kubectl rollout undo deployment/student-management`.
24. **Why are there no multiple replicas by default?** SQLite is a file in one Pod; each replica would have its own separate data.
25. **How did the image get into the cluster?** `minikube image load`, because Minikube's runtime cannot see Docker Desktop's local images; `imagePullPolicy: IfNotPresent` uses it.

## Prometheus, Grafana, metrics

26. **What is Prometheus and how does it collect data?** A time-series database that *pulls* (scrapes) metrics over HTTP from `/metrics` at fixed intervals.
27. **Counter, gauge, histogram?** Counter only goes up (requests). Gauge goes up/down (students stored). Histogram buckets observations (latency) so percentiles can be computed.
28. **What is `rate()`?** Per-second increase of a counter over a time window, e.g. `rate(http_requests_total[1m])`.
29. **Application vs OS metrics?** Application metrics describe what the app does (requests, latency); OS metrics describe the machine (CPU, memory, disk) and need something like node-exporter. We only collect application (and app-process) metrics.
30. **Why not label metrics by raw URL or student ID?** Each new value creates a new time series (high cardinality), which can overload Prometheus. We use the route pattern.

## Why these tools, and how they communicate

31. **Why Flask/SQLite/Minikube?** Small, free, simple to explain and run offline on a laptop. SQLite is only suitable for a demo.
32. **How does Prometheus reach the app inside Kubernetes?** Through the Service DNS name `student-management.default.svc.cluster.local:80`, which routes to the Pod's port 5000.
33. **How does Grafana talk to Prometheus?** Grafana's data source calls `http://prometheus:9090` (the Prometheus Service) and sends PromQL queries; Grafana stores no metrics itself.
34. **Why is `localhost` wrong as a Prometheus target?** Inside the Prometheus container `localhost` is the Prometheus container itself.
35. **Where does your pipeline stop being automated?** After the image build; loading the image and `kubectl apply/set image` are manual. Closing the gap requires a registry (e.g. GHCR) plus a reachable cluster or GitOps tool.

## Security and limitations

36. **List three limitations.** SQLite/emptyDir data loss and no HA; no authentication/TLS; manual deployment; Grafana/Prometheus not hardened or persistent.
37. **How would you handle secrets properly?** Kubernetes Secrets / GitHub Actions encrypted secrets, never in source or in images.
38. **What would you change for production?** Managed database, PVC or external storage, Ingress with TLS, auth, alerting, autoscaling, image scanning.
