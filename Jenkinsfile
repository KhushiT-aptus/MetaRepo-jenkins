pipeline {
    agent any

    parameters {
        string(name: 'repo_name', defaultValue: '', description: 'Service repository name (from webhook)')
        string(name: 'branch_name', defaultValue: '', description: 'Branch name (from webhook)')
    }

    environment {
        SONAR_TOKEN   = credentials('sonar-token')
        META_REPO_DIR = "${WORKSPACE}/meta-repo"
    }

    stages {

        stage('Checkout Config Repo') {
            steps {
                script {
                    echo "Checking out meta repo to read services-config.yaml"
                    dir("${env.META_REPO_DIR}") {
                        git branch: "main", url: "https://github.com/KhushiT-aptus/MetaRepo-jenkins"
                    }
                }
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

                    env.SERVICE_NAME  = params.repo_name
                    env.REPO_URL      = service.REPO_URL
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
                        def branchTag   = "${params.branch_name}".replaceAll('refs/heads/', '').replaceAll('/', '-')
                        def projectKey  = "${env.SERVICE_NAME}-${branchTag}"
                        try {
                            sh """
                                ${scannerHome}/bin/sonar-scanner \
                                -Dsonar.projectKey=${projectKey} \
                                -Dsonar.sources=.
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
                    def imageTag   = "${env.SERVICE_NAME}:${params.branch_name.replaceAll('refs/heads/', '').replaceAll('/', '-')}"
                    def registry   = "docker.io"
                    def scriptPath = "${env.META_REPO_DIR}/scripts/build_and_push.sh"

                    withCredentials([usernamePassword(credentialsId: 'docker-creds',
                                                      usernameVariable: 'DOCKER_USER',
                                                      passwordVariable: 'DOCKER_PASS')]) {
                        sh """
                            chmod +x "${scriptPath}"
                            "${scriptPath}" "${imageTag}" "${registry}" "${DOCKER_USER}" "${DOCKER_PASS}"
                        """
                    }
                }
            }
        }

        stage('Deploy Service') {
            steps {
                script {
                    def server     = "${env.DEPLOY_SERVER}"
                    def registry   = "docker.io"
                    def image      = "aptusch/${env.SERVICE_NAME}"
                    def tag        = "${params.branch_name}".replaceAll('refs/heads/', '')
                    def scriptPath = "${env.META_REPO_DIR}/scripts/deploy_compose.sh"

                    echo "Deploying ${env.SERVICE_NAME} to server ${server} with tag ${tag}"

                    withCredentials([
                        sshUserPrivateKey(credentialsId: 'ssh-deploy-key',
                                          keyFileVariable: 'SSH_KEY',
                                          usernameVariable: 'SSH_USER'),
                        usernamePassword(credentialsId: 'docker-creds',
                                         usernameVariable: 'DOCKER_USER',
                                         passwordVariable: 'DOCKER_PASS')
                    ]) {
                        sh """
                            scp -i "$SSH_KEY" -o StrictHostKeyChecking=no "${scriptPath}" $SSH_USER@${server}:/tmp/deploy_compose.sh
                            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no $SSH_USER@${server} \
                                "chmod +x /tmp/deploy_compose.sh && /tmp/deploy_compose.sh '${server}' '${registry}' '${image}' '${tag}' '${DOCKER_USER}' '${DOCKER_PASS}'"
                        """
                    }
                }
            }
        }
    } // ✅ closes "stages"

    post {
        success {
            echo "Deployment successful for ${env.SERVICE_NAME} on branch ${params.branch_name}"
        }
        failure {
            echo "Deployment FAILED for ${env.SERVICE_NAME} on branch ${params.branch_name}"
        }
    }
}
