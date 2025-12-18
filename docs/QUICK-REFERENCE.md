# Quick Reference Card

## Container Management

```bash
# Start container
docker compose up -d

# Stop container
docker compose stop

# Restart container
docker compose restart

# View logs
docker compose logs -f

# Stop and remove
docker compose down

# Rebuild
docker compose up -d --build

# View container status
docker compose ps
```

## SSH Access

```bash
# Connect with password
ssh -p 2222 root@localhost

# Connect with SSH key
ssh -i ~/.ssh/lamp-key -p 2222 root@localhost

# Copy files to container
scp -P 2222 file.txt root@localhost:/var/www/html/

# Copy files from container
scp -P 2222 root@localhost:/var/www/html/file.txt ./

# Execute single command
ssh -p 2222 root@localhost "command"
```

## PHP Version Switching

```bash
# SSH into container
ssh -p 2222 root@localhost

# Check current version
cd /var/www/html/your-app
php-switch

# Switch to PHP 5.6
php-switch 5.6

# Switch to PHP 7.4
php-switch 7.4

# Switch to PHP 8.3
php-switch 8.3

# Test PHP-FPM services
php-switch --test

# Show help
php-switch --help
```

## File Management

```bash
# Access from host
cd www/

# Access from container
ssh -p 2222 root@localhost
cd /var/www/html/

# Or use symlink inside container
cd ~/html

# Set permissions
docker exec lamp-dev chown -R www-data:www-data /var/www/html
docker exec lamp-dev chmod -R 755 /var/www/html
```

## Database Management

```bash
# Connect to MySQL
ssh -p 2222 root@localhost
mysql -u root -p

# Create database
mysql -u root -p -e "CREATE DATABASE newdb;"

# Import SQL file
mysql -u root -p dbname < backup.sql

# Export database
mysqldump -u root -p dbname > backup.sql

# Export all databases
mysqldump -u root -p --all-databases > all-databases.sql

# From host machine
docker exec lamp-dev mysqldump -u root -pPASSWORD dbname > backup.sql
docker exec -i lamp-dev mysql -u root -pPASSWORD dbname < backup.sql
```

## Service Management

```bash
# SSH into container
ssh -p 2222 root@localhost

# View all services
supervisorctl status

# Restart Apache
supervisorctl restart apache2

# Restart MySQL
supervisorctl restart mysqld

# Restart PHP-FPM
supervisorctl restart php-fpm-5.6
supervisorctl restart php-fpm-7.4
supervisorctl restart php-fpm-8.3

# Restart all services
supervisorctl restart all

# Stop a service
supervisorctl stop apache2

# Start a service
supervisorctl start apache2

# View service logs
supervisorctl tail -f apache2
supervisorctl tail -f php-fpm-8.3
```

## Log Files

```bash
# From host machine
tail -f logs/apache-error.log
tail -f logs/apache-access.log
tail -f logs/php-5.6.log
tail -f logs/php-7.4.log
tail -f logs/php-8.3.log
tail -f logs/mysql.log

# From container
ssh -p 2222 root@localhost
tail -f /var/log/lamp/apache-error.log
tail -f /var/log/lamp/php-7.4.log

# Search logs
grep "error" logs/apache-error.log
grep "Fatal" logs/php-8.3.log

# View last 100 lines
tail -100 logs/apache-error.log
```

## Access URLs

| Service | URL |
|---------|-----|
| Main site (HTTP) | http://localhost |
| Main site (HTTPS) | https://localhost |
| phpMyAdmin | http://localhost/phpmyadmin |
| File Manager | http://localhost/filemanager |
| SSH | ssh -p 2222 root@localhost |

## PHP-FPM Ports

| PHP Version | Port |
|-------------|------|
| PHP 5.6 | 9056 |
| PHP 7.4 | 9074 |
| PHP 8.3 | 9083 |

## Configuration Files

| File | Location | Mount Type | Purpose |
|------|----------|------------|---------|
| Environment | `.env` | Host only | Ports, passwords, PHP settings |
| Apache Core | `conf/apache2/apache2.conf` | Read-only | Main Apache config |
| HTTP Virtual Host | `conf/apache2/vhost.conf` | Read-only | HTTP site config |
| HTTPS Virtual Host | `conf/apache2/ssl-vhost.conf` | Read-only | HTTPS site config |
| Security | `conf/apache2/security.conf` | Read-only | Security headers |
| PHP 5.6 | `conf/php/php-5.6.ini` | Read-write | PHP 5.6 settings (modified by startup.sh) |
| PHP 7.4 | `conf/php/php-7.4.ini` | Read-write | PHP 7.4 settings (modified by startup.sh) |
| PHP 8.3 | `conf/php/php-8.3.ini` | Read-write | PHP 8.3 settings (modified by startup.sh) |
| MySQL | `conf/mysql/my.cnf` | Read-only | MySQL settings |
| SSH Keys | `conf/ssh/authorized_keys` | Read-only | SSH public keys |

**Note:** PHP ini files are read-write to allow startup.sh to apply environment variables from .env

## Common Tasks

### Install WordPress

```bash
ssh -p 2222 root@localhost
cd /var/www/html
mkdir wordpress && cd wordpress
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* . && rm -rf wordpress latest.tar.gz
php-switch 7.4
chown -R www-data:www-data .
```

### Install Laravel

```bash
ssh -p 2222 root@localhost
cd /var/www/html
composer create-project laravel/laravel myapp
cd myapp
php-switch 8.3
chown -R www-data:www-data .
chmod -R 775 storage bootstrap/cache
```

### Create MySQL User

```bash
ssh -p 2222 root@localhost
mysql -u root -p
```

```sql
CREATE DATABASE myapp;
CREATE USER 'myapp_user'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON myapp.* TO 'myapp_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### Backup Database

```bash
# From host
docker exec lamp-dev mysqldump -u root -pROOT_PASS dbname > backup-$(date +%Y%m%d).sql

# From container
ssh -p 2222 root@localhost
mysqldump -u root -p dbname > /var/www/html/backup.sql
```

### Restore Database

```bash
# From host
docker exec -i lamp-dev mysql -u root -pROOT_PASS dbname < backup.sql

# From container
ssh -p 2222 root@localhost
mysql -u root -p dbname < /var/www/html/backup.sql
```

### Check Service Status

```bash
# Quick check
docker compose ps

# Detailed check
docker exec lamp-dev supervisorctl status

# Check specific service
docker exec lamp-dev supervisorctl status apache2
docker exec lamp-dev supervisorctl status mysqld

# Check all PHP-FPM versions
docker exec lamp-dev supervisorctl status | grep php-fpm
```

### Update Configuration

```bash
# 1. Edit config file on host
vim conf/php/php-7.4.ini

# 2. Restart affected service
docker exec lamp-dev supervisorctl restart php-fpm-7.4

# Or restart entire container
docker compose restart
```

### Test PHP-FPM Connectivity

```bash
# From inside container
ssh -p 2222 root@localhost
php-switch --test

# Manual test
nc -zv 127.0.0.1 9056  # PHP 5.6
nc -zv 127.0.0.1 9074  # PHP 7.4
nc -zv 127.0.0.1 9083  # PHP 8.3
```

## Troubleshooting

### Service Not Starting

```bash
# Check status
docker exec lamp-dev supervisorctl status

# View service logs
docker exec lamp-dev supervisorctl tail -f apache2
docker exec lamp-dev supervisorctl tail -f mysqld

# Restart service
docker exec lamp-dev supervisorctl restart apache2

# Check container logs
docker compose logs lamp
```

### Permission Issues

```bash
# Fix web directory permissions
docker exec lamp-dev chown -R www-data:www-data /var/www/html
docker exec lamp-dev chmod -R 755 /var/www/html

# Fix specific app
docker exec lamp-dev chown -R www-data:www-data /var/www/html/myapp
```

### PHP Not Working

```bash
# Check PHP-FPM status
docker exec lamp-dev supervisorctl status | grep php-fpm

# Test PHP-FPM connectivity
ssh -p 2222 root@localhost
php-switch --test

# Check PHP error log
tail -f logs/php-7.4.log

# Restart PHP-FPM
docker exec lamp-dev supervisorctl restart php-fpm-7.4
```

### MySQL Connection Issues

```bash
# Check if MySQL is running
docker exec lamp-dev supervisorctl status mysqld

# Test MySQL connection
docker exec lamp-dev mysql -u root -p

# Check MySQL log
tail -f logs/mysql.log

# Restart MySQL
docker exec lamp-dev supervisorctl restart mysqld
```

### Apache Configuration Error

```bash
# Test Apache configuration
docker exec lamp-dev apache2ctl configtest

# Check Apache error log
tail -f logs/apache-error.log

# Restart Apache
docker exec lamp-dev supervisorctl restart apache2
```

### Docker Compose Issues

```bash
# Check Docker Compose version
docker compose version

# Should be v2.x or higher
# If not, upgrade:
sudo apt-get install docker-compose-plugin

# Rebuild from scratch
docker compose down
docker compose build --no-cache
docker compose up -d
```

## Emergency Commands

```bash
# Force stop everything
docker compose down --remove-orphans

# Nuclear option (removes volumes)
docker compose down -v

# Rebuild from scratch
docker compose down
rm -rf mysql/*
docker compose build --no-cache
docker compose up -d

# View real-time container logs
docker logs -f lamp-dev

# Enter container shell
docker exec -it lamp-dev /bin/bash
```

## Security Checklist

- [ ] Change ROOT_PASSWORD in .env
- [ ] Change MySQL passwords in .env
- [ ] Add SSH public keys to authorized_keys
- [ ] Change TinyFileManager password (admin/admin@123)
- [ ] Review security.conf settings
- [ ] Set display_errors = Off in production PHP configs
- [ ] Enable HTTPS in production
- [ ] Configure firewall rules
- [ ] Regular database backups
- [ ] Keep Docker images updated

## Performance Tuning

```bash
# Edit PHP memory limit
vim conf/php/php-8.3.ini
# Change: memory_limit = 1024M

# Edit MySQL buffer pool
vim conf/mysql/my.cnf
# Change: innodb_buffer_pool_size = 512M

# Restart services
docker compose restart

# Monitor resource usage
docker stats lamp-dev
```

## Environment Variables Reference

```bash
# Container
CONTAINER_NAME=lamp-dev

# Ports
HTTP_PORT=80
HTTPS_PORT=443
SSH_PORT=2222

# SSH
ROOT_PASSWORD=changeme

# MySQL
MYSQL_ROOT_PASSWORD=rootpass
MYSQL_DATABASE=mydb
MYSQL_USER=dbuser
MYSQL_PASSWORD=dbpass

# PHP Settings
PHP_MEMORY_LIMIT=512M
PHP_MAX_EXECUTION_TIME=300
PHP_UPLOAD_MAX_FILESIZE=128M
PHP_POST_MAX_SIZE=128M
```
