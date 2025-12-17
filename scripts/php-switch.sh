#!/bin/bash

# PHP Version Switcher for Apache + PHP-FPM
# This script manages PHP version switching on a per-directory basis
# by creating or updating .htaccess files

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Available PHP versions and their FPM ports
declare -A PHP_VERSIONS=(
    ["5.6"]="9056"
    ["7.4"]="9074"
    ["8.3"]="9083"
)

# Function to show available versions
show_versions() {
    echo -e "${BLUE}Available PHP versions:${NC}"
    for version in $(echo "${!PHP_VERSIONS[@]}" | tr ' ' '\n' | sort -V); do
        echo -e "  ${GREEN}→${NC} PHP $version (FPM port: ${PHP_VERSIONS[$version]})"
    done
}

# Function to get current PHP version from .htaccess
get_current_version() {
    if [ -f ".htaccess" ]; then
        # Extract port number from .htaccess
        local port=$(grep -oP 'proxy:fcgi://127\.0\.0\.1:\K\d+' .htaccess 2>/dev/null | head -1)
        
        if [ -n "$port" ]; then
            # Find version by port
            for version in "${!PHP_VERSIONS[@]}"; do
                if [ "${PHP_VERSIONS[$version]}" == "$port" ]; then
                    echo "$version"
                    return 0
                fi
            done
        fi
    fi
    
    # No .htaccess or no PHP handler found - using default
    echo "default (8.3)"
    return 1
}

# Function to check if .htaccess has PHP handler block
has_php_handler() {
    if [ -f ".htaccess" ]; then
        grep -q "proxy:fcgi://127.0.0.1:" .htaccess 2>/dev/null
        return $?
    fi
    return 1
}

# Function to remove existing PHP handler block from .htaccess
remove_php_handler() {
    if [ ! -f ".htaccess" ]; then
        return 0
    fi
    
    # Create temporary file
    local temp_file=$(mktemp)
    
    # Remove PHP handler block while preserving everything else
    awk '
        /<FilesMatch \\\.php\$>/ { 
            in_block=1
            next
        }
        in_block && /SetHandler.*proxy:fcgi/ {
            next
        }
        in_block && /<\/FilesMatch>/ {
            in_block=0
            next
        }
        !in_block { print }
    ' .htaccess > "$temp_file"
    
    # Replace original file
    cat "$temp_file" > .htaccess
    rm "$temp_file"
}

# Function to add PHP handler block to .htaccess
add_php_handler() {
    local version=$1
    local port=${PHP_VERSIONS[$version]}
    
    # Create temporary file with PHP handler at the top
    local temp_file=$(mktemp)
    
    # Write PHP handler block
    cat > "$temp_file" << EOF
<FilesMatch \.php$>
    SetHandler "proxy:fcgi://127.0.0.1:$port"
</FilesMatch>

EOF
    
    # Append existing .htaccess content if it exists
    if [ -f ".htaccess" ]; then
        cat .htaccess >> "$temp_file"
    fi
    
    # Replace original file
    cat "$temp_file" > .htaccess
    rm "$temp_file"
    
    # Set proper permissions
    chmod 644 .htaccess
    chown www-data:www-data .htaccess 2>/dev/null || true
}

# Function to set PHP version
set_php_version() {
    local version=$1
    local port=${PHP_VERSIONS[$version]}
    
    echo -e "${YELLOW}Switching PHP version...${NC}"
    
    # Backup existing .htaccess if it exists
    if [ -f ".htaccess" ]; then
        cp .htaccess .htaccess.backup.$(date +%Y%m%d_%H%M%S)
        echo -e "${GREEN}✓${NC} Backup created"
    fi
    
    # Remove existing PHP handler block
    remove_php_handler
    
    # Add new PHP handler block
    add_php_handler "$version"
    
    echo ""
    echo -e "${GREEN}✓ PHP version switched to $version${NC}"
    echo -e "${BLUE}Directory:${NC} $(pwd)"
    echo -e "${BLUE}FPM Port:${NC} $port"
    
    if ls .htaccess.backup.* >/dev/null 2>&1; then
        echo -e "${YELLOW}Note:${NC} Backup files created in current directory"
    fi
}

# Function to show current status
show_status() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}PHP Version Switcher${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Current directory:${NC} $(pwd)"
    
    local current_version=$(get_current_version)
    if [ "$current_version" == "default (8.3)" ]; then
        echo -e "${BLUE}Current PHP version:${NC} ${YELLOW}$current_version${NC}"
        echo -e "${YELLOW}Note:${NC} No .htaccess file found or no PHP handler configured"
    else
        echo -e "${BLUE}Current PHP version:${NC} ${GREEN}$current_version${NC}"
    fi
    
    echo ""
    show_versions
    echo ""
    echo -e "${BLUE}Usage:${NC} php-switch <version>"
    echo -e "${BLUE}Example:${NC} php-switch 7.4"
}

# Function to test PHP-FPM connectivity
test_php_fpm() {
    local version=$1
    local port=${PHP_VERSIONS[$version]}
    
    echo -e "${YELLOW}Testing PHP-FPM $version connectivity...${NC}"
    
    if nc -z 127.0.0.1 $port 2>/dev/null; then
        echo -e "${GREEN}✓ PHP-FPM $version is running on port $port${NC}"
        return 0
    else
        echo -e "${RED}✗ PHP-FPM $version is not responding on port $port${NC}"
        echo -e "${YELLOW}Check if PHP-FPM service is running:${NC} supervisorctl status php-fpm-$version"
        return 1
    fi
}

# Main script logic
main() {
    case "$1" in
        "")
            # No arguments - show status
            show_status
            ;;
        
        "-h"|"--help"|"help")
            # Show help
            show_status
            ;;
        
        "-t"|"--test")
            # Test PHP-FPM services
            echo -e "${BLUE}Testing PHP-FPM services...${NC}"
            echo ""
            for version in $(echo "${!PHP_VERSIONS[@]}" | tr ' ' '\n' | sort -V); do
                test_php_fpm "$version"
            done
            ;;
        
        "5.6"|"7.4"|"8.3")
            # Valid version - switch to it
            set_php_version "$1"
            ;;
        
        *)
            # Invalid version
            echo -e "${RED}Error: Invalid PHP version '$1'${NC}"
            echo ""
            show_versions
            echo ""
            echo -e "${BLUE}Usage:${NC} php-switch <version>"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
