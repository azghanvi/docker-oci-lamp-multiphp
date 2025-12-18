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
<?php
// Handle phpinfo page
if (isset($_GET['info']) && $_GET['info'] === 'phpinfo') {
    phpinfo();
    exit;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LAMP Stack</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
</head>
<body class="bg-slate-900 min-h-screen text-gray-100">
    <div class="container mx-auto px-6 py-12 max-w-6xl">
        
        <!-- Header with Status -->
        <div class="mb-12 flex items-start justify-between gap-6 flex-wrap">
            <div>
                <div class="flex items-center gap-3 mb-3">
                    <div class="w-10 h-10 bg-gradient-to-br from-blue-500 to-cyan-500 rounded-lg flex items-center justify-center">
                        <i class="fas fa-server text-white text-lg"></i>
                    </div>
                    <h1 class="text-3xl font-semibold text-white">LAMP Stack</h1>
                </div>
                <p class="text-gray-400 ml-13">Multi-PHP Development Environment</p>
            </div>
            
            <!-- Status -->
            <div class="flex items-center gap-4">
                <div class="flex items-center gap-2 bg-slate-800 border border-slate-700 px-4 py-2 rounded-lg">
                    <div class="w-2 h-2 bg-emerald-400 rounded-full"></div>
                    <span class="text-sm text-gray-400">Online</span>
                </div>
                <div class="flex items-center gap-2 bg-slate-800 border border-slate-700 px-4 py-2 rounded-lg">
                    <i class="fab fa-php text-indigo-400"></i>
                    <span class="text-gray-400 text-sm">PHP</span>
                    <span class="font-semibold text-white"><?php echo PHP_VERSION; ?></span>
                </div>
            </div>
        </div>

        <!-- Tools Section -->
        <div class="mb-8">
            <h2 class="text-xl font-medium text-white mb-6 flex items-center gap-2">
                <i class="fas fa-tools text-cyan-400"></i>
                Available Tools
            </h2>
            <div class="grid md:grid-cols-3 gap-5">
                <a href="/phpmyadmin" target="_blank" class="group bg-slate-800 border border-slate-700 rounded-2xl p-6 hover:border-blue-500/50 hover:shadow-lg hover:shadow-blue-500/10 transition-all">
                    <div class="w-12 h-12 bg-blue-500/20 rounded-xl flex items-center justify-center mb-4 group-hover:bg-blue-500/30 transition-colors">
                        <i class="fas fa-database text-blue-400 text-xl"></i>
                    </div>
                    <div class="text-white font-medium mb-1">phpMyAdmin</div>
                    <div class="text-sm text-gray-400">Manage MySQL databases</div>
                </a>

                <a href="/filemanager" target="_blank" class="group bg-slate-800 border border-slate-700 rounded-2xl p-6 hover:border-purple-500/50 hover:shadow-lg hover:shadow-purple-500/10 transition-all">
                    <div class="w-12 h-12 bg-purple-500/20 rounded-xl flex items-center justify-center mb-4 group-hover:bg-purple-500/30 transition-colors">
                        <i class="fas fa-folder-open text-purple-400 text-xl"></i>
                    </div>
                    <div class="text-white font-medium mb-1">File Manager</div>
                    <div class="text-sm text-gray-400">Browse and edit files</div>
                </a>

                <a href="?info=phpinfo" target="_blank" class="group bg-slate-800 border border-slate-700 rounded-2xl p-6 hover:border-cyan-500/50 hover:shadow-lg hover:shadow-cyan-500/10 transition-all">
                    <div class="w-12 h-12 bg-cyan-500/20 rounded-xl flex items-center justify-center mb-4 group-hover:bg-cyan-500/30 transition-colors">
                        <i class="fas fa-circle-info text-cyan-400 text-xl"></i>
                    </div>
                    <div class="text-white font-medium mb-1">PHP Info</div>
                    <div class="text-sm text-gray-400">System configuration</div>
                </a>
            </div>
        </div>

        <!-- PHP Version Switching Card -->
        <div class="bg-slate-800 border border-slate-700 rounded-2xl p-6">
            <h2 class="text-xl font-medium text-white mb-5 flex items-center gap-2">
                <i class="fas fa-code-branch text-indigo-400"></i>
                PHP Version Switching
            </h2>
            <p class="text-gray-400 text-sm mb-4">Switch PHP version for any directory via SSH</p>
            <div class="bg-slate-900 border border-slate-700 rounded-xl px-4 py-3 mb-5 font-mono">
                <span class="text-gray-500">$</span>
                <span class="text-emerald-400 ml-2">php-switch</span>
                <span class="text-cyan-400 ml-2">[5.6|7.4|8.3]</span>
            </div>
            <div class="grid grid-cols-3 gap-4">
                <div class="bg-slate-900 border border-slate-700 rounded-xl px-4 py-3">
                    <div class="flex items-center gap-2 mb-2">
                        <i class="fas fa-shield-halved text-orange-400 text-sm"></i>
                        <div class="text-xs text-gray-500">Legacy</div>
                    </div>
                    <div class="text-white font-medium">PHP 5.6</div>
                </div>
                <div class="bg-slate-900 border border-slate-700 rounded-xl px-4 py-3">
                    <div class="flex items-center gap-2 mb-2">
                        <i class="fas fa-check-circle text-blue-400 text-sm"></i>
                        <div class="text-xs text-gray-500">Stable</div>
                    </div>
                    <div class="text-white font-medium">PHP 7.4</div>
                </div>
                <div class="bg-slate-900 border border-slate-700 rounded-xl px-4 py-3">
                    <div class="flex items-center gap-2 mb-2">
                        <i class="fas fa-star text-emerald-400 text-sm"></i>
                        <div class="text-xs text-gray-500">Latest</div>
                    </div>
                    <div class="text-white font-medium">PHP 8.3</div>
                </div>
            </div>
        </div>

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
