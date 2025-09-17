# Laravel Hello World API

A simple Laravel application that provides a REST API endpoint to return a "Hello World" JSON response with automated CI/CD deployment using Jenkins and Docker.

## Features

- Simple REST API endpoint
- JSON response format
- Laravel 11 framework
- Dockerized application
- Automated CI/CD with Jenkins
- Deployment to DigitalOcean Droplet

## Requirements

- PHP >= 8.2
- Composer
- Laravel 11
- Docker & Docker Compose
- Jenkins (containerized)
- DigitalOcean Droplet (Ubuntu)

## Local Development

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd laravel-starter
```

2. Install dependencies:
```bash
composer install
```

3. Copy environment file:
```bash
cp .env.example .env
```

4. Generate application key:
```bash
php artisan key:generate
```

### Start the Development Server

```bash
php artisan serve
```

The application will be available at `http://127.0.0.1:8000`

### API Endpoint

**GET** `/api/hello`

Returns a JSON response with a hello world message.

#### Example Request

```bash
curl -X GET http://127.0.0.1:8000/api/hello
```

#### Example Response

```json
{
  "message": "Hello World!",
  "status": "success",
  "timestamp": "2025-01-09T11:48:07.215051Z"
}
```

## CI/CD Setup

### 1. Jenkins Setup with Docker

#### Install Docker on Host Machine

```bash
# Update system
sudo apt-get update

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
```

#### Run Jenkins with Docker Support

```bash
# Get Docker group GID
DOCKER_GID=$(getent group docker | cut -d: -f3)

# Create Jenkins with Docker CLI pre-installed
docker run -d \
  -p 8081:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.ssh:/var/jenkins_home/.ssh:ro \
  --group-add $DOCKER_GID \
  --name jenkins \
  jenkins/jenkins:lts-jdk17

# Install Docker CLI inside Jenkins container
docker exec -u root jenkins apt-get update
docker exec -u root jenkins apt-get install -y docker.io
```

#### Alternative: Custom Jenkins Image

Build custom Jenkins image with Docker CLI:

```dockerfile
FROM jenkins/jenkins:lts-jdk17

USER root

# Install Docker CLI
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

USER jenkins
```

```bash
# Build and run custom image
docker build -t jenkins-with-docker .

# Get Docker group GID
DOCKER_GID=$(getent group docker | cut -d: -f3)

docker run -d \
  -p 8081:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $DOCKER_GID \
  --name jenkins \
  jenkins-with-docker
```

### 2. SSH Key Setup

#### Generate SSH Key for Jenkins

```bash
# Generate new SSH key pair for Jenkins
ssh-keygen -t rsa -b 4096 -f ~/.ssh/jenkins_key -N "" -C "jenkins@deployment"

# Display private key for Jenkins credentials
cat ~/.ssh/jenkins_key

# Display public key for droplet
cat ~/.ssh/jenkins_key.pub
```

### 3. DigitalOcean Droplet Setup

#### Create Droplet
- Create Ubuntu 24.04 droplet on DigitalOcean
- Add your SSH public key during creation
- Note the droplet IP address

#### Install Docker on Droplet

Create and run the installation script:

```bash
#!/bin/bash

# Update system
apt-get update

# Install prerequisites
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index
apt-get update

# Install Docker
apt-get install -y docker-ce docker-ce-cli containerd.io

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Create deploy user
useradd -m -s /bin/bash deploy
usermod -aG docker deploy

# Copy SSH keys to deploy user
mkdir -p /home/deploy/.ssh
cp /root/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys

# Configure Docker to restart containers on boot
echo '{"live-restore": true}' > /etc/docker/daemon.json
systemctl restart docker

# Verify installation
docker --version
sudo -u deploy docker run hello-world

echo "Docker installation completed successfully!"
echo "Deploy user created with Docker access"
echo "Containers will restart automatically on reboot"
```

#### Copy SSH Key to Droplet

```bash
# Copy public key to droplet
ssh-copy-id -i ~/.ssh/jenkins_key.pub root@YOUR_DROPLET_IP

# Test SSH connection
ssh -i ~/.ssh/jenkins_key deploy@YOUR_DROPLET_IP "echo 'SSH connection successful'"
```

### 4. Jenkins Configuration

#### Access Jenkins
1. Open `http://localhost:8081`
2. Get initial admin password: `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`
3. Install suggested plugins
4. Create admin user

#### Configure Credentials

1. **Docker Hub Credentials**
   - Go to "Manage Jenkins" → "Manage Credentials"
   - Add "Username with password"
   - ID: `dockerhub-creds`
   - Username: Your Docker Hub username
   - Password: Your Docker Hub password/token

2. **SSH Key for Droplet**
   - Add "SSH Username with private key"
   - ID: `do-ssh-key`
   - Username: `deploy`
   - Private Key: Content of `~/.ssh/jenkins_key`

3. **Laravel App Key**
   - Add "Secret text"
   - ID: `laravel-app-key`
   - Secret: Generate with Docker command:
   ```bash
   docker run --rm -v $(pwd):/app -w /app php:8.2-fpm sh -c "apt-get update && apt-get install -y unzip libzip-dev && docker-php-ext-install zip && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && composer install && php artisan key:generate --show"
   ```

#### Configure Pipeline

1. Create new Pipeline job
2. Configure Git repository
3. Set Pipeline script from SCM
4. Update `Jenkinsfile` environment variables:
   ```groovy
   environment {
       REGISTRY = 'your-dockerhub-username'
       IMAGE_NAME = 'laravel-test'
       DOCKERHUB_CREDENTIALS_ID = 'dockerhub-creds'
       DO_SSH_KEY_ID = 'do-ssh-key'
       DROPLET_IP = 'your-droplet-ip'
       APP_KEY = credentials('laravel-app-key')
   }
   ```

### 5. Docker Configuration

#### Dockerfile
The application includes a production-ready Dockerfile:

```dockerfile
FROM php:8.2-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY . .

# Install dependencies
RUN composer install --optimize-autoloader --no-dev

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Copy Apache configuration
COPY docker/apache.conf /etc/apache2/sites-available/000-default.conf

# Expose port 80
EXPOSE 80

# Start Apache
CMD ["apache2-foreground"]
```

## Deployment Pipeline

The Jenkins pipeline automatically:

1. **Checkout** - Pulls latest code from Git
2. **Build** - Creates Docker image with Git commit SHA tag
3. **Login & Push** - Pushes image to Docker Hub
4. **Deploy** - SSH to droplet and runs new container

### Pipeline Stages

```groovy
pipeline {
    agent any
    tools {
        dockerTool 'docker-latest'
    }

    environment {
        REGISTRY = 'draft04'
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
                    def shortSha = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    sh "docker build -t ${REGISTRY}/${IMAGE_NAME}:${shortSha} ."
                    sh "docker tag ${REGISTRY}/${IMAGE_NAME}:${shortSha} ${REGISTRY}/${IMAGE_NAME}:latest"
                }
            }
        }

        stage('Login & Push') {
            steps {
                script {
                    def shortSha = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    withDockerRegistry([ credentialsId: DOCKERHUB_CREDENTIALS_ID ]) {
                        sh "docker push ${REGISTRY}/${IMAGE_NAME}:${shortSha}"
                        sh "docker push ${REGISTRY}/${IMAGE_NAME}:latest"
                    }
                }
            }
        }

        stage('Deploy to Droplet') {
            steps {
                script {
                    def shortSha = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    withCredentials([sshUserPrivateKey(credentialsId: DO_SSH_KEY_ID, keyFileVariable: 'SSH_KEY')]) {
                        sh """
                            chmod 600 \${SSH_KEY}
                            ssh -o StrictHostKeyChecking=no -i \${SSH_KEY} deploy@\${DROPLET_IP} \
                                "docker pull \${REGISTRY}/\${IMAGE_NAME}:${shortSha} && \
                                 docker stop hello || true && docker rm hello || true && \
                                 docker run -d --name hello -p 80:80 \
                                    -e APP_ENV=production \
                                    -e APP_KEY=\${APP_KEY} \
                                    -e BUILD_SHA=${shortSha} \
                                    -e BUILD_AT='\$(date)' \
                                    --restart unless-stopped \
                                    \${REGISTRY}/\${IMAGE_NAME}:${shortSha}"
                        """
                    }
                }
            }
        }
    }
}
```

## Deployment Operations

### Manual Deployment

To manually deploy a specific version:

```bash
# SSH to droplet
ssh -i ~/.ssh/jenkins_key deploy@YOUR_DROPLET_IP

# Pull specific image tag
docker pull draft04/laravel-test:COMMIT_SHA

# Stop current container
docker stop hello

# Remove current container
docker rm hello

# Run new container
docker run -d --name hello -p 80:80 \
  -e APP_ENV=production \
  -e APP_KEY=YOUR_APP_KEY \
  -e BUILD_SHA=COMMIT_SHA \
  -e BUILD_AT="$(date)" \
  --restart unless-stopped \
  draft04/laravel-test:COMMIT_SHA
```

### Rollback Instructions

#### Quick Rollback to Previous Version

```bash
# SSH to droplet
ssh -i ~/.ssh/jenkins_key deploy@YOUR_DROPLET_IP

# List available images
docker images draft04/laravel-test

# Stop current container
docker stop hello && docker rm hello

# Run previous version (replace with actual previous tag)
docker run -d --name hello -p 80:80 \
  -e APP_ENV=production \
  -e APP_KEY=YOUR_APP_KEY \
  -e BUILD_SHA=PREVIOUS_COMMIT_SHA \
  -e BUILD_AT="$(date)" \
  --restart unless-stopped \
  draft04/laravel-test:PREVIOUS_COMMIT_SHA
```

#### Rollback via Jenkins

1. Go to Jenkins job history
2. Find the previous successful build
3. Click "Replay" to redeploy that version
4. Or manually trigger build with specific Git commit

#### Emergency Rollback Script

Create this script on your droplet for quick rollbacks:

```bash
# Create rollback script
ssh -i ~/.ssh/jenkins_key deploy@YOUR_DROPLET_IP "cat > ~/rollback.sh << 'EOF'
#!/bin/bash
PREVIOUS_TAG=\$1
if [ -z \"\$PREVIOUS_TAG\" ]; then
  echo \"Usage: ./rollback.sh <previous-tag>\"
  echo \"Available tags:\"
  docker images draft04/laravel-test --format \"table {{.Tag}}\t{{.CreatedAt}}\"
  exit 1
fi

echo \"Rolling back to: \$PREVIOUS_TAG\"
docker stop hello || true
docker rm hello || true
docker run -d --name hello -p 80:80 \
  -e APP_ENV=production \
  -e APP_KEY=\$APP_KEY \
  -e BUILD_SHA=\$PREVIOUS_TAG \
  -e BUILD_AT=\"\$(date)\" \
  --restart unless-stopped \
  draft04/laravel-test:\$PREVIOUS_TAG

echo \"Rollback completed. Check: curl http://localhost/api/hello\"
EOF"

# Make script executable
ssh -i ~/.ssh/jenkins_key deploy@YOUR_DROPLET_IP "chmod +x ~/rollback.sh"
```

#### Usage:
```bash
# SSH to droplet and run rollback
ssh -i ~/.ssh/jenkins_key deploy@YOUR_DROPLET_IP "./rollback.sh abc1234"
```

### Deployment Verification

After any deployment or rollback:

```bash
# Check container status
docker ps

# Check application health
curl http://YOUR_DROPLET_IP/api/hello

# Check container logs
docker logs hello

# Check resource usage
docker stats hello --no-stream
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              DEVELOPMENT ENVIRONMENT                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────────┐  │
│  │   Developer     │    │   Git Repository │    │      Local Machine          │  │
│  │                 │───▶│   (GitHub/etc)   │    │  ┌─────────────────────────┐ │  │
│  │  Code Changes   │    │                 │    │  │    SSH Keys             │ │  │
│  │  Git Push       │    │  - Laravel App  │    │  │  ~/.ssh/jenkins_key     │ │  │
│  └─────────────────┘    │  - Dockerfile   │    │  │  ~/.ssh/jenkins_key.pub │ │  │
│                          │  - Jenkinsfile  │    │  └─────────────────────────┘ │  │
│                          └─────────────────┘    └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Git Webhook/Poll
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                CI/CD PIPELINE                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                        Jenkins Container                                    │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │ │
│  │  │   Stage 1:      │  │   Stage 2:      │  │      Stage 3:               │ │ │
│  │  │   Checkout      │─▶│   Build Image   │─▶│   Login & Push              │ │ │
│  │  │                 │  │                 │  │                             │ │ │
│  │  │ - Git clone     │  │ - docker build  │  │ - Docker Hub login          │ │ │
│  │  │ - Get commit    │  │ - Tag with SHA  │  │ - Push image:tag            │ │ │
│  │  │   SHA           │  │ - Tag latest    │  │ - Push image:latest         │ │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────────────────┘ │ │
│  │                                                           │                 │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐ │ │
│  │  │                        Stage 4: Deploy                                 │ │ │
│  │  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐ │ │ │
│  │  │  │   SSH Connect   │─▶│   Pull Image    │─▶│   Run Container         │ │ │ │
│  │  │  │                 │  │                 │  │                         │ │ │ │
│  │  │  │ - Use SSH key   │  │ - docker pull   │  │ - docker run -d         │ │ │ │
│  │  │  │ - Connect as    │  │ - Get latest    │  │ - Port 80:80            │ │ │ │
│  │  │  │   deploy user   │  │   image         │  │ - Auto restart          │ │ │ │
│  │  │  └─────────────────┘  └─────────────────┘  └─────────────────────────┘ │ │ │
│  │  └─────────────────────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
│  Docker Socket Mount: /var/run/docker.sock:/var/run/docker.sock                  │
│  Port: 8081:8080 | Group: --group-add $DOCKER_GID                               │
└─────────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ SSH Connection
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            DOCKER HUB REGISTRY                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                        draft04/laravel-test                                 │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │ │
│  │  │   Image Tags    │  │   Image Layers  │  │      Metadata               │ │ │
│  │  │                 │  │                 │  │                             │ │ │
│  │  │ - latest        │  │ - PHP 8.2       │  │ - Build timestamp           │ │ │
│  │  │ - commit-sha    │  │ - Apache        │  │ - Git commit SHA            │ │ │
│  │  │ - build-123     │  │ - Laravel app   │  │ - Environment vars          │ │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Docker Pull
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          PRODUCTION ENVIRONMENT                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                      DigitalOcean Droplet                                   │ │
│  │                         Ubuntu 24.04                                       │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │ │
│  │  │   Deploy User   │  │   Docker Engine │  │    Laravel Container        │ │ │
│  │  │                 │  │                 │  │                             │ │ │
│  │  │ - Non-root      │  │ - Auto-start    │  │ - Name: hello               │ │ │
│  │  │ - Docker access │  │ - Live restore  │  │ - Port: 80:80               │ │ │
│  │  │ - SSH keys      │  │ - Container     │  │ - Auto restart              │ │ │
│  │  │   authorized    │  │   management    │  │ - Environment vars          │ │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
│  IP: YOUR_DROPLET_IP                                                             │
│  Access: http://YOUR_DROPLET_IP/api/hello                                        │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                                DATA FLOW                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  1. Developer pushes code to Git repository                                     │
│  2. Jenkins detects changes (webhook/polling)                                   │
│  3. Jenkins pulls code and builds Docker image                                  │
│  4. Jenkins pushes image to Docker Hub registry                                 │
│  5. Jenkins SSH to droplet as deploy user                                       │
│  6. Droplet pulls latest image from Docker Hub                                  │
│  7. Droplet stops old container and starts new one                              │
│  8. Application is live and accessible via HTTP                                 │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              SECURITY LAYERS                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  • SSH Key Authentication (jenkins_key)                                         │
│  • Non-root deployment user (deploy)                                            │
│  • Docker Hub private registry access                                           │
│  • Jenkins credentials management                                               │
│  • Container isolation and restart policies                                     │
│  • Docker group permissions (--group-add $DOCKER_GID)                          │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### Jenkins Container
- **Base Image**: jenkins/jenkins:lts-jdk17
- **Docker CLI**: Installed for container operations
- **Mounted Volumes**: Docker socket, SSH keys, Jenkins home
- **Port**: 8081 (host) → 8080 (container)
- **Permissions**: Docker group access via --group-add

### DigitalOcean Droplet
- **OS**: Ubuntu 24.04
- **Users**: root (setup), deploy (runtime)
- **Docker**: Latest CE with auto-restart configuration
- **Network**: Public IP with HTTP/SSH access

### Laravel Application
- **Framework**: Laravel 11
- **Runtime**: PHP 8.2 + Apache
- **API Endpoint**: `/api/hello`
- **Container**: Auto-restart, port 80 exposed

### Security
- SSH key-based authentication
- Non-privileged deployment user
- Container isolation
- Credential management in Jenkins

## Troubleshooting

### Common Issues

1. **Docker permission denied**
   - Ensure Jenkins container has Docker socket mounted
   - Install Docker CLI inside Jenkins container

2. **SSH connection failed**
   - Verify SSH key is correctly added to Jenkins credentials
   - Ensure public key is in droplet's `~/.ssh/authorized_keys`
   - Check droplet IP address is correct

3. **Docker login failed**
   - Remove URL parameter from `withDockerRegistry` for Docker Hub
   - Verify Docker Hub credentials in Jenkins

4. **Container restart issues**
   - Ensure `--restart unless-stopped` flag is used
   - Configure Docker daemon with `live-restore: true`

### Verification Commands

```bash
# Test SSH connection
ssh -i ~/.ssh/jenkins_key deploy@YOUR_DROPLET_IP "docker ps"

# Check Jenkins logs
docker logs jenkins

# Verify Docker on droplet
ssh -i ~/.ssh/jenkins_key deploy@YOUR_DROPLET_IP "docker --version"
```

## Project Structure

- `app/Http/Controllers/HelloController.php` - Controller handling the hello endpoint
- `routes/api.php` - API routes definition
- `bootstrap/app.php` - Application bootstrap configuration
- `Dockerfile` - Production Docker configuration
- `Jenkinsfile` - CI/CD pipeline configuration
- `install-docker.sh` - Droplet setup script

## License

This project is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
