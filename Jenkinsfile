#!/usr/bin/env groovy

/*
 * ═══════════════════════════════════════════════════════════════════════════════
 * Jenkins CI/CD Pipeline
 * Full-Stack DevOps: Build → Test → Security Scan → Push → Deploy
 * ═══════════════════════════════════════════════════════════════════════════════
 */

pipeline {
    agent any

    // ═══════════════════════════════════════════════════════════════════════════
    // Environment Variables
    // ═══════════════════════════════════════════════════════════════════════════
    environment {
        // Application Config
        APP_NAME = 'cicd-demo-app'
        VERSION = "${env.BUILD_NUMBER}"
        DOCKER_REGISTRY = 'your-registry.com'
        DOCKER_IMAGE = "${DOCKER_REGISTRY}/${APP_NAME}"
        
        // Credentials
        DOCKER_CREDENTIALS = credentials('docker-registry-credentials')
        AWS_CREDENTIALS = credentials('aws-credentials')
        KUBECONFIG = credentials('kubeconfig')
        
        // Paths
        APP_DIR = 'app'
        K8S_DIR = 'k8s'
        
        // SonarQube
        SONARQUBE_SCANNER = tool 'SonarQubeScanner'
        SONARQUBE_TOKEN = credentials('sonarqube-token')
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Options
    // ═══════════════════════════════════════════════════════════════════════════
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        ansiColor('xterm')
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Parameters
    // ═══════════════════════════════════════════════════════════════════════════
    parameters {
        choice(
            name: 'DEPLOY_ENV',
            choices: ['none', 'staging', 'production'],
            description: 'Deployment Environment'
        )
        booleanParam(
            name: 'RUN_SECURITY_SCAN',
            defaultValue: true,
            description: 'Run security vulnerability scan'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip running tests'
        )
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Stages
    // ═══════════════════════════════════════════════════════════════════════════
    stages {
        
        // ───────────────────────────────────────────────────────────────────────
        // Stage 1: Checkout & Setup
        // ───────────────────────────────────────────────────────────────────────
        stage('📥 Checkout') {
            steps {
                script {
                    echo "╔════════════════════════════════════════════════════════════╗"
                    echo "║  🚀 Starting CI/CD Pipeline                                 ║"
                    echo "║  Branch: ${env.BRANCH_NAME}                                 ║"
                    echo "║  Build: ${env.BUILD_NUMBER}                                 ║"
                    echo "╚════════════════════════════════════════════════════════════╝"
                }
                checkout scm
                sh '''
                    echo "Node version:"
                    node --version
                    echo "NPM version:"
                    npm --version
                    echo "Docker version:"
                    docker --version
                '''
            }
        }

        // ───────────────────────────────────────────────────────────────────────
        // Stage 2: Install Dependencies
        // ───────────────────────────────────────────────────────────────────────
        stage('📦 Install Dependencies') {
            steps {
                dir(env.APP_DIR) {
                    sh '''
                        echo "Installing npm dependencies..."
                        npm ci
                    '''
                }
            }
        }

        // ───────────────────────────────────────────────────────────────────────
        // Stage 3: Code Quality & Linting
        // ───────────────────────────────────────────────────────────────────────
        stage('🔍 Code Quality') {
            parallel {
                stage('ESLint') {
                    steps {
                        dir(env.APP_DIR) {
                            sh 'npm run lint'
                        }
                    }
                }
                stage('SonarQube Analysis') {
                    when {
                        branch 'main'
                    }
                    steps {
                        withSonarQubeEnv('SonarQube') {
                            sh """
                                ${SONARQUBE_SCANNER}/bin/sonar-scanner \
                                    -Dsonar.projectKey=${APP_NAME} \
                                    -Dsonar.projectName="${APP_NAME}" \
                                    -Dsonar.projectVersion=${VERSION} \
                                    -Dsonar.sources=${APP_DIR} \
                                    -Dsonar.exclusions=node_modules/**,coverage/**,tests/** \
                                    -Dsonar.javascript.lcov.reportPaths=${APP_DIR}/coverage/lcov.info
                            """
                        }
                    }
                }
            }
        }

        // ───────────────────────────────────────────────────────────────────────
        // Stage 4: Testing
        // ───────────────────────────────────────────────────────────────────────
        stage('🧪 Testing') {
            when {
                expression { !params.SKIP_TESTS }
            }
            steps {
                dir(env.APP_DIR) {
                    sh '''
                        echo "Running unit tests with coverage..."
                        npm run test -- --coverage --reporters=default --reporters=jest-junit
                    '''
                }
            }
            post {
                always {
                    publishTestResults testResultsPattern: '**/junit.xml'
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: "${env.APP_DIR}/coverage/lcov-report",
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }

        // ───────────────────────────────────────────────────────────────────────
        // Stage 5: Security Scanning
        // ───────────────────────────────────────────────────────────────────────
        stage('🔒 Security Scan') {
            when {
                expression { params.RUN_SECURITY_SCAN }
            }
            parallel {
                stage('NPM Audit') {
                    steps {
                        dir(env.APP_DIR) {
                            sh 'npm audit --audit-level=moderate || true'
                        }
                    }
                }
                stage('Snyk Scan') {
                    steps {
                        snykSecurity(
                            snykInstallation: 'Snyk',
                            snykTokenId: 'snyk-token',
                            severity: 'medium',
                            failOnIssues: false,
                            monitorProjectOnBuild: true,
                            additionalArguments: "--file=${APP_DIR}/package.json"
                        )
                    }
                }
                stage('Trivy Scan') {
                    steps {
                        sh '''
                            # Install Trivy if not present
                            if ! command -v trivy &> /dev/null; then
                                curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh
                            fi
                            
                            # Scan filesystem
                            trivy fs --exit-code 0 --no-progress --format table -o trivy-fs-report.txt .
                        '''
                    }
                }
            }
        }

        // ───────────────────────────────────────────────────────────────────────
        // Stage 6: Build Docker Image
        // ───────────────────────────────────────────────────────────────────────
        stage('🐳 Build Docker Image') {
            steps {
                script {
                    def imageTag = "${DOCKER_IMAGE}:${VERSION}"
                    def latestTag = "${DOCKER_IMAGE}:latest"
                    
                    dir(env.APP_DIR) {
                        // Build multi-stage Docker image
                        sh """
                            echo "Building Docker image..."
                            docker build \
                                --target production \
                                --tag ${imageTag} \
                                --tag ${latestTag} \
                                --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                                --build-arg VCS_REF=\$(git rev-parse --short HEAD) \
                                --build-arg VERSION=${VERSION} \
                                .
                        """
                        
                        // Verify image
                        sh """
                            echo "Docker image built successfully!"
                            docker images | grep ${APP_NAME}
                            docker history ${imageTag}
                        """
                    }
                }
            }
        }

        // ───────────────────────────────────────────────────────────────────────
        // Stage 7: Scan Docker Image
        // ───────────────────────────────────────────────────────────────────────
        stage('🔍 Scan Docker Image') {
            when {
                expression { params.RUN_SECURITY_SCAN }
            }
            steps {
                script {
                    def imageTag = "${DOCKER_IMAGE}:${VERSION}"
                    
                    sh """
                        # Scan Docker image with Trivy
                        trivy image --exit-code 0 --severity HIGH,CRITICAL \
                            --format template --template '@contrib/html.tpl' \
                            -o trivy-image-report.html ${imageTag}
                        
                        # Also output to console
                        trivy image --exit-code 0 --severity HIGH,CRITICAL ${imageTag}
                    """
                }
            }
            post {
                always {
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: '.',
                        reportFiles: 'trivy-image-report.html',
                        reportName: 'Trivy Image Scan Report'
                    ])
                }
            }
        }

        // ───────────────────────────────────────────────────────────────────────
        // Stage 8: Push Docker Image
        // ───────────────────────────────────────────────────────────────────────
        stage('📤 Push Docker Image') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                script {
                    def imageTag = "${DOCKER_IMAGE}:${VERSION}"
                    def latestTag = "${DOCKER_IMAGE}:latest"
                    
                    // Login to registry
                    sh """
                        echo "\${DOCKER_CREDENTIALS_PSW}" | docker login \${DOCKER_REGISTRY} -u \${DOCKER_CREDENTIALS_USR} --password-stdin
                    """
                    
                    // Push images
                    sh """
                        echo "Pushing Docker images..."
                        docker push ${imageTag}
                        docker push ${latestTag}
                    """
                    
                    // Logout
                    sh 'docker logout ${DOCKER_REGISTRY}'
                }
            }
        }

        // ───────────────────────────────────────────────────────────────────────
        // Stage 9: Deploy to Staging
        // ───────────────────────────────────────────────────────────────────────
        stage('🚀 Deploy to Staging') {
            when {
                anyOf {
                    branch 'develop'
                    expression { params.DEPLOY_ENV == 'staging' }
                }
            }
            steps {
                script {
                    deployToKubernetes('staging', VERSION)
                }
            }
        }

        // ───────────────────────────────────────────────────────────────────────
        // Stage 10: Deploy to Production
        // ───────────────────────────────────────────────────────────────────────
        stage('🚀 Deploy to Production') {
            when {
                anyOf {
                    allOf {
                        branch 'main'
                        expression { params.DEPLOY_ENV == 'production' }
                    }
                }
            }
            steps {
                script {
                    // Manual approval
                    timeout(time: 5, unit: 'MINUTES') {
                        input message: 'Deploy to Production?', ok: 'Deploy',
                              submitterParameter: 'APPROVER'
                    }
                    
                    echo "Approved by: ${APPROVER}"
                    deployToKubernetes('production', VERSION)
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Post-Build Actions
    // ═══════════════════════════════════════════════════════════════════════════
    post {
        always {
            script {
                echo "Cleaning up..."
                sh '''
                    docker system prune -f || true
                    docker image prune -f || true
                '''
            }
            
            // Clean workspace
            cleanWs(
                deleteDirs: true,
                notFailBuild: true,
                patterns: [[pattern: '.git', type: 'EXCLUDE']]
            )
        }
        
        success {
            script {
                echo "✅ Pipeline completed successfully!"
                
                // Send success notification
                slackSend(
                    color: 'good',
                    message: """
                        ✅ *Build Successful*
                        
                        Job: ${env.JOB_NAME}
                        Build: #${env.BUILD_NUMBER}
                        Branch: ${env.BRANCH_NAME}
                        Duration: ${currentBuild.durationString}
                        
                        <${env.BUILD_URL}|View Build>
                    """.stripIndent()
                )
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline failed!"
                
                // Send failure notification
                slackSend(
                    color: 'danger',
                    message: """
                        ❌ *Build Failed*
                        
                        Job: ${env.JOB_NAME}
                        Build: #${env.BUILD_NUMBER}
                        Branch: ${env.BRANCH_NAME}
                        
                        <${env.BUILD_URL}console|View Console Output>
                    """.stripIndent()
                )
            }
        }
        
        unstable {
            script {
                echo "⚠️ Pipeline is unstable!"
                
                slackSend(
                    color: 'warning',
                    message: """
                        ⚠️ *Build Unstable*
                        
                        Job: ${env.JOB_NAME}
                        Build: #${env.BUILD_NUMBER}
                        Branch: ${env.BRANCH_NAME}
                        
                        <${env.BUILD_URL}|View Build>
                    """.stripIndent()
                )
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper Functions
// ═══════════════════════════════════════════════════════════════════════════════

def deployToKubernetes(String environment, String version) {
    echo "Deploying to ${environment} environment..."
    
    withCredentials([kubeconfigFile(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
        sh """
            # Set image tag in kustomization
            cd ${K8S_DIR}/overlays/${environment}
            kustomize edit set image app=${DOCKER_IMAGE}:${version}
            
            # Apply manifests
            kustomize build . | kubectl apply -f -
            
            # Wait for rollout
            kubectl rollout status deployment/${APP_NAME} -n ${environment} --timeout=300s
            
            # Verify deployment
            kubectl get pods -n ${environment}
            kubectl get svc -n ${environment}
        """
    }
    
    echo "✅ Deployment to ${environment} completed!"
}
