#!/bin/bash
set -e

echo "========================================="
echo "Starting LAMP Stack Initialization"
echo "========================================="

# Set root password for SSH
if [ -n "$ROOT_PASSWORD" ]; then
    echo "root:$ROOT_PASSWORD" | chpasswd
    echo "✓ Root password configured"
fi

# Ensure SSH authorized_keys has correct permissions
if [ -f /root/.ssh/authorized_keys ]; then
    chmod 600 /root/.ssh/authorized_keys
    chown root:root /root/.ssh/authorized_keys
    echo "✓ SSH keys configured"
fi

# Update PHP configuration from environment variables
for VERSION in 5.6 7.4 8.3; do
    PHP_INI="/etc/php/${VERSION}/fpm/php.ini"
    if [ -f "$PHP_INI" ]; then
        sed "s/^memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT}/" "$PHP_INI" > /tmp/php.ini.tmp
        cat /tmp/php.ini.tmp > "$PHP_INI"
        sed "s/^max_execution_time = .*/max_execution_time = ${PHP_MAX_EXECUTION_TIME}/" "$PHP_INI" > /tmp/php.ini.tmp
        cat /tmp/php.ini.tmp > "$PHP_INI"
        sed "s/^upload_max_filesize = .*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/" "$PHP_INI" > /tmp/php.ini.tmp
        cat /tmp/php.ini.tmp > "$PHP_INI"
        sed "s/^post_max_size = .*/post_max_size = ${PHP_POST_MAX_SIZE}/" "$PHP_INI" > /tmp/php.ini.tmp
        cat /tmp/php.ini.tmp > "$PHP_INI"
        rm -f /tmp/php.ini.tmp
        echo "✓ PHP ${VERSION} configuration updated"
    fi
done

# Initialize MySQL if needed
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo ""
    echo "========================================="
    echo "Initializing MySQL Database"
    echo "========================================="
    
    # Initialize database
    mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
    echo "✓ MySQL database initialized"
    
    # Start MySQL temporarily
    mysqld_safe --datadir='/var/lib/mysql' &
    MYSQLD_PID=$!
    
    # Wait for MySQL to be ready
    echo "Waiting for MySQL to start..."
    for i in {1..30}; do
        if mysqladmin ping --silent 2>/dev/null; then
            echo "✓ MySQL is ready"
            break
        fi
        sleep 2
        if [ $i -eq 30 ]; then
            echo "ERROR: MySQL failed to start"
            exit 1
        fi
    done
    
    # Setup MySQL users and database
    echo "Creating database and users..."
    mysql -u root <<-EOSQL
        -- Secure the installation
        DELETE FROM mysql.user WHERE User='';
        DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
        DROP DATABASE IF EXISTS test;
        DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
        
        -- Set root password
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
        
        -- Create database
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        
        -- Create user
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
        
        -- Grant privileges
        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'localhost';
        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
        
        -- Flush privileges
        FLUSH PRIVILEGES;
EOSQL
    
    echo "✓ Database '${MYSQL_DATABASE}' created"
    echo "✓ User '${MYSQL_USER}' created with full privileges"
    
    # Stop temporary MySQL instance
    echo "Stopping temporary MySQL instance..."
    mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown
    wait $MYSQLD_PID 2>/dev/null || true
    
    # Kill any remaining processes
    pkill -9 mysqld 2>/dev/null || true
    sleep 2
    
    echo "✓ MySQL initialization complete"
else
    echo "✓ MySQL already initialized"
fi

# Create log directories and files
echo ""
echo "========================================="
echo "Setting up logging"
echo "========================================="

mkdir -p /var/log/lamp
touch /var/log/lamp/apache-access.log
touch /var/log/lamp/apache-error.log
touch /var/log/lamp/php-5.6.log
touch /var/log/lamp/php-7.4.log
touch /var/log/lamp/php-8.3.log
touch /var/log/lamp/mysql.log

chown -R www-data:www-data /var/log/lamp/apache-*.log
chown -R www-data:www-data /var/log/lamp/php-*.log
chown -R mysql:mysql /var/log/lamp/mysql.log

echo "✓ Log files created"

# Configure PHP-FPM error logs
sed -i "s|^error_log = .*|error_log = /var/log/lamp/php-5.6.log|" /etc/php/5.6/fpm/php-fpm.conf
sed -i "s|^error_log = .*|error_log = /var/log/lamp/php-7.4.log|" /etc/php/7.4/fpm/php-fpm.conf
sed -i "s|^error_log = .*|error_log = /var/log/lamp/php-8.3.log|" /etc/php/8.3/fpm/php-fpm.conf

echo "✓ PHP-FPM logging configured"

# Install phpMyAdmin if not present
if [ ! -d "/var/www/html/phpmyadmin" ] && [ -d "/opt/phpmyadmin" ]; then
    echo ""
    echo "========================================="
    echo "Installing phpMyAdmin"
    echo "========================================="
    cp -r /opt/phpmyadmin /var/www/html/phpmyadmin
    chown -R www-data:www-data /var/www/html/phpmyadmin
    echo "✓ phpMyAdmin installed at /phpmyadmin"
fi

# Install TinyFileManager if not present
if [ ! -d "/var/www/html/filemanager" ] && [ -d "/opt/filemanager" ]; then
    echo ""
    echo "========================================="
    echo "Installing TinyFileManager"
    echo "========================================="
    cp -r /opt/filemanager /var/www/html/filemanager
    chown -R www-data:www-data /var/www/html/filemanager
    echo "✓ TinyFileManager installed at /filemanager"
fi

# Create default index.php if not exists
if [ ! -f "/var/www/html/index.php" ]; then
    cat > /var/www/html/index.php << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>LAMP Stack - Multi-PHP Environment</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .info { background: #e3f2fd; padding: 15px; border-radius: 4px; margin: 20px 0; }
        .links { margin-top: 20px; }
        .links a { display: inline-block; margin: 10px 10px 10px 0; padding: 10px 20px; background: #2196F3; color: white; text-decoration: none; border-radius: 4px; }
        .links a:hover { background: #1976D2; }
        .version { color: #4CAF50; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 LAMP Stack - Multi-PHP Environment</h1>
        <div class="info">
            <p>Your multi-PHP LAMP stack is running successfully!</p>
            <p>Current PHP Version: <span class="version"><?php echo PHP_VERSION; ?></span></p>
        </div>
        
        <h2>Available Tools</h2>
        <div class="links">
            <a href="/phpmyadmin" target="_blank">📊 phpMyAdmin</a>
            <a href="/filemanager" target="_blank">📁 File Manager</a>
        </div>
        
        <h2>PHP Version Switching</h2>
        <p>To switch PHP version for any directory, SSH into the container and run:</p>
        <pre style="background: #f5f5f5; padding: 15px; border-radius: 4px;">php-switch [5.6|7.4|8.3]</pre>
        
        <h2>Quick Info</h2>
        <pre style="background: #f5f5f5; padding: 15px; border-radius: 4px; font-size: 12px;">
<?php phpinfo(); ?>
        </pre>
    </div>
</body>
</html>
EOF
    chown www-data:www-data /var/www/html/index.php
    echo "✓ Default index.php created"
fi

# Set proper permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Create symlink for convenience
ln -sf /var/www/html /root/html 2>/dev/null || true

# Create supervisord configuration
echo ""
echo "========================================="
echo "Configuring Service Management"
echo "========================================="

cat > /etc/supervisor/conf.d/services.conf << 'EOF'
[supervisord]
nodaemon=true
user=root
logfile=/var/log/lamp/supervisord.log
pidfile=/var/run/supervisord.pid

[program:mysqld]
command=/usr/bin/mysqld_safe --datadir='/var/lib/mysql'
user=mysql
autostart=true
autorestart=true
stdout_logfile=/var/log/lamp/mysql.log
stderr_logfile=/var/log/lamp/mysql.log
priority=1

[program:php-fpm-5.6]
command=/usr/sbin/php-fpm5.6 --nodaemonize --fpm-config /etc/php/5.6/fpm/php-fpm.conf
autostart=true
autorestart=true
stdout_logfile=/var/log/lamp/php-5.6.log
stderr_logfile=/var/log/lamp/php-5.6.log
priority=2

[program:php-fpm-7.4]
command=/usr/sbin/php-fpm7.4 --nodaemonize --fpm-config /etc/php/7.4/fpm/php-fpm.conf
autostart=true
autorestart=true
stdout_logfile=/var/log/lamp/php-7.4.log
stderr_logfile=/var/log/lamp/php-7.4.log
priority=2

[program:php-fpm-8.3]
command=/usr/sbin/php-fpm8.3 --nodaemonize --fpm-config /etc/php/8.3/fpm/php-fpm.conf
autostart=true
autorestart=true
stdout_logfile=/var/log/lamp/php-8.3.log
stderr_logfile=/var/log/lamp/php-8.3.log
priority=2

[program:apache2]
command=/usr/sbin/apache2ctl -D FOREGROUND
autostart=true
autorestart=true
stdout_logfile=/var/log/lamp/apache-access.log
stderr_logfile=/var/log/lamp/apache-error.log
priority=3

[program:sshd]
command=/usr/sbin/sshd -D
autostart=true
autorestart=true
stdout_logfile=/var/log/lamp/sshd.log
stderr_logfile=/var/log/lamp/sshd.log
priority=4
EOF

echo "✓ Supervisor configuration created"

# Enable Apache sites
a2ensite 000-default > /dev/null 2>&1 || true
a2ensite default-ssl > /dev/null 2>&1 || true
a2enconf security > /dev/null 2>&1 || true

# Create necessary run directories
mkdir -p /run/sshd /run/mysqld /run/php
chown mysql:mysql /run/mysqld

echo ""
echo "========================================="
echo "🎉 LAMP Stack Ready!"
echo "========================================="
echo "Services starting:"
echo "  ✓ MySQL/MariaDB"
echo "  ✓ PHP-FPM 5.6 (port 9056)"
echo "  ✓ PHP-FPM 7.4 (port 9074)"
echo "  ✓ PHP-FPM 8.3 (port 9083)"
echo "  ✓ Apache Web Server"
echo "  ✓ SSH Server"
echo ""
echo "Access URLs:"
echo "  → Web: http://localhost"
echo "  → HTTPS: https://localhost"
echo "  → phpMyAdmin: http://localhost/phpmyadmin"
echo "  → File Manager: http://localhost/filemanager"
echo "  → SSH: ssh -p 2222 root@localhost"
echo "========================================="
echo ""

# Start supervisord
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
