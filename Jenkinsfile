pipeline {
    agent any

    environment {
        SONAR_TOKEN = credentials('sonar-token')
        SERVICE_NAME = ""
        REPO_URL = ""
        DEPLOY_SERVER = ""
    }

    stages {

        stage('Checkout Config Repo') {
            steps {
                echo "Checking out meta repo to read services-config.yaml"
                // Replace with your meta repo URL containing services-config.yaml
                git branch: "main", url: "https://github.com/KhushiT-aptus/MetaRepo-jenkins"
            }
        }

        stage('Determine Service') {
            steps {
                script {
                    // Read service config YAML
                    def config = readYaml file: 'services-config.yaml'
                    echo "DEBUG: Config keys = ${config.keySet()}"

                    // Detect service name from JOB_NAME or BRANCH_NAME
                    def repoName = env.JOB_NAME.tokenize('/')[-1]  // safer than GIT_URL
                    if (!config.containsKey(repoName)) {
                        error "Repo ${repoName} not configured in services-config.yaml"
                    }

                    // Set environment variables
                    env.SERVICE_NAME = repoName
                    env.REPO_URL = config[repoName].REPO_URL
                    env.DEPLOY_SERVER = config[repoName].DEPLOY_SERVER

                    echo "Detected Service: ${env.SERVICE_NAME}, Repo URL: ${env.REPO_URL}, Deploy Server: ${env.DEPLOY_SERVER}"
                }
            }
        }

        stage('Checkout Service Repo') {
            steps {
                echo "Checking out actual service repo: ${env.REPO_URL}"
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
        success {
            echo "Deployment successful for ${env.SERVICE_NAME}"
        }
        failure {
            echo "Deployment FAILED for ${env.SERVICE_NAME}"
        }
    }
}
