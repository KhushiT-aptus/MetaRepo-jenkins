pipeline {
    agent any

    parameters {
        string(name: 'repo_name', defaultValue: '', description: 'Service repository name (from webhook)')
        string(name: 'branch_name', defaultValue: '', description: 'Branch name (from webhook)')
    }

    environment {
        SONAR_TOKEN = credentials('sonar-token')
        // SERVICE_NAME = ""
        // REPO_URL = ""
        // DEPLOY_SERVER = ""
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
                    // Read service config YAML
                    def config = readYaml file: 'services-config.yaml'
                    echo "DEBUG from webhook: repo_name='${params.repo_name}', branch_name='${params.branch_name}'"
                    echo "DEBUG: Config keys = ${config.keySet()}"

                    // Use repo_name parameter from webhook
                    def repoName = params.repo_name
                    echo "Service repo from webhook: ${repoName}"

                    if (!config.containsKey(repoName)) {
                        error "Repo ${repoName} not configured in services-config.yaml"
                    }

                    // Set environment variables dynamically
                    def service = config[repoName]
                    if (service == null) {
                        error "Repo '${repoName}' not found or YAML malformed. Config keys: ${config.keySet()}"
                    }

                   env.SERVICE_NAME = repoName
                   env.REPO_URL = service.REPO_URL
                   env.DEPLOY_SERVER = service.DEPLOY_SERVER

                   echo "SERVICE_NAME now = ${env.SERVICE_NAME}"
                   echo "REPO_URL now = ${env.REPO_URL}"
                   echo "DEPLOY_SERVER now = ${env.DEPLOY_SERVER}"


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

        // stage('SonarQube Analysis') {
        //     steps {
        //         withSonarQubeEnv('SonarServer') {
        //             script {
        //                 def branchKey = params.branch_name.replaceAll('/', '-')
        //                 sh """
        //                     sonar-scanner \
        //                         -Dsonar.projectKey=${env.SERVICE_NAME}-${branchKey} \
        //                         -Dsonar.sources=.
        //                 """
        //             }
        //         }
        //     }
        // }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarServer') {
                    script {
                        def scannerHome = tool 'sonar-scanner'
                        def projectKey = ""
                    if (env.BRANCH_NAME == "dev") {
                        projectKey = "myapp-develop"
                    } else if (env.BRANCH_NAME == "staging") {
                        projectKey = "myapp-staging"
                    } else if (env.BRANCH_NAME == "main") {
                        projectKey = "myapp"
                    } else {
                        projectKey = "myapp-feature-${env.BRANCH_NAME.replaceAll('/', '-')}"
                        
                    }
                        try {
                            sh """
                                echo "Using sonar-scanner from: ${scannerHome}"
                                ${scannerHome}/bin/sonar-scanner -X \
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
    }

    post {
        success {
            echo "Deployment successful for ${env.SERVICE_NAME} on branch ${params.branch_name}"
        }
        failure {
            echo "Deployment FAILED for ${env.SERVICE_NAME} on branch ${params.branch_name}"
        }
    }
}
