// Declarative Jenkins pipeline for the Student Management System.
// Works on a Windows agent (bat) and on Linux/macOS agents (sh).

def run(String cmd) {
    if (isUnix()) { sh cmd } else { bat cmd }
}

def runQuiet(String cmd) {
    // Never fails the build (used for clean-up)
    if (isUnix()) { sh(script: cmd, returnStatus: true) } else { bat(script: cmd, returnStatus: true) }
}

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    // A local Jenkins cannot receive GitHub webhooks, so it polls the repository.
    triggers {
        pollSCM('H/2 * * * *')
    }

    parameters {
        booleanParam(
            name: 'DEPLOY_TO_MINIKUBE',
            defaultValue: false,
            description: 'Load the image into Minikube and roll the Deployment to it (needs minikube + kubectl on this machine).'
        )
    }

    environment {
        IMAGE = 'studentmgmt'
        TAG   = "jenkins-${env.BUILD_NUMBER}"
        SMOKE = "smoke-${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install dependencies') {
            steps {
                script {
                    def py = isUnix() ? '.venv/bin/python' : '.venv\\Scripts\\python'
                    run('python -m venv .venv')
                    run("${py} -m pip install -r requirements.txt")
                }
            }
        }

        stage('Test') {
            steps {
                script {
                    def py = isUnix() ? '.venv/bin/python' : '.venv\\Scripts\\python'
                    run("${py} -m pytest -v")
                }
            }
        }

        stage('Build image') {
            steps {
                run("docker build -t ${IMAGE}:${TAG} .")
            }
        }

        stage('Smoke test container') {
            steps {
                script {
                    run("docker run -d --name ${SMOKE} -p 5055:5000 ${IMAGE}:${TAG}")
                    run('python scripts/smoke_test.py http://localhost:5055/health')
                }
            }
        }

        stage('Deploy to Minikube') {
            when {
                expression { params.DEPLOY_TO_MINIKUBE }
            }
            steps {
                run("minikube image load ${IMAGE}:${TAG}")
                run("kubectl set image deployment/student-management app=${IMAGE}:${TAG}")
                run('kubectl rollout status deployment/student-management --timeout=120s')
            }
        }
    }

    post {
        always {
            script {
                runQuiet("docker rm -f ${SMOKE}")
            }
        }
        success {
            echo "Pipeline succeeded: ${IMAGE}:${TAG}"
        }
        failure {
            echo 'Pipeline failed: open the red stage and read its log.'
        }
    }
}
