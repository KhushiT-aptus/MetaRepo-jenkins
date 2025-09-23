pipeline {
    agent any

    environment {
        // DOCKER_REGISTRY = "docker.io"
        // DOCKER_CREDS = credentials('docker-creds')
        SONAR_TOKEN = credentials('sonar-token')
    }

    stages {
        stage('Determine Service') {
            steps {
                script {
                    // Read service config
                    def config = readYaml file: 'services-config.yml'

                    // Detect service name from Git repo URL
                    def repoName = env.GIT_URL.tokenize('/')[-1].replace('.git','')
                    if (!config.containsKey(repoName)) {
                        error "Repo ${repoName} not configured in services-config.yml"
                    }

                    SERVICE_NAME = repoName
                    REPO_URL = config[SERVICE_NAME].REPO_URL
                    DEPLOY_SERVER = config[SERVICE_NAME].DEPLOY_SERVER

                    echo "Detected Service: ${SERVICE_NAME}, Repo URL: ${REPO_URL}, Deploy Server: ${DEPLOY_SERVER}"
                }
            }
        }

        stage('Checkout') {
            steps {
                git branch: "${env.BRANCH_NAME}", url: "${REPO_URL}"
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarServer') {
                    sh """
                    sonar-scanner \
                        -Dsonar.projectKey=${SERVICE_NAME}-${env.BRANCH_NAME.replaceAll('/', '-') } \
                        -Dsonar.sources=.
                    """
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 2, unit: 'MINUTES') {
                    script {
                        def qg = waitForQualityGate(abortPipeline: true)
                        echo "Quality Gate Status: ${qg.status}"
                    }
                }
            }
        }
    } // <--- closing stages block

    post {
        success { echo "Deployment successful for ${SERVICE_NAME}" }
        failure { echo "Deployment FAILED for ${SERVICE_NAME}" }
    }
} // <--- closing pipeline block
