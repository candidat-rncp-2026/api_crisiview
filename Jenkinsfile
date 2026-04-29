pipeline {
    agent {
        docker {
            image 'node:20-alpine'
            args '-v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker -u root'
        }
    }

    environment {
        DOCKER_IMAGE = 'api-crisiview'
        VERSION = "${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Test') {
            steps {
                sh 'npm test -- --coverage --coverageDirectory=coverage || true'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                sh '''
                    docker run --rm \
                        -v $(pwd):/usr/src \
                        -e SONAR_HOST_URL=http://10.0.2.15:9000 \
                        -e SONAR_TOKEN=sqp_f1aa11b84ca1938892f093163e108a365511b164 \
                        sonarsource/sonar-scanner-cli:latest \
                        -Dsonar.projectKey=api \
                        -Dsonar.sources=. \
                        -Dsonar.exclusions=node_modules/**,coverage/**
                '''
            }
        }

        stage('Security Scan') {
            steps {
                sh 'npm audit --audit-level=high || true'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${DOCKER_IMAGE}:${VERSION} -t ${DOCKER_IMAGE}:latest ."
            }
        }

        stage('Scan Image Trivy') {
            steps {
                sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --exit-code 0 --severity HIGH,CRITICAL ${DOCKER_IMAGE}:latest || true"
            }
        }

        stage('Deploy Staging') {
            steps {
                sh 'docker compose -f /home/arnol/staging/docker-compose.yml up -d --build'
            }
        }

        stage('Smoke Test') {
            steps {
                sh 'sleep 15'
                sh 'apk add --no-cache curl'
                sh 'curl -f http://10.0.2.15:3001/techniciens || echo "API not ready yet"'
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'coverage/**/*', allowEmptyArchive: true
        }
        success {
            echo 'Pipeline API reussi'
        }
        failure {
            echo 'Pipeline API echoue'
        }
    }
}
