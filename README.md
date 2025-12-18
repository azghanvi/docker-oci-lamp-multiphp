# Multi-PHP LAMP Stack Docker Container

A comprehensive LAMP stack supporting multiple PHP versions (5.6, 7.4, 8.3) with easy per-directory PHP version switching.

## 🚀 Features

- **Multi-PHP Support**: PHP 5.6, 7.4, and 8.3 running simultaneously
- **Easy PHP Switching**: One command to switch PHP versions per directory
- **Full LAMP Stack**: Apache 2.4, MariaDB 10.x, PHP-FPM
- **Management Tools**: phpMyAdmin, TinyFileManager
- **SSH Access**: Password and key-based authentication
- **Persistent Storage**: MySQL data, web files, and logs survive restarts
- **External Configuration**: All configs editable from host machine
- **Development Tools**: vim, htop, screen, wget, unzip, net-tools

## 📋 Prerequisites

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.x or higher (for `${VAR:-default}` syntax support)
- **Basic command line knowledge**
- **Ports available**: 80, 443, 2222 (or customize in .env)

**Check your versions:**
```bash
docker --version
docker compose version  # Note: "compose" not "docker-compose"
```

**Upgrade if needed:**
```bash
# Install Docker Compose V2 plugin
sudo apt-get update
sudo apt-get install docker-compose-plugin
```

---

## 📁 Directory Structure

```
project/
├── Dockerfile                          # Container build instructions
├── docker-compose.yaml                 # Container orchestration
├── .env                                # Environment variables (passwords, ports)
│
├── conf/                               # Configuration files (mounted as volumes)
│   ├── apache2/
│   │   ├── apache2.conf               # Core Apache configuration
│   │   ├── vhost.conf                 # HTTP virtual host
│   │   ├── ssl-vhost.conf             # HTTPS virtual host
│   │   └── security.conf              # Security headers and settings
│   ├── php/
│   │   ├── php-5.6.ini                # PHP 5.6 configuration
│   │   ├── php-7.4.ini                # PHP 7.4 configuration
│   │   └── php-8.3.ini                # PHP 8.3 configuration
│   ├── mysql/
│   │   └── my.cnf                     # MySQL/MariaDB configuration
│   └── ssh/
│       └── authorized_keys            # SSH public keys for authentication
│
├── scripts/
│   ├── startup.sh                      # Container startup script
│   └── php-switch.sh                   # PHP version switcher script
│
├── www/                                # Web root (your applications go here)
│   ├── index.php                      # Default landing page
│   ├── phpmyadmin/                    # Database management (auto-installed)
│   ├── filemanager/                   # File management (auto-installed)
│   └── [your-apps]/                   # Your applications
│
├── mysql/                              # MySQL data directory (persistent)
│   └── [database-files]               # Auto-generated on first run
│
└── logs/                               # Application logs
    ├── apache-access.log              # HTTP access logs
    ├── apache-error.log               # Apache error logs
    ├── php-5.6.log                    # PHP 5.6 errors
    ├── php-7.4.log                    # PHP 7.4 errors
    ├── php-8.3.log                    # PHP 8.3 errors
    └── mysql.log                      # MySQL errors and queries
```

---

## 🔧 Configuration Files

### Apache Configuration (`conf/apache2/`)

| File | Purpose | When to Edit |
|------|---------|--------------|
| `apache2.conf` | Core Apache settings (MPM, modules, global directives) | Change worker limits, enable/disable modules |
| `vhost.conf` | HTTP virtual host configuration | Change document root, add custom directives |
| `ssl-vhost.conf` | HTTPS virtual host configuration | Configure SSL settings, certificates |
| `security.conf` | Security headers and server identity | Harden security, hide Apache version. Note: HTTP method limiting should be added per-directory in vhost.conf if needed |

### PHP Configuration (`conf/php/`)

| File | Purpose | Settings |
|------|---------|----------|
| `php-5.6.ini` | PHP 5.6 settings | memory_limit, upload_max_filesize, error_reporting |
| `php-7.4.ini` | PHP 7.4 settings | Same as above, version-specific optimizations |
| `php-8.3.ini` | PHP 8.3 settings | Same as above, latest PHP features including JIT |

**Common settings you might change:**
- `memory_limit` - PHP memory limit per script
- `upload_max_filesize` - Maximum upload file size
- `post_max_size` - Maximum POST data size
- `max_execution_time` - Script timeout
- `error_reporting` - Error verbosity level
- `display_errors` - Show errors on screen (disable in production)

**Important Note:** PHP configuration files are mounted as read-write (not read-only) to allow the startup script to apply environment variable settings from `.env` on container start. You can edit these files directly, and changes will be applied after container restart.

### MySQL Configuration (`conf/mysql/`)

| File | Purpose | When to Edit |
|------|---------|--------------|
| `my.cnf` | MySQL/MariaDB settings | Change buffer sizes, query cache, connection limits |

### SSH Configuration (`conf/ssh/`)

| File | Purpose | Format |
|------|---------|--------|
| `authorized_keys` | SSH public keys for passwordless login | One key per line (ssh-rsa ...) |

---

## 🛠️ Scripts

### `startup.sh`
**Location**: `/startup.sh` (inside container)  
**Purpose**: Initializes and starts all services

**What it does:**
1. Initializes MySQL database on first run
2. Creates MySQL users and databases
3. Applies PHP configuration from .env variables (using temp file method for Docker volume compatibility)
4. Sets up log files and directories
5. Configures supervisord to manage all services
6. Installs phpMyAdmin and TinyFileManager if not present
7. Starts Apache, MySQL, PHP-FPM (all versions), and SSH

**When it runs:** Automatically on container start

### `php-switch.sh`
**Location**: `/usr/local/bin/php-switch` (inside container)  
**Purpose**: Switch PHP version for any directory

**Usage:**
```bash
# Check current PHP version
php-switch

# Switch to specific version
php-switch 5.6
php-switch 7.4
php-switch 8.3

# Test PHP-FPM connectivity
php-switch --test
```

**What it does:**
1. Shows current PHP version in the directory
2. Validates requested PHP version
3. Creates backup of existing .htaccess
4. Updates .htaccess while preserving existing rules
5. Adds PHP-FPM handler for the selected version

**Safe:** Preserves all existing .htaccess rules (RewriteRules, security directives, etc.) and creates timestamped backups.

---

## 🚦 Getting Started

### 1. Initial Setup

```bash
# Option A: Clone from repository
git clone <your-repo-url>
cd lamp-multiphp

# Option B: Create structure manually
mkdir lamp-stack && cd lamp-stack
mkdir -p conf/apache2 conf/php conf/mysql conf/ssh scripts www mysql logs

# Copy all configuration files (provided in this repo)
# Edit .env with your settings
```

### 2. Configure Environment Variables

Edit `.env`:
```bash
# Container settings
CONTAINER_NAME=lamp-dev

# Ports
SSH_PORT=2222
HTTP_PORT=80
HTTPS_PORT=443

# SSH Access
ROOT_PASSWORD=your-secure-password

# MySQL credentials
MYSQL_ROOT_PASSWORD=root-password
MYSQL_DATABASE=mydb
MYSQL_USER=dbuser
MYSQL_PASSWORD=dbpass

# PHP settings (applied to all versions)
PHP_MEMORY_LIMIT=512M
PHP_MAX_EXECUTION_TIME=300
PHP_UPLOAD_MAX_FILESIZE=128M
PHP_POST_MAX_SIZE=128M
```

### 3. Add SSH Key (Optional but Recommended)

```bash
# Copy your public key
cat ~/.ssh/id_rsa.pub > conf/ssh/authorized_keys

# Or create new key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/lamp-key
cat ~/.ssh/lamp-key.pub > conf/ssh/authorized_keys
```

### 4. Start Container

```bash
# Build and start (Docker Compose v2)
docker compose up -d

# Check logs
docker compose logs -f

# Verify services
docker compose ps
```

### 5. Access Your Stack

- **Web**: http://localhost (or your HTTP_PORT)
- **HTTPS**: https://localhost (or your HTTPS_PORT)
- **SSH**: `ssh -p 2222 root@localhost`
- **phpMyAdmin**: http://localhost/phpmyadmin
- **File Manager**: http://localhost/filemanager

---

## 📝 Common Tasks

### Installing a New Application

```bash
# SSH into container
ssh -p 2222 root@localhost

# Navigate to web root
cd /var/www/html

# Example: Install WordPress
mkdir wordpress && cd wordpress
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* . && rm -rf wordpress latest.tar.gz

# Set PHP version (WordPress needs PHP 7.4+)
php-switch 7.4

# Set permissions
chown -R www-data:www-data .
chmod -R 755 .
```

### Switching PHP Version for an App

```bash
# SSH into container
ssh -p 2222 root@localhost

# Navigate to app directory
cd /var/www/html/legacy-app

# Check current version
php-switch
# Output: Current PHP version: 8.3

# Switch to PHP 5.6
php-switch 5.6
# Output: ✓ PHP version switched to 5.6 in /var/www/html/legacy-app
```

### Viewing Logs

```bash
# From host machine
tail -f logs/apache-error.log
tail -f logs/php-7.4.log
tail -f logs/mysql.log

# Or inside container
ssh -p 2222 root@localhost
tail -f /var/log/lamp/apache-error.log
```

### Changing PHP Settings

```bash
# Edit PHP configuration for specific version
vim conf/php/php-7.4.ini

# Change memory limit
memory_limit = 1024M

# Restart container to apply
docker compose restart
```

### Backing Up Database

```bash
# From host machine
docker exec lamp-dev mysqldump -u root -pROOT_PASSWORD mydb > backup.sql

# Or via SSH
ssh -p 2222 root@localhost
mysqldump -u root -p mydb > /var/www/html/backup.sql
```

### Restoring Database

```bash
# From host machine
docker exec -i lamp-dev mysql -u root -pROOT_PASSWORD mydb < backup.sql

# Or via SSH
ssh -p 2222 root@localhost
mysql -u root -p mydb < /var/www/html/backup.sql
```

---

## 🔍 Troubleshooting

### Container won't start

```bash
# Check logs
docker compose logs

# Common issues:
# - Port already in use: Change ports in .env
# - Permission issues: Check file ownership
# - MySQL fails: Delete mysql/ folder and restart
```

### Docker Compose version issues

**Symptoms**: `Invalid interpolation format` or `${VAR:-default}` not working

**Solution**:
```bash
# Check version
docker compose version

# If using old docker-compose v1.x, upgrade to v2.x
sudo apt-get install docker-compose-plugin

# Use new command format
docker compose up -d  # NOT docker-compose
```

### Can't connect via SSH

```bash
# Check if SSH port is exposed
docker compose ps

# Test connection
ssh -v -p 2222 root@localhost

# Common issues:
# - Wrong port in SSH_PORT
# - authorized_keys format issue
# - Root password not set in .env
```

### PHP version not switching

```bash
# SSH into container
ssh -p 2222 root@localhost

# Check if .htaccess was created
cd /var/www/html/your-app
cat .htaccess

# Verify PHP-FPM is running
supervisorctl status | grep php-fpm

# Test PHP-FPM connectivity
php-switch --test

# Check Apache error log
tail -f /var/log/lamp/apache-error.log
```

### Application shows errors

```bash
# Check appropriate PHP log
tail -f logs/php-7.4.log

# Check Apache error log
tail -f logs/apache-error.log

# Check file permissions
ls -la www/your-app/
```

### Apache won't start

**Symptoms**: Apache service keeps restarting or fails

**Common causes:**
```bash
# Test Apache configuration
docker exec lamp-dev apache2ctl configtest

# Check for syntax errors in config files
# Common issue: directives in wrong context (e.g., <LimitExcept> outside <Directory>)

# View Apache error log
tail -f logs/apache-error.log
```

### sed errors during startup

**Symptoms**: `sed: cannot rename /etc/php/X.X/fpm/sedXXXXX: Device or resource busy`

**Solution**: This is already handled in startup.sh using temp files. If you see this error, ensure PHP ini files are **not** mounted as `:ro` (read-only) in docker-compose.yaml. They should be read-write to allow configuration updates.

---

## 🔐 Security Notes

### For Development:
- ✅ Use as-is with default settings
- ✅ SSH with password is fine for local development

### For Production:
- ⚠️ Change all default passwords in `.env`
- ⚠️ Disable password SSH, use keys only
- ⚠️ Use real SSL certificates (Let's Encrypt)
- ⚠️ Enable firewall rules
- ⚠️ Disable `display_errors` in PHP configs
- ⚠️ Change phpMyAdmin and filemanager default passwords
- ⚠️ Consider removing phpMyAdmin in production
- ⚠️ Review and customize security.conf settings
- ⚠️ Add HTTP method restrictions per-directory if needed

---

## 📊 Log Files Explained

| Log File | Contains | Use Case |
|----------|----------|----------|
| `apache-access.log` | All HTTP requests (GET, POST, etc.) | Track traffic, find popular pages |
| `apache-error.log` | Apache server errors, proxy issues | Debug 500 errors, configuration issues |
| `php-5.6.log` | PHP 5.6 code errors and warnings | Debug legacy applications |
| `php-7.4.log` | PHP 7.4 code errors and warnings | Debug mid-version applications |
| `php-8.3.log` | PHP 8.3 code errors and warnings | Debug modern applications |
| `mysql.log` | Database errors and slow queries | Debug database issues, optimize queries |

**Why separate PHP logs?**  
When running multiple PHP versions, separate logs help you immediately identify which version is causing issues without digging through mixed error messages. Each PHP-FPM instance logs to its own file, making debugging much faster.

---

## 🆘 Support

### Restart Services

```bash
# Restart entire container
docker compose restart

# Restart specific service (inside container)
ssh -p 2222 root@localhost
supervisorctl restart apache2
supervisorctl restart php-fpm-8.3
supervisorctl restart mysqld
```

### View Service Status

```bash
# Inside container
ssh -p 2222 root@localhost
supervisorctl status

# Expected output:
# apache2    RUNNING   pid 123, uptime 1:23:45
# mysqld     RUNNING   pid 124, uptime 1:23:45
# php-fpm-5.6 RUNNING  pid 125, uptime 1:23:45
# php-fpm-7.4 RUNNING  pid 126, uptime 1:23:45
# php-fpm-8.3 RUNNING  pid 127, uptime 1:23:45
# sshd       RUNNING   pid 128, uptime 1:23:45
```

### Clean Restart

```bash
# Stop container
docker compose down

# Remove MySQL data (WARNING: Deletes all databases!)
rm -rf mysql/*

# Remove logs
rm -rf logs/*

# Start fresh
docker compose up -d
```

---

## 📚 Additional Resources

- **Apache Documentation**: https://httpd.apache.org/docs/2.4/
- **PHP Documentation**: https://www.php.net/docs.php
- **MariaDB Documentation**: https://mariadb.org/documentation/
- **Docker Compose**: https://docs.docker.com/compose/
- **Ondrej PHP PPA**: https://launchpad.net/~ondrej/+archive/ubuntu/php

---

## 📄 License

This configuration is provided as-is for development purposes. Modify as needed for your use case.
