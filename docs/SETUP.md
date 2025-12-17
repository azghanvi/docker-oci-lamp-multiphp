# Quick Setup Guide

## Prerequisites

- Docker installed
- Docker Compose installed
- Basic understanding of command line

## Step-by-Step Setup

### 1. Create Project Structure

```bash
# Create main directory
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

### 3. Configure Environment Variables

Edit `.env` file:

```bash
# Change these values
CONTAINER_NAME=lamp-dev
SSH_PORT=2222
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
docker-compose build

# Start the container
docker-compose up -d

# Check logs
docker-compose logs -f
```

### 6. Verify Installation

```bash
# Check if services are running
docker-compose ps

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

### Port Already in Use

```bash
# Check what's using the port
sudo lsof -i :80
sudo lsof -i :443
sudo lsof -i :2222

# Change ports in .env
HTTP_PORT=8080
HTTPS_PORT=8443
SSH_PORT=2222

# Restart container
docker-compose down
docker-compose up -d
```

### Permission Denied on SSH

```bash
# Check authorized_keys permissions
chmod 600 conf/ssh/authorized_keys

# Rebuild container
docker-compose down
docker-compose build
docker-compose up -d
```

### MySQL Won't Start

```bash
# Stop container
docker-compose down

# Remove MySQL data (WARNING: Deletes all databases!)
rm -rf mysql/*

# Start fresh
docker-compose up -d
```

### Can't Access Web Interface

```bash
# Check if Apache is running
docker exec lamp-dev supervisorctl status apache2

# Check Apache error log
tail -f logs/apache-error.log

# Restart Apache
docker exec lamp-dev supervisorctl restart apache2
```

## Next Steps

1. **Deploy Your First App**: See README.md for detailed instructions
2. **Switch PHP Version**: Use `php-switch` command
3. **Configure Backups**: Set up regular database backups
4. **Secure for Production**: Follow security guidelines in README.md

## Useful Commands

```bash
# View logs
docker-compose logs -f

# Stop container
docker-compose stop

# Start container
docker-compose start

# Restart container
docker-compose restart

# Stop and remove container
docker-compose down

# Rebuild and start
docker-compose up -d --build

# SSH into container
ssh -p 2222 root@localhost

# Execute command in container
docker exec lamp-dev <command>

# View running processes
docker exec lamp-dev supervisorctl status
```

## Getting Help

1. Check README.md for detailed documentation
2. Review logs in `logs/` directory
3. Check Docker logs: `docker-compose logs`
4. Verify services: `docker exec lamp-dev supervisorctl status`

## Success Checklist

- ✅ Container is running (`docker-compose ps`)
- ✅ Can access http://localhost
- ✅ Can SSH into container
- ✅ phpMyAdmin is accessible
- ✅ File Manager is accessible
- ✅ All PHP versions are running
- ✅ MySQL is accessible

**You're all set! Start deploying your applications.**
