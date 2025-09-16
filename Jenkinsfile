
pipeline {
    agent any

    environment {
        REGISTRY = 'draft04' // Docker Hub or DOCR
        IMAGE_NAME = 'laravel-test'
        DOCKERHUB_CREDENTIALS_ID = 'dockerhub-creds'
        DO_SSH_KEY_ID = 'do-ssh-key'
        DROPLET_IP = 'your-droplet-ip'
        APP_KEY = credentials('laravel-app-key')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                script {
                    def shortSha = scm.head.abbreviatedId
                    docker.build("${REGISTRY}/${IMAGE_NAME}:${shortSha}")
                    docker.tag("${REGISTRY}/${IMAGE_NAME}:${shortSha}", "${REGISTRY}/${IMAGE_NAME}:latest")
                }
            }
        }

        stage('Login & Push') {
            steps {
                script {
                    def shortSha = scm.head.abbreviatedId
                    withDockerRegistry([ credentialsId: DOCKERHUB_CREDENTIALS_ID, url: "https://${REGISTRY}" ]) {
                        docker.push("${REGISTRY}/${IMAGE_NAME}:${shortSha}")
                        docker.push("${REGISTRY}/${IMAGE_NAME}:latest")
                    }
                }
            }
        }

        stage('Deploy to Droplet') {
            steps {
                script {
                    def shortSha = scm.head.abbreviatedId
                    withCredentials([sshUserPrivateKey(credentialsId: DO_SSH_KEY_ID, keyFileVariable: 'key')]) {
                        sh '''
                            ssh -o StrictHostKeyChecking=no -i ${key} root@${DROPLET_IP} \
                                "docker pull ${REGISTRY}/${IMAGE_NAME}:${shortSha} && \
                                 docker stop hello || true && docker rm hello || true && \
                                 docker run -d --name hello -p 80:80 \
                                    -e APP_ENV=production \
                                    -e APP_KEY=${APP_KEY} \
                                    -e BUILD_SHA=${shortSha} \
                                    -e BUILD_AT=$(date) \
                                    --restart unless-stopped \
                                    ${REGISTRY}/${IMAGE_NAME}:${shortSha}"
                        '''
                    }
                }
            }
        }
    }
}
