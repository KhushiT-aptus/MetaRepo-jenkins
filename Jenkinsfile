pipeline {
    agent any

    environment {
        SONAR_TOKEN = credentials('sonar-token')
        // Initialize as empty; will be set dynamically
        SERVICE_NAME = ""
        REPO_URL = ""
        DEPLOY_SERVER = ""
    }

    stages {
        stage('Determine Service') {
            steps {
                script {
                    // Read service config
                    def config = readYaml file: 'services-config.yaml'
                    echo "DEBUG: Config keys = ${config.keySet()}"
                    // Detect service name from Git repo URL
                    def repoName = env.GIT_URL.tokenize('/')[-1].replace('.git','')
                    if (!config.containsKey(repoName)) {
                        error "Repo ${repoName} not configured in services-config.yml"
                    }

                    // Set as environment variables
                    env.SERVICE_NAME = repoName
                    env.REPO_URL = config[repoName].REPO_URL
                    env.DEPLOY_SERVER = config[repoName].DEPLOY_SERVER

                    echo "Detected Service: ${env.SERVICE_NAME}, Repo URL: ${env.REPO_URL}, Deploy Server: ${env.DEPLOY_SERVER}"
                }
            }
        }

        stage('Checkout') {
            steps {
                git branch: "${env.BRANCH_NAME}", url: "${env.REPO_URL}"
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarServer') {
                    sh """
                        sonar-scanner \
                            -Dsonar.projectKey=${env.SERVICE_NAME}-${env.BRANCH_NAME.replaceAll('/', '-') } \
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
    }

    post {
        success { echo "Deployment successful for ${env.SERVICE_NAME}" }
        failure { echo "Deployment FAILED for ${env.SERVICE_NAME}" }
    }
}
