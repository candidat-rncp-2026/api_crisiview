pipeline {
    agent {
        docker {
            image 'node:20-bookworm'
            args '''-v /var/run/docker.sock:/var/run/docker.sock \
                    -v /usr/bin/docker:/usr/bin/docker \
                    -v /usr/libexec/docker/cli-plugins:/usr/libexec/docker/cli-plugins \
                    -v /home/arnol/staging:/home/arnol/staging \
                    -u root'''
        }
    }

    environment {
        DOCKER_IMAGE = 'candidatrncp2026/api-crisiview'
        VERSION = "${BUILD_NUMBER}"
        MYSQL_CONTAINER = "mysql-test-${BUILD_NUMBER}"
        DOCKER_NETWORK = "test-network-${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Docker Login') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                }
            }
        }

        stage('Install') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Start MySQL') {
            steps {
                sh """
                    docker network create ${DOCKER_NETWORK} || true
                    docker rm -f ${MYSQL_CONTAINER} || true
                    docker run -d \
                        --name ${MYSQL_CONTAINER} \
                        --network ${DOCKER_NETWORK} \
                        -e MYSQL_ROOT_PASSWORD=root \
                        -e MYSQL_DATABASE=crisiview \
                        mysql:8.4.8
                    sleep 40
                """
            }
        }

        stage('Test') {
            steps {
                sh """
                    docker network connect ${DOCKER_NETWORK} \$(hostname) || true
                    MYSQL_IP=\$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${MYSQL_CONTAINER})
                    echo "MySQL IP : \${MYSQL_IP}"
                    DB_HOST=\${MYSQL_IP} \
                    DB_PORT=3306 \
                    DB_USER=root \
                    DB_PASS=root \
                    DB_NAME=crisiview \
                    npm test -- --coverage --coverageDirectory=coverage || true
                """
            }
        }

        stage('SonarQube Analysis') {
            steps {
                sh """
                    docker run --rm \
                        --volumes-from \$(hostname) \
                        -w \$(pwd) \
                        -e SONAR_HOST_URL=http://10.0.2.15:9000 \
                        -e SONAR_TOKEN=sqp_f1aa11b84ca1938892f093163e108a365511b164 \
                        sonarsource/sonar-scanner-cli:latest \
                        -Dsonar.projectKey=api \
                        -Dsonar.sources=. \
                        -Dsonar.exclusions=node_modules/**,coverage/**,__tests__/** \
                        -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
                """
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

        stage('Push Docker Image') {
            steps {
                sh "docker push ${DOCKER_IMAGE}:${VERSION}"
                sh "docker push ${DOCKER_IMAGE}:latest"
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
                sh """
                    sleep 20
                    API_IP=\$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' api)
                    echo "Test API sur IP : \${API_IP}"
                    curl -f http://\${API_IP}:3001/techniciens || echo "API not ready yet"
                """
            }
        }
    }

    post {
        always {
            sh "docker rm -f ${MYSQL_CONTAINER} || true"
            sh "docker network disconnect ${DOCKER_NETWORK} \$(hostname) || true"
            sh "docker network rm ${DOCKER_NETWORK} || true"
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
