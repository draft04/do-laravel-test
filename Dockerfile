# Stage 1: Builder
FROM php:8.2-fpm AS builder
WORKDIR /var/www/html

# Install dependencies
RUN apt-get update && apt-get install -y \
    libzip-dev \
    unzip \
    curl
RUN docker-php-ext-install pdo pdo_mysql zip

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Copy app files
COPY . .

# Install dependencies
RUN composer update --no-dev --optimize-autoloader

# Stage 2: Production
FROM php:8.2-fpm AS production
WORKDIR /var/www/html

# Install nginx
RUN apt-get update && apt-get install -y nginx

# Create non-root user
RUN useradd -ms /bin/bash/ appuser

# Copy app files from builder
COPY --from=builder /var/www/html .

# Copy nginx config
COPY docker/nginx.conf /etc/nginx/sites-enabled/default

# Set permissions
RUN chown -R appuser:appuser /var/www/html/storage /var/www/html/bootstrap/cache

# Expose port
EXPOSE 80

COPY docker/entrypoint.sh /entrypoint.sh
CMD ["/entrypoint.sh"]

HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl --fail http://localhost/api/hello || exit 1
