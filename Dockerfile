FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Add Ondrej PHP PPA and install all packages
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:ondrej/php -y && \
    apt-get update && \
    apt-get install -y \
        apache2 \
        mariadb-server \
        mariadb-client \
        # PHP 5.6
        php5.6 \
        php5.6-cli \
        php5.6-fpm \
        php5.6-common \
        php5.6-mysql \
        php5.6-xml \
        php5.6-mbstring \
        php5.6-gd \
        php5.6-curl \
        php5.6-zip \
        # PHP 7.4
        php7.4 \
        php7.4-cli \
        php7.4-fpm \
        php7.4-common \
        php7.4-mysql \
        php7.4-json \
        php7.4-xml \
        php7.4-mbstring \
        php7.4-gd \
        php7.4-curl \
        php7.4-zip \
        # PHP 8.3
        php8.3 \
        php8.3-cli \
        php8.3-fpm \
        php8.3-common \
        php8.3-mysql \
        php8.3-xml \
        php8.3-mbstring \
        php8.3-gd \
        php8.3-curl \
        php8.3-zip \
        # Tools
        supervisor \
        openssh-server \
        wget \
        unzip \
        vim \
        nano \
        htop \
        screen \
        net-tools \
        curl \
        netcat-openbsd && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure PHP-FPM to listen on different ports
RUN sed -i 's|listen = /run/php/php5.6-fpm.sock|listen = 127.0.0.1:9056|g' /etc/php/5.6/fpm/pool.d/www.conf && \
    sed -i 's|listen = /run/php/php7.4-fpm.sock|listen = 127.0.0.1:9074|g' /etc/php/7.4/fpm/pool.d/www.conf && \
    sed -i 's|listen = /run/php/php8.3-fpm.sock|listen = 127.0.0.1:9083|g' /etc/php/8.3/fpm/pool.d/www.conf

# Enable Apache modules
RUN a2dismod mpm_event && \
    a2enmod mpm_prefork \
        ssl \
        rewrite \
        headers \
        proxy \
        proxy_fcgi

# Configure SSH
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Download and install phpMyAdmin
RUN wget -q https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip -O /tmp/phpmyadmin.zip && \
    unzip -q /tmp/phpmyadmin.zip -d /tmp && \
    mkdir -p /opt/phpmyadmin && \
    mv /tmp/phpMyAdmin-5.2.1-all-languages/* /opt/phpmyadmin/ && \
    rm -rf /tmp/phpmyadmin.zip /tmp/phpMyAdmin-5.2.1-all-languages && \
    chown -R www-data:www-data /opt/phpmyadmin

# Create phpMyAdmin config
RUN echo "<?php" > /opt/phpmyadmin/config.inc.php && \
    echo "\$cfg['blowfish_secret'] = '$(openssl rand -base64 32)';" >> /opt/phpmyadmin/config.inc.php && \
    echo "\$i = 0;" >> /opt/phpmyadmin/config.inc.php && \
    echo "\$i++;" >> /opt/phpmyadmin/config.inc.php && \
    echo "\$cfg['Servers'][\$i]['auth_type'] = 'cookie';" >> /opt/phpmyadmin/config.inc.php && \
    echo "\$cfg['Servers'][\$i]['host'] = 'localhost';" >> /opt/phpmyadmin/config.inc.php && \
    echo "\$cfg['Servers'][\$i]['compress'] = false;" >> /opt/phpmyadmin/config.inc.php && \
    echo "\$cfg['Servers'][\$i]['AllowNoPassword'] = false;" >> /opt/phpmyadmin/config.inc.php

# Download and install TinyFileManager
RUN mkdir -p /opt/filemanager && \
    wget -q https://raw.githubusercontent.com/gridphp/tinyfilemanager/master/tinyfilemanager.php -O /opt/filemanager/index.php && \
    chown -R www-data:www-data /opt/filemanager

# Generate self-signed SSL certificate
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/apache-selfsigned.key \
    -out /etc/ssl/certs/apache-selfsigned.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Copy scripts
COPY scripts/startup.sh /usr/local/bin/startup.sh
COPY scripts/php-switch.sh /usr/local/bin/php-switch

# Make scripts executable
RUN chmod +x /usr/local/bin/startup.sh /usr/local/bin/php-switch

# Create necessary directories
RUN mkdir -p /var/www/html \
    /var/lib/mysql \
    /run/php \
    /var/log/lamp

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html && \
    chown -R mysql:mysql /var/lib/mysql

# Expose ports
EXPOSE 22 80 443 3306

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Start services
CMD ["/usr/local/bin/startup.sh"]
