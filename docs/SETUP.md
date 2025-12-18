# Quick Setup Guide

## Prerequisites

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.x or higher (for `${VAR:-default}` syntax)
- Basic understanding of command line

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

# Verify installation
docker compose version
```

## Step-by-Step Setup

### 1. Create Project Structure

```bash
# Option A: Clone from repository (recommended)
git clone <your-repo-url>
cd lamp-multiphp

# Option B: Create structure manually
mkdir lamp-stack && cd lamp-stack

# Create subdirectories
mkdir -p conf/apache2 conf/php conf/mysql conf/ssh scripts www mysql logs

# Create placeholder files for Git
touch www/.gitkeep mysql/.gitkeep logs/.gitkeep
```

### 2. Copy Configuration Files

Copy all provided configuration files to their respective locations:

```
conf/apache2/apache2.conf
conf/apache2/vhost.conf
conf/apache2/ssl-vhost.conf
conf/apache2/security.conf
conf/php/php-5.6.ini
conf/php/php-7.4.ini
conf/php/php-8.3.ini
conf/mysql/my.cnf
conf/ssh/authorized_keys
scripts/startup.sh
scripts/php-switch.sh
Dockerfile
docker-compose.yaml
.env
.gitignore
```

**Important:** PHP configuration files (php-*.ini) are mounted as **read-write** (not read-only) to allow the startup script to apply environment variable settings from `.env` on container start.

### 3. Configure Environment Variables

Edit `.env` file:

```bash
# Change these values
CONTAINER_NAME=lamp-dev
SSH_PORT=2222
HTTP_PORT=80
HTTPS_PORT=443

# Set secure passwords
ROOT_PASSWORD=your-secure-password

# MySQL credentials
MYSQL_ROOT_PASSWORD=secure-root-password
MYSQL_DATABASE=mydb
MYSQL_USER=dbuser
MYSQL_PASSWORD=secure-db-password

# PHP settings (optional)
PHP_MEMORY_LIMIT=512M
PHP_MAX_EXECUTION_TIME=300
PHP_UPLOAD_MAX_FILESIZE=128M
PHP_POST_MAX_SIZE=128M
```

### 4. Add SSH Key (Optional but Recommended)

```bash
# If you already have an SSH key
cat ~/.ssh/id_rsa.pub > conf/ssh/authorized_keys

# Or generate a new one
ssh-keygen -t rsa -b 4096 -f ~/.ssh/lamp-key
cat ~/.ssh/lamp-key.pub > conf/ssh/authorized_keys
```

### 5. Build and Start Container

```bash
# Build the Docker image
docker compose build

# Start the container
docker compose up -d

# Check logs
docker compose logs -f
```

### 6. Verify Installation

```bash
# Check if services are running
docker compose ps

# Expected output:
# NAME        COMMAND                  SERVICE   STATUS    PORTS
# lamp-dev    "/usr/local/bin/star…"   lamp      Up        0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp, 0.0.0.0:2222->22/tcp

# Test SSH connection
ssh -p 2222 root@localhost

# Or with key
ssh -i ~/.ssh/lamp-key -p 2222 root@localhost
```

### 7. Access Services

Open your browser and visit:

- **Main site**: http://localhost
- **phpMyAdmin**: http://localhost/phpmyadmin
- **File Manager**: http://localhost/filemanager
- **HTTPS**: https://localhost (accept self-signed certificate warning)

## First Time Login Credentials

### SSH
- **User**: root
- **Password**: (set in .env as ROOT_PASSWORD)
- **Port**: 2222 (or your SSH_PORT)

### MySQL/MariaDB
- **Root User**: root
- **Root Password**: (set in .env as MYSQL_ROOT_PASSWORD)
- **Database**: (set in .env as MYSQL_DATABASE)
- **User**: (set in .env as MYSQL_USER)
- **Password**: (set in .env as MYSQL_PASSWORD)

### phpMyAdmin
- Use MySQL credentials above
- URL: http://localhost/phpmyadmin

### TinyFileManager
- **Default User**: admin
- **Default Password**: admin@123
- **Change immediately after first login!**

## Common Setup Issues

### Docker Compose Version Error

**Symptoms**: `Invalid interpolation format` or `${VAR:-default}` not working

```bash
# Check version
docker compose version

# If shows "command not found" or v1.x, upgrade
sudo apt-get update
sudo apt-get install docker-compose-plugin

# Verify
docker compose version
# Should show: Docker Compose version v2.x.x
```

### Port Already in Use

```bash
# Check what's using the port
sudo lsof -i :80
sudo lsof -i :443
sudo lsof -i :2222

# Change ports in .env
HTTP_PORT=8080
HTTPS_PORT=8443
SSH_PORT=2223

# Restart container
docker compose down
docker compose up -d
```

### Permission Denied on SSH

```bash
# Check authorized_keys permissions
chmod 600 conf/ssh/authorized_keys

# Rebuild container
docker compose down
docker compose build
docker compose up -d
```

### MySQL Won't Start

```bash
# Stop container
docker compose down

# Remove MySQL data (WARNING: Deletes all databases!)
rm -rf mysql/*

# Start fresh
docker compose up -d
```

### Can't Access Web Interface

```bash
# Check if Apache is running
docker exec lamp-dev supervisorctl status apache2

# Check Apache error log
tail -f logs/apache-error.log

# Test Apache configuration
docker exec lamp-dev apache2ctl configtest

# Restart Apache
docker exec lamp-dev supervisorctl restart apache2
```

### Apache Configuration Syntax Error

**Symptoms**: Apache won't start, shows syntax error

```bash
# Test configuration
docker exec lamp-dev apache2ctl configtest

# Common issue: <LimitExcept> not allowed in security.conf
# This has been fixed in the provided configs
# If you see this, ensure you're using the latest config files

# View Apache error
tail -f logs/apache-error.log
```

### sed Device or Resource Busy Error

**Symptoms**: During startup: `sed: cannot rename /etc/php/X.X/fpm/sedXXXXX: Device or resource busy`

**Cause**: PHP ini files mounted as read-only or sed -i not working with Docker volumes.

**Solution**: This is already handled in the provided startup.sh using temp files. If you see this:

1. Ensure PHP ini files in docker-compose.yaml are **NOT** mounted with `:ro` flag
2. They should be: `./conf/php/php-X.X.ini:/etc/php/X.X/fpm/php.ini` (without `:ro`)
3. Rebuild: `docker compose down && docker compose up -d --build`

## Next Steps

1. **Deploy Your First App**: See README.md for detailed instructions
2. **Switch PHP Version**: Use `php-switch` command inside container
3. **Configure Backups**: Set up regular database backups
4. **Secure for Production**: Follow security guidelines in README.md

## Useful Commands

```bash
# View logs
docker compose logs -f

# Stop container
docker compose stop

# Start container
docker compose start

# Restart container
docker compose restart

# Stop and remove container
docker compose down

# Rebuild and start
docker compose up -d --build

# SSH into container
ssh -p 2222 root@localhost

# Execute command in container
docker exec lamp-dev <command>

# View running processes
docker exec lamp-dev supervisorctl status
```

## Getting Help

1. Check README.md for detailed documentation
2. Check TROUBLESHOOTING.md for common issues
3. Review logs in `logs/` directory
4. Check Docker logs: `docker compose logs`
5. Verify services: `docker exec lamp-dev supervisorctl status`

## Success Checklist

- ✅ Docker Compose v2.x installed
- ✅ Container is running (`docker compose ps`)
- ✅ Can access http://localhost
- ✅ Can SSH into container
- ✅ phpMyAdmin is accessible
- ✅ File Manager is accessible
- ✅ All PHP versions are running (`docker exec lamp-dev supervisorctl status | grep php-fpm`)
- ✅ MySQL is accessible

**You're all set! Start deploying your applications.**
