# Jenkins (CI/CD alternative to GitHub Actions)

The assessment accepts **Jenkins or GitHub Actions** as the CI/CD tool. This project provides both: `.github/workflows/ci.yml` and the `Jenkinsfile` at the repo root. Both do the same job; use whichever is your primary tool and mention the other.

| | GitHub Actions | Jenkins |
|---|---|---|
| Runs on | GitHub-hosted runner | Your own machine |
| Trigger | Push / PR event | Poll SCM every ~2 min (or webhook if reachable) |
| Pipeline file | `.github/workflows/ci.yml` | `Jenkinsfile` |
| Can reach local Minikube | No | **Yes** (same machine) |
| Server to maintain | No | Yes |

## 1. Run Jenkins on your machine (Windows PowerShell)

Jenkins needs Java 17 or 21 (a newer JDK may also work; if Jenkins complains about the Java version, install Temurin 21: `winget install EclipseAdoptium.Temurin.21.JDK`).

```powershell
java -version
mkdir C:\jenkins; cd C:\jenkins
Invoke-WebRequest https://get.jenkins.io/war-stable/latest/jenkins.war -OutFile jenkins.war
java -jar jenkins.war --httpPort=8085
```

Port 8085 avoids clashes with 8080 (your port-forwards). Running the WAR as **your user** means Jenkins sees the same `python`, `docker`, `kubectl` and `minikube` you use. (The Windows service installer runs as SYSTEM and will not see your Minikube config.)

1. Open http://localhost:8085.
2. Unlock with the password printed in the console, or: `Get-Content $env:USERPROFILE\.jenkins\secrets\initialAdminPassword`.
3. **Install suggested plugins**, create an admin user.

Keep this terminal open. Docker Desktop must be running.

## 2. Create the pipeline job

1. New Item → name `student-management` → **Pipeline** → OK.
2. Pipeline → Definition: **Pipeline script from SCM**.
3. SCM: **Git**, Repository URL `https://github.com/atharva-glitch10/Devops-Cie.git`.
   - Public repo: no credentials needed. Private repo: add a GitHub personal access token under Credentials (never put it in the Jenkinsfile).
4. Branch specifier: `*/main`. Script Path: `Jenkinsfile`. Save.
5. **Build with Parameters** (or Build Now the first time) → keep `DEPLOY_TO_MINIKUBE` unchecked → Build.

## 3. Verify

- Stage View shows: Checkout → Install dependencies → Test → Build image → Smoke test container (→ Deploy to Minikube if ticked), all green.
- Console Output ends with `Finished: SUCCESS`.
- `docker images studentmgmt` lists a tag `jenkins-<build number>`.

## 4. Deployment stage (continuous deployment to local Minikube)

With Minikube running, tick `DEPLOY_TO_MINIKUBE` and build. Jenkins loads the image and runs `kubectl set image` and waits for the rollout. Verify:

```powershell
kubectl get deployment student-management -o jsonpath="{.spec.template.spec.containers[0].image}"
```

It should print `studentmgmt:jenkins-<n>`. Roll back with `kubectl rollout undo deployment/student-management`.

## 5. Trigger

`pollSCM('H/2 * * * *')` makes Jenkins check GitHub about every two minutes and build when `main` has a new commit. Demo: push a small commit and watch a build start on its own. (A webhook would be instant but GitHub cannot reach `localhost` without a tunnel.)

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `'python' is not recognized` | Start Jenkins from a PowerShell where `python --version` works |
| `docker` cannot connect | Docker Desktop not running |
| Smoke test fails, port in use | Another process on 5055; change the port in the Jenkinsfile |
| Deploy stage: `minikube` not recognized | Start Jenkins from a shell with Minikube on PATH: `$env:Path += ";C:\Program Files\Kubernetes\Minikube"` |
| Deploy stage: connection refused | `minikube start --driver=docker` first |
| Job cannot clone | Wrong URL, or private repo without credentials |
| No build starts after push | Poll SCM waits up to ~2 minutes; check **Polling Log** |

Not verified yet on this project: run the job yourself and keep your own screenshot of the green Stage View.
