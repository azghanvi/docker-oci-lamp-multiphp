# Troubleshooting Guide

## Container Issues

### Container Won't Start

**Symptoms**: `docker-compose up -d` fails or exits immediately

**Diagnosis**:
```bash
# Check container status
docker-compose ps

# View startup logs
docker-compose logs

# Check for port conflicts
sudo lsof -i :80
sudo lsof -i :443
sudo lsof -i :2222
```

**Solutions**:

1. **Port already in use**:
   ```bash
   # Change ports in .env
   HTTP_PORT=8080
   HTTPS_PORT=8443
   SSH_PORT=2223
   
   # Restart
   docker-compose down
   docker-compose up -d
   ```

2. **Build errors**:
   ```bash
   # Rebuild from scratch
   docker-compose down
   docker-compose build --no-cache
   docker-compose up -d
   ```

3. **Permission errors**:
   ```bash
   # Fix directory permissions
   sudo chown -R $USER:$USER .
   chmod -R 755 conf/
   
   # Restart
   docker-compose restart
   ```

### Container Keeps Restarting

**Symptoms**: Container status shows "Restarting"

**Diagnosis**:
```bash
# Check logs
docker-compose logs -f

# Check which service is failing
docker exec lamp-dev supervisorctl status
```

**Solutions**:

1. **MySQL initialization failed**:
   ```bash
   # Stop and remove MySQL data
   docker-compose down
   rm -rf mysql/*
   
   # Start fresh
   docker-compose up -d
   ```

2. **Configuration file error**:
   ```bash
   # Test Apache config
   docker exec lamp-dev apache2ctl configtest
   
   # Test PHP-FPM config
   docker exec lamp-dev php-fpm8.3 -t
   docker exec lamp-dev php-fpm7.4 -t
   docker exec lamp-dev php-fpm5.6 -t
   ```

3. **Check supervisord logs**:
   ```bash
   docker exec lamp-dev cat /var/log/lamp/supervisord.log
   ```

---

## SSH Issues

### Cannot Connect via SSH

**Symptoms**: Connection refused or timeout

**Diagnosis**:
```bash
# Check if SSH port is exposed
docker-compose ps

# Check if SSH is running
docker exec lamp-dev supervisorctl status sshd

# Test from inside container
docker exec lamp-dev netstat -tlnp | grep 22
```

**Solutions**:

1. **SSH service not running**:
   ```bash
   docker exec lamp-dev supervisorctl start sshd
   ```

2. **Wrong port**:
   ```bash
   # Check your .env file
   cat .env | grep SSH_PORT
   
   # Connect with correct port
   ssh -p 2222 root@localhost
   ```

3. **Firewall blocking**:
   ```bash
   # Check firewall
   sudo ufw status
   
   # Allow SSH port
   sudo ufw allow 2222/tcp
   ```

### SSH Authentication Failed

**Symptoms**: Permission denied (publickey,password)

**Diagnosis**:
```bash
# Check authorized_keys
docker exec lamp-dev cat /root/.ssh/authorized_keys

# Check permissions
docker exec lamp-dev ls -la /root/.ssh/
```

**Solutions**:

1. **Key permission issues**:
   ```bash
   # Fix on host
   chmod 600 conf/ssh/authorized_keys
   
   # Rebuild
   docker-compose down
   docker-compose up -d
   ```

2. **Wrong key**:
   ```bash
   # Copy correct public key
   cat ~/.ssh/id_rsa.pub > conf/ssh/authorized_keys
   
   # Restart container
   docker-compose restart
   ```

3. **Use password instead**:
   ```bash
   # Ensure ROOT_PASSWORD is set in .env
   ssh -p 2222 root@localhost
   # Enter password from .env
   ```

---

## Apache / Web Server Issues

### 404 Not Found

**Symptoms**: All pages return 404

**Diagnosis**:
```bash
# Check if Apache is running
docker exec lamp-dev supervisorctl status apache2

# Check document root
docker exec lamp-dev ls -la /var/www/html/

# Check Apache error log
tail -f logs/apache-error.log
```

**Solutions**:

1. **Files not in correct location**:
   ```bash
   # Files should be in www/ directory
   ls -la www/
   
   # Check from container
   docker exec lamp-dev ls -la /var/www/html/
   ```

2. **Permission issues**:
   ```bash
   # Fix permissions
   docker exec lamp-dev chown -R www-data:www-data /var/www/html
   docker exec lamp-dev chmod -R 755 /var/www/html
   ```

3. **Restart Apache**:
   ```bash
   docker exec lamp-dev supervisorctl restart apache2
   ```

### 500 Internal Server Error

**Symptoms**: Pages return 500 error

**Diagnosis**:
```bash
# Check Apache error log
tail -f logs/apache-error.log

# Check PHP error log (for correct version)
tail -f logs/php-8.3.log
tail -f logs/php-7.4.log
tail -f logs/php-5.6.log
```

**Solutions**:

1. **PHP syntax error**:
   - Check the PHP error log for the version you're using
   - Fix syntax errors in your PHP files

2. **.htaccess error**:
   ```bash
   # Test Apache config
   docker exec lamp-dev apache2ctl configtest
   
   # Temporarily rename .htaccess
   docker exec lamp-dev mv /var/www/html/.htaccess /var/www/html/.htaccess.bak
   
   # Test if site works
   # If yes, fix .htaccess syntax
   ```

3. **PHP-FPM not responding**:
   ```bash
   # Check PHP-FPM status
   docker exec lamp-dev supervisorctl status | grep php-fpm
   
   # Restart PHP-FPM
   docker exec lamp-dev supervisorctl restart php-fpm-8.3
   ```

### PHP Not Executing (Shows Source Code)

**Symptoms**: Browser downloads .php files or shows PHP code

**Diagnosis**:
```bash
# Check if PHP-FPM is running
docker exec lamp-dev supervisorctl status | grep php-fpm

# Check Apache config
docker exec lamp-dev apache2ctl -M | grep proxy_fcgi
```

**Solutions**:

1. **PHP-FPM not running**:
   ```bash
   docker exec lamp-dev supervisorctl restart php-fpm-8.3
   ```

2. **Wrong PHP handler**:
   - Check if .htaccess exists
   - Verify PHP-FPM port is correct
   ```bash
   cat www/your-app/.htaccess
   ```

3. **Apache modules not enabled**:
   ```bash
   docker exec lamp-dev a2enmod proxy_fcgi
   docker exec lamp-dev supervisorctl restart apache2
   ```

---

## PHP Issues

### Wrong PHP Version

**Symptoms**: App requires PHP 7.4 but using 8.3

**Diagnosis**:
```bash
# SSH into container
ssh -p 2222 root@localhost

# Check current version
cd /var/www/html/your-app
php-switch
```

**Solutions**:
```bash
# Switch to correct version
php-switch 7.4

# Verify
cat .htaccess | grep proxy:fcgi
```

### PHP Memory Exhausted

**Symptoms**: Fatal error: Allowed memory size exhausted

**Diagnosis**:
```bash
# Check PHP memory limit
docker exec lamp-dev php8.3 -i | grep memory_limit
docker exec lamp-dev php7.4 -i | grep memory_limit
docker exec lamp-dev php5.6 -i | grep memory_limit
```

**Solutions**:

1. **Increase globally**:
   ```bash
   # Edit .env
   PHP_MEMORY_LIMIT=1024M
   
   # Restart
   docker-compose restart
   ```

2. **Increase per version**:
   ```bash
   # Edit specific PHP ini
   vim conf/php/php-8.3.ini
   # Change: memory_limit = 1024M
   
   # Restart PHP-FPM
   docker exec lamp-dev supervisorctl restart php-fpm-8.3
   ```

### Upload Size Too Large

**Symptoms**: File upload fails for large files

**Solutions**:
```bash
# Edit .env
PHP_UPLOAD_MAX_FILESIZE=256M
PHP_POST_MAX_SIZE=256M

# Or edit specific version
vim conf/php/php-8.3.ini
# Change:
# upload_max_filesize = 256M
# post_max_size = 256M

# Restart
docker-compose restart
```

### PHP Extensions Missing

**Symptoms**: Fatal error: Call to undefined function

**Diagnosis**:
```bash
# Check installed extensions
docker exec lamp-dev php8.3 -m
docker exec lamp-dev php7.4 -m
docker exec lamp-dev php5.6 -m
```

**Solutions**:
```bash
# Install extension (requires rebuild)
# Edit Dockerfile to add:
# php8.3-extension-name

# Rebuild
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

---

## MySQL Issues

### Cannot Connect to MySQL

**Symptoms**: Connection refused or access denied

**Diagnosis**:
```bash
# Check if MySQL is running
docker exec lamp-dev supervisorctl status mysqld

# Check MySQL log
tail -f logs/mysql.log

# Test connection
docker exec lamp-dev mysql -u root -p
```

**Solutions**:

1. **MySQL not running**:
   ```bash
   docker exec lamp-dev supervisorctl start mysqld
   ```

2. **Wrong credentials**:
   ```bash
   # Check .env file
   cat .env | grep MYSQL
   
   # Reset password
   docker exec lamp-dev mysql -u root
   ALTER USER 'root'@'localhost' IDENTIFIED BY 'new-password';
   FLUSH PRIVILEGES;
   ```

3. **MySQL initialization failed**:
   ```bash
   # Nuclear option - deletes all data!
   docker-compose down
   rm -rf mysql/*
   docker-compose up -d
   ```

### Too Many Connections

**Symptoms**: Error: Too many connections

**Solutions**:
```bash
# Edit MySQL config
vim conf/mysql/my.cnf
# Change: max_connections = 500

# Restart
docker-compose restart
```

### MySQL Crashed

**Symptoms**: MySQL won't start after unexpected shutdown

**Solutions**:
```bash
# Try to repair
docker exec lamp-dev supervisorctl stop mysqld
docker exec lamp-dev mysqld --skip-grant-tables &

# If that doesn't work, backup and reinitialize
# 1. Backup what you can
docker exec lamp-dev mysqldump --all-databases > backup.sql

# 2. Reinitialize
docker-compose down
rm -rf mysql/*
docker-compose up -d

# 3. Restore
docker exec -i lamp-dev mysql -u root -p < backup.sql
```

---

## phpMyAdmin Issues

### 404 Not Found

**Symptoms**: /phpmyadmin returns 404

**Solutions**:
```bash
# Check if phpMyAdmin exists
docker exec lamp-dev ls -la /var/www/html/phpmyadmin

# If missing, copy from template
docker exec lamp-dev cp -r /opt/phpmyadmin /var/www/html/
docker exec lamp-dev chown -R www-data:www-data /var/www/html/phpmyadmin
```

### Cannot Login

**Symptoms**: Wrong username or password

**Solutions**:
```bash
# Use MySQL credentials from .env
# Username: root or MYSQL_USER
# Password: MYSQL_ROOT_PASSWORD or MYSQL_PASSWORD

# Reset MySQL password if needed
docker exec lamp-dev mysql -u root
ALTER USER 'root'@'localhost' IDENTIFIED BY 'new-password';
FLUSH PRIVILEGES;
```

---

## Performance Issues

### Slow Response Times

**Diagnosis**:
```bash
# Check resource usage
docker stats lamp-dev

# Check MySQL slow query log
tail -f logs/mysql.log
```

**Solutions**:

1. **Increase PHP-FPM workers**:
   ```bash
   # Edit PHP-FPM pool config (requires container modification)
   # This would require rebuilding the container
   ```

2. **Optimize MySQL**:
   ```bash
   vim conf/mysql/my.cnf
   # Increase:
   # innodb_buffer_pool_size = 512M
   # max_connections = 200
   
   docker-compose restart
   ```

3. **Enable OPcache**:
   ```bash
   vim conf/php/php-8.3.ini
   # Ensure opcache is enabled
   # opcache.enable = 1
   
   docker exec lamp-dev supervisorctl restart php-fpm-8.3
   ```

### High Memory Usage

**Solutions**:
```bash
# Reduce PHP memory limit
vim conf/php/php-8.3.ini
# memory_limit = 256M

# Reduce MySQL buffer pool
vim conf/mysql/my.cnf
# innodb_buffer_pool_size = 128M

docker-compose restart
```

---

## Log Analysis

### Find Recent Errors

```bash
# Apache errors (last 50 lines)
tail -50 logs/apache-error.log

# PHP errors (last 50 lines)
tail -50 logs/php-8.3.log

# MySQL errors
tail -50 logs/mysql.log

# Search for specific error
grep "Fatal error" logs/php-8.3.log
grep "404" logs/apache-access.log
```

### Real-time Monitoring

```bash
# Watch all logs
tail -f logs/*.log

# Watch specific log
tail -f logs/apache-error.log

# Watch with grep filter
tail -f logs/apache-error.log | grep "error"
```

---

## Emergency Recovery

### Complete Reset

```bash
# Backup important files first
cp -r www/ www-backup/
docker exec lamp-dev mysqldump --all-databases > all-databases-backup.sql

# Nuclear reset
docker-compose down --remove-orphans
rm -rf mysql/*
rm -rf logs/*

# Rebuild
docker-compose build --no-cache
docker-compose up -d

# Restore data
cp -r www-backup/* www/
docker exec -i lamp-dev mysql -u root -p < all-databases-backup.sql
```

### Backup Before Troubleshooting

```bash
# Always backup before making changes
tar -czf backup-$(date +%Y%m%d-%H%M%S).tar.gz www/ mysql/ conf/ .env
```

---

## Getting Help

If none of these solutions work:

1. **Check logs thoroughly**:
   ```bash
   docker-compose logs > full-logs.txt
   ```

2. **Verify your setup**:
   ```bash
   # Check all services
   docker exec lamp-dev supervisorctl status
   
   # Test each component
   docker exec lamp-dev apache2ctl configtest
   docker exec lamp-dev php-fpm8.3 -t
   docker exec lamp-dev mysql -u root -p -e "SELECT 1"
   ```

3. **Collect debug information**:
   ```bash
   # System info
   docker --version
   docker-compose --version
   
   # Container info
   docker inspect lamp-dev
   
   # Resource usage
   docker stats --no-stream lamp-dev
   ```
