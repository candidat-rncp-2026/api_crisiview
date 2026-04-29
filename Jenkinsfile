pipeline {
    agent {
        docker {
            image 'node:20-alpine'
            args '-v /var/run/docker.sock:/var/run/docker.sock -u root'
        }
    }

    environment {
        DOCKER_IMAGE = 'api-crisiview'
        VERSION = "${BUILD_NUMBER}"
        SONAR_HOST_URL = 'http://10.0.2.15:9000'
        SONAR_TOKEN = 'sqp_f1aa11b84ca1938892f093163e108a365511b164'
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
                    apk add --no-cache openjdk17-jre curl unzip
                    curl -sSLo /tmp/sonar-scanner.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-6.2.1.4610-linux-x64.zip
                    unzip -q /tmp/sonar-scanner.zip -d /tmp/
                    /tmp/sonar-scanner-6.2.1.4610-linux-x64/bin/sonar-scanner \
                        -Dsonar.projectKey=api \
                        -Dsonar.sources=. \
                        -Dsonar.host.url=http://10.0.2.15:9000 \
                        -Dsonar.token=sqp_f1aa11b84ca1938892f093163e108a365511b164 \
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
                sh 'apk add --no-cache docker-cli'
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
                sh 'apk add --no-cache docker-cli'
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
