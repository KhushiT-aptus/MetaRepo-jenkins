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
                        git branch: "main", url: "https://github.com/KhushiT-aptus/MetaRepo-jenkins.git"
                    }
                }
            }
        }

        stage('Determine Service') {
            steps {
                script {
                    def config = readYaml file: 'services-config.yaml'
                    if (!config.containsKey(params.repo_name)) {
                        error "Repo ${params.repo_name} not configured in services-config.yaml"
                    }
                    def service = config[params.repo_name]
                    if (service == null) {
                        error "Repo '${params.repo_name}' not found or YAML malformed."
                    }

                    env.SERVICE_NAME  = params.repo_name
                    env.REPO_URL      = service.REPO_URL
                    env.DEPLOY_SERVER = service.DEPLOY_SERVER
                }
            }
        }

        stage('Checkout Service Repo') {
            steps {
                script {
                    def branch = params.branch_name.replace('refs/heads/', '')
                    git branch: branch, url: env.REPO_URL
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarServer') {
                    script {
                        def scannerHome = tool 'sonar-scanner'
                        def branchTag   = params.branch_name.replaceAll('refs/heads/', '').replaceAll('/', '-')
                        def projectKey  = "${env.SERVICE_NAME}-${branchTag}"
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=${projectKey} \
                            -Dsonar.sources=.
                        """
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
                // Use SSH Agent plugin for reliable SSH key handling
                sshagent(['ssh-deploy-key']) {
                    withCredentials([usernamePassword(credentialsId: 'docker-creds', 
                                                      usernameVariable: 'DOCKER_USER', 
                                                      passwordVariable: 'DOCKER_PASS')]) {
                        script {
                            echo "=== Starting Deploy Service stage ==="
                            echo "DEPLOY_SERVER: ${env.DEPLOY_SERVER}"
                            echo "SERVICE_NAME: ${env.SERVICE_NAME}"
                            echo "Branch: ${params.branch_name}"

                            def server     = env.DEPLOY_SERVER
                            def registry   = "docker.io"
                            def image      = "aptusdatalabstech/${env.SERVICE_NAME}"
                            def tag        = params.branch_name.replaceAll('refs/heads/', '')
                            def scriptPath = "${env.META_REPO_DIR}/scripts/deploy_compose.sh"

                            // Make sure the script exists
                            if (!fileExists(scriptPath)) {
                                error "Deploy script not found at ${scriptPath}"
                            }

                            try {
                                echo "Copying deploy script to remote server..."
                                 def username = 'aptus'
                                sh """
                                    scp -o StrictHostKeyChecking=no ${scriptPath} ${username}@${server}:/tmp/deploy_compose.sh
                                """

                                echo "Running deploy script on remote server..."
                              
        sh """
            scp -o StrictHostKeyChecking=no ${scriptPath} ${username}@${server}:/tmp/deploy_compose.sh
            ssh -vvv -o StrictHostKeyChecking=no ${username}@${server} '
                chmod +x /tmp/deploy_compose.sh
                /tmp/deploy_compose.sh "${server}" "${registry}" "${image}" "${tag}" "${DOCKER_USER}" "${DOCKER_PASS}"
            '
        """
                                echo "Deploy script executed successfully!"

                            } catch (err) {
                                echo "[ERROR] Deployment failed: ${err}"
                                error "Deploy stage failed. See above logs."
                            }

                            echo "=== Deploy Service stage completed ==="
                        }
                    }
                }
            }
        }

    } // <-- Close stages block

    post {
        success {
            echo "Deployment successful for ${env.SERVICE_NAME} on branch ${params.branch_name}"
        }
        failure {
            echo "Deployment FAILED for ${env.SERVICE_NAME} on branch ${params.branch_name}"
        }
    }

} // <-- Close pipeline
