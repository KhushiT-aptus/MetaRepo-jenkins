pipeline {
    agent any

    parameters {
        string(name: 'repo_name', defaultValue: '', description: 'Service repository name (from webhook)')
        string(name: 'branch_name', defaultValue: '', description: 'Branch name (from webhook)')
    }

    environment {
        SONAR_TOKEN = credentials('sonar-token')
    }

    stages {

        stage('Checkout Config Repo') {
            steps {
                echo "Checking out meta repo to read services-config.yaml"
                git branch: "main", url: "https://github.com/KhushiT-aptus/MetaRepo-jenkins"
            }
        }

        stage('Determine Service') {
            steps {
                script {
                    def config = readYaml file: 'services-config.yaml'
                    echo "DEBUG from webhook: repo_name='${params.repo_name}', branch_name='${params.branch_name}'"

                    if (!config.containsKey(params.repo_name)) {
                        error "Repo ${params.repo_name} not configured in services-config.yaml"
                    }

                    def service = config[params.repo_name]
                    if (service == null) {
                        error "Repo '${params.repo_name}' not found or YAML malformed. Config keys: ${config.keySet()}"
                    }

                    env.SERVICE_NAME = params.repo_name
                    env.REPO_URL = service.REPO_URL
                    env.DEPLOY_SERVER = service.DEPLOY_SERVER

                    echo "Detected Service: ${env.SERVICE_NAME}, Repo URL: ${env.REPO_URL}, Deploy Server: ${env.DEPLOY_SERVER}"
                }
            }
        }

        stage('Checkout Service Repo') {
            steps {
                script {
                    def branch = params.branch_name.replace('refs/heads/', '')
                    echo "Checking out service repo: ${env.REPO_URL} branch: ${branch}"
                    git branch: branch, url: "${env.REPO_URL}"
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarServer') {
                    script {
                        def scannerHome = tool 'sonar-scanner'
                        def projectKey = "${env.SERVICE_NAME}-${params.branch_name.replaceAll('/', '-')}"
                        try {
                            sh """
                                ${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectKey} -Dsonar.sources=.
                            """
                        } catch (Exception e) {
                            echo "SonarQube analysis failed: ${e}"
                            throw e
                        }
                    }
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

        stage('Build Docker Image') {
            steps {
                script {
                    def imageTag = "${env.SERVICE_NAME}:${params.branch_name.replaceAll('/', '-')}"
                    def registry = "docker.io"
                    def creds = credentials('docker-creds') // username:password

                    echo "Building and pushing Docker image for ${env.SERVICE_NAME}"
                    sh """
                        chmod +x scripts/build_and_push.sh
                        ./scripts/build_and_push.sh "${imageTag}" "${registry}" "${creds}"
                    """
                }
            }
        }

        stage('Deploy Service') {
            steps {
                script {
                    def server = env.DEPLOY_SERVER
                    def registry = "docker.io"
                    def image = Aptusdatalabstech/env.SERVICE_NAME
                    def tag = params.branch_name.replaceAll('/', '-')
                    def creds = credentials('docker-creds')
                    def username = creds.split(':')[0]
                    def password = creds.split(':')[1]

                    echo "Deploying ${env.SERVICE_NAME} to server ${server}"
                    sh """
                        chmod +x ./scripts/deploy_compose.sh \
                        ./scripts/deploy_compose.sh "${server}" "${registry}" "${image}" "${tag}" "${username}" "${password}"
                    """
                }
            }
        }
    }

    post {
        success {
            echo " Deployment successful for ${env.SERVICE_NAME} on branch ${params.branch_name}"
        }
        failure {
            echo " Deployment FAILED for ${env.SERVICE_NAME} on branch ${params.branch_name}"
        }
    }
}
