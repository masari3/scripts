#!/bin/bash

# =============================================
# HYBRID PROJECT MANAGER
# Version: 2.1 | Enhanced Permission Handling
# Description: Manage web projects with auto environment detection
# =============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Icons
ICON_CHECK="✅"
ICON_ERROR="❌"
ICON_WARN="⚠️ "
ICON_INFO="ℹ️ "
ICON_GEAR="🔧"
ICON_PACKAGE="📦"
ICON_SERVER="🚀"
ICON_DATABASE="🗄️"
ICON_CODE="💻"
ICON_SECURITY="🔐"
ICON_NETWORK="🌐"
ICON_SUCCESS="🎉"
ICON_FOLDER="📁"
ICON_LIST="📋"
ICON_LINK="🔗"

# Get current user and dynamic paths
CURRENT_USER=$(whoami)
HOME_DIR="/home/$CURRENT_USER"

# Environment detection
detect_environment() {
    if grep -q "Microsoft" /proc/version 2>/dev/null || grep -q "WSL" /proc/version 2>/dev/null; then
        echo "wsl"
    elif [ -d "/mnt/c" ] && command -v powershell.exe >/dev/null 2>&1; then
        echo "wsl"
    else
        echo "native"
    fi
}

ENVIRONMENT=$(detect_environment)

# Dynamic path configuration based on environment
setup_environment_paths() {
    case $ENVIRONMENT in
        "wsl")
            PROJECTS_ROOT="/mnt/d/projects/www"
            HOSTS_FILE="/mnt/c/Windows/System32/drivers/etc/hosts"
            CERT_ROOT="/mnt/d/projects/certs"
            ;;
        "native")
            PROJECTS_ROOT="$HOME_DIR/Projects/www"
            HOSTS_FILE="/etc/hosts"
            CERT_ROOT="$HOME_DIR/.local/share/certs"
            ;;
    esac
    
    # Common paths
    SCRIPTS_ROOT="$HOME_DIR/scripts"
    NGINX_AVAILABLE="/etc/nginx/sites-available"
    NGINX_ENABLED="/etc/nginx/sites-enabled"
    
    # Create directories if they don't exist
    mkdir -p "$PROJECTS_ROOT"
    mkdir -p "$CERT_ROOT"
    mkdir -p "$SCRIPTS_ROOT"
}

# Initialize paths
setup_environment_paths

# Logging functions
log_info() {
    echo -e "${ICON_INFO} ${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${ICON_WARN} ${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${ICON_ERROR} ${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${ICON_GEAR} ${BLUE}[SETUP]${NC} $1"
}

show_header() {
    echo -e "${PURPLE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    HYBRID PROJECT MANAGER                     ║"
    echo "║                   Version 2.1 | Enhanced Permissions          ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${CYAN}Environment:${NC} $ENVIRONMENT | ${CYAN}User:${NC} $CURRENT_USER"
    echo -e "${CYAN}Projects:${NC} $PROJECTS_ROOT"
    echo ""
}

# Function to ensure www-data can access home directory
ensure_www_data_access() {
    echo -e "${ICON_GEAR} Ensuring www-data can access home directory..."
    
    local home_dir="/home/$CURRENT_USER"
    
    # Check current permissions
    local current_perm=$(stat -c "%a" "$home_dir")
    
    if [ "$current_perm" -lt 755 ]; then
        echo -e "${ICON_WARN} Home directory permission is too restrictive: $current_perm"
        echo -e "${ICON_INFO} Setting home directory permission to 755..."
        sudo chmod 755 "$home_dir"
        echo -e "${ICON_CHECK} Home directory permission updated to 755"
    else
        echo -e "${ICON_CHECK} Home directory permission is sufficient: $current_perm"
    fi
    
    # Ensure Projects directory is accessible
    local projects_parent="$HOME_DIR/Projects"
    if [ -d "$projects_parent" ]; then
        sudo chmod 755 "$projects_parent"
        echo -e "${ICON_CHECK} Projects directory permission ensured"
    fi
    
    # Ensure www-data can access the specific project path
    if [ -d "$PROJECTS_ROOT" ]; then
        sudo chmod 755 "$PROJECTS_ROOT"
        echo -e "${ICON_CHECK} Projects root permission ensured"
    fi
}

# Function to setup aliases
setup_aliases() {
    echo -e "${ICON_GEAR} Setting up project manager aliases..."
    
    # Detect shell configuration file
    local shell_config=""
    if [ -n "$BASH_VERSION" ]; then
        shell_config="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        shell_config="$HOME/.zshrc"
    else
        shell_config="$HOME/.bashrc"
    fi
    
    echo -e "${ICON_INFO} Using shell config: $shell_config"
    
    # Get the absolute path to this script
    local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    
    # Check if aliases already exist
    if grep -q "alias project=" "$shell_config" 2>/dev/null; then
        echo -e "${ICON_WARN} Aliases already exist in $shell_config"
        echo -e "${ICON_INFO} Updating aliases..."
        
        # Remove existing project manager aliases
        sed -i '/# PROJECT MANAGER ALIASES/,/# =============================================/d' "$shell_config"
    fi
    
    # Define aliases
    local aliases=(
        "# ============================================="
        "# PROJECT MANAGER ALIASES"
        "# ============================================="
        "alias project='$script_path'"
        "alias pj='$script_path'"
        "alias pj-create='$script_path create'"
        "alias pj-setup='$script_path setup'"
        "alias pj-list='$script_path list'"
        "alias pj-code='$script_path code'"
        "alias pj-delete='$script_path delete'"
        "alias pj-mkcert='$script_path mkcert-setup'"
        "alias pj-trust='$script_path trust-setup'"
        "alias pj-symlink='$script_path symlink'"
        "alias pj-info='$script_path info'"
        "alias pj-env='$script_path env'"
        "alias pj-alias='$script_path setup-alias'"
        "alias pj-exists='$script_path exists'"
        "alias pj-fix='$script_path fix'"
        "alias pj-enable-ssl='$script_path enable-ssl'"
        "alias pj-disable-ssl='$script_path disable-ssl'"
        "alias pj-fix-permissions='$script_path fix-permissions'"
        "alias pj-verify-access='$script_path verify-access'"
        "alias pj-fix-home-permission='$script_path fix-home-permission'"
        "alias pj-troubleshoot='$script_path troubleshoot'"
        "alias pj-network-status='$script_path network-status'"
        "alias pj-restart-services='$script_path restart-services'"
        "alias pj-production-nextjs='$script_path production-nextjs'"
        "alias pj-development-nextjs='$script_path development-nextjs'"
        "alias pj-watch-nextjs='$script_path watch-nextjs'"
        "alias pj-build-nextjs='$script_path build-nextjs'"
        "alias pj-repair='$script_path repair'"
        "alias pj-upgrade-php='$script_path upgrade-php'"
        "alias pj-change-php='$script_path change-php'"
        "alias pj-php-list='$script_path php-list'"
        "alias pj-repair-ssl='$script_path repair-ssl'"
        "alias pj-check-config='$script_path check-config'"
        ""
    )
    
    # Append aliases to shell config
    for alias_line in "${aliases[@]}"; do
        echo "$alias_line" >> "$shell_config"
    done
    
    echo -e "${ICON_CHECK} Aliases added to $shell_config"
    echo ""
    echo -e "${CYAN}AVAILABLE ALIASES:${NC}"
    echo "  ${GREEN}PROJECT MANAGEMENT:${NC}"
    echo "  project, pj          - Main project manager"
    echo "  pj-create            - Create new project"
    echo "  pj-setup             - Setup existing project"
    echo "  pj-list              - List all projects"
    echo "  pj-code              - Open project in VS Code"
    echo "  pj-delete            - Delete project"
    echo "  pj-exists            - Check if project exists"
    echo "  pj-fix               - Fix project configuration"
    echo ""
    echo "  ${BLUE}SSL & SECURITY:${NC}"
    echo "  pj-mkcert            - Setup mkcert for SSL"
    echo "  pj-trust             - Setup browser trust"
    echo "  pj-enable-ssl        - Enable SSL for project"
    echo "  pj-disable-ssl       - Disable SSL for project"
    echo ""
    echo "  ${YELLOW}SYSTEM & ENVIRONMENT:${NC}"
    echo "  pj-symlink           - Setup projects symlink"
    echo "  pj-info              - Show environment info"
    echo "  pj-env               - Show environment paths"
    echo "  pj-alias             - Setup aliases (this command)"
    echo "  pj-restart-services  - Restart web services"
    echo ""
    echo "  ${PURPLE}PERMISSIONS & ACCESS:${NC}"
    echo "  pj-fix-permissions   - Fix project permissions"
    echo "  pj-verify-access     - Verify project web accessibility"
    echo "  pj-fix-home-permission - Fix home directory permission"
    echo ""
    echo "  ${RED}TROUBLESHOOTING:${NC}"
    echo "  pj-troubleshoot      - Troubleshoot connection issues"
    echo "  pj-network-status    - Show network and service status"
    echo ""
    echo "  ${CYAN}NEXT.JS SPECIFIC:${NC}"
    echo "  pj-production-nextjs - Switch Next.js to production mode"
    echo "  pj-development-nextjs - Switch Next.js to development mode"
    echo "  pj-watch-nextjs      - Auto-build Next.js on file changes"
    echo "  pj-build-nextjs      - One-time Next.js production build"
    echo ""
    echo -e "${YELLOW}To use aliases immediately, run:${NC}"
    echo "  source $shell_config"
    echo ""
    echo -e "${YELLOW}Or restart your terminal.${NC}"
}

# Function to show current aliases status
show_alias_status() {
    echo -e "${CYAN}${ICON_INFO} ALIASES STATUS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    
    local shell_config=""
    if [ -n "$BASH_VERSION" ]; then
        shell_config="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        shell_config="$HOME/.zshrc"
    else
        shell_config="$HOME/.bashrc"
    fi
    
    echo -e "Shell config: $shell_config"
    
    if grep -q "alias project=" "$shell_config" 2>/dev/null; then
        echo -e "${ICON_CHECK} Aliases are installed"
        echo ""
        echo -e "${GREEN}Installed aliases:${NC}"
        grep "alias pj" "$shell_config" | grep -v "^#" | sed 's/alias //'
    else
        echo -e "${ICON_ERROR} Aliases are not installed"
        echo ""
        echo -e "${YELLOW}To install aliases, run:${NC}"
        echo "  project setup-alias"
        echo "  OR"
        echo "  ./project-manager.sh setup-alias"
    fi
}

# Function to setup mkcert environment
setup_mkcert() {
    echo -e "${ICON_SECURITY} Setting up mkcert for SSL certificates..."
    
    # Install mkcert if not available
    if ! command -v mkcert &> /dev/null; then
        echo -e "${ICON_PACKAGE} Installing mkcert..."
        sudo apt update
        sudo apt install libnss3-tools -y
        wget -O mkcert https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64
        chmod +x mkcert
        sudo mv mkcert /usr/local/bin/
    fi
    
    # Setup local CA if not exists
    if [ ! -f "$HOME/.local/share/mkcert/rootCA.pem" ]; then
        echo -e "${ICON_GEAR} Creating local Certificate Authority..."
        mkcert -install
    fi
    
    # Create certs directory if not exists
    mkdir -p "$CERT_ROOT"
    
    echo -e "${ICON_CHECK} mkcert setup completed"
}

# Function to setup browser trust for mkcert
setup_browser_trust() {
    echo -e "${ICON_SECURITY} Setting up browser trust for mkcert..."
    
    # Setup mkcert if not setup
    setup_mkcert
    
    # Ensure certs directory exists
    mkdir -p "$CERT_ROOT"
    
    # Export root CA
    local root_ca_path="$HOME/.local/share/mkcert/rootCA.pem"
    
    if [ ! -f "$root_ca_path" ]; then
        echo -e "${ICON_ERROR} mkcert root CA not found"
        return 1
    fi
    
    # Copy root CA to certs directory
    cp "$root_ca_path" "$CERT_ROOT/rootCA.pem"
    
    # Convert to .crt format for Windows
    openssl x509 -outform der -in "$root_ca_path" -out "$CERT_ROOT/rootCA.crt" 2>/dev/null
    
    echo -e "${ICON_CHECK} Root CA exported:"
    echo "   PEM: $CERT_ROOT/rootCA.pem"
    echo "   CRT: $CERT_ROOT/rootCA.crt"
    
    case $ENVIRONMENT in
        "wsl")
            echo ""
            echo -e "${CYAN}WINDOWS TRUST INSTRUCTIONS:${NC}"
            echo "====================================="
            echo "1. Open File Explorer to: D:\\projects\\certs\\"
            echo "2. Double-click 'rootCA.crt'"
            echo "3. Click 'Install Certificate'"
            echo "4. Choose 'Current User' or 'Local Machine'"
            echo "5. Select 'Trusted Root Certification Authorities'"
            echo "6. Click 'OK' and 'Finish'"
            echo "7. RESTART YOUR BROWSER"
            ;;
        "native")
            echo ""
            echo -e "${CYAN}LINUX BROWSER TRUST:${NC}"
            echo "========================"
            echo "Chrome: Settings → Privacy and Security → Security → Manage certificates"
            echo "Firefox: Preferences → Privacy & Security → View Certificates → Authorities"
            echo "Import: $CERT_ROOT/rootCA.pem"
            ;;
    esac
    
    echo ""
    echo -e "${ICON_INFO} After installation, SSL warnings should disappear!"
}

# Function to generate SSL certificate for domain
generate_ssl_cert() {
    local domain=$1
    
    if [ -z "$domain" ]; then
        echo -e "${ICON_ERROR} Domain is required for SSL certificate"
        return 1
    fi
    
    echo -e "${ICON_SECURITY} Generating SSL certificate for: $domain"
    
    # Setup mkcert if not setup
    setup_mkcert
    
    # Ensure certs directory exists
    mkdir -p "$CERT_ROOT"
    
    # Generate certificate in certs directory
    cd "$CERT_ROOT"
    
    # Remove old certificates if exist
    rm -f "$domain.pem" "$domain-key.pem"
    rm -f "$domain"+*.pem  # Remove files with +number
    
    # Generate certificate
    if mkcert -cert-file "$domain.pem" -key-file "$domain-key.pem" \
        "$domain" "www.$domain" "localhost.$domain" "127.0.0.1" "::1"; then
        
        if [ -f "$domain.pem" ] && [ -f "$domain-key.pem" ]; then
            echo -e "${ICON_CHECK} SSL certificate generated:"
            echo "   Cert: $CERT_ROOT/$domain.pem"
            echo "   Key:  $CERT_ROOT/$domain-key.pem"
            return 0
        else
            echo -e "${ICON_ERROR} Certificate files not created properly"
            return 1
        fi
    else
        echo -e "${ICON_ERROR} Failed to generate SSL certificate"
        return 1
    fi
}

# ============================================================
# VALIDATE SSL CERTIFICATE
# ============================================================
validate_ssl_certificate() {
    local domain=$1
    local cert_path="$CERT_ROOT/$domain.pem"
    local key_path="$CERT_ROOT/$domain-key.pem"
    
    if [ -f "$cert_path" ] && [ -f "$key_path" ]; then
        echo -e "${ICON_CHECK} SSL certificate found: $cert_path"
        echo -e "${ICON_CHECK} SSL key found: $key_path"
        return 0
    else
        echo -e "${ICON_WARN} SSL certificate missing for: $domain"
        echo -e "${ICON_GEAR} Generating new certificate..."
        if generate_ssl_cert "$domain"; then
            return 0
        else
            echo -e "${ICON_ERROR} Failed to generate SSL certificate"
            return 1
        fi
    fi
}

# Function to detect PHP version
detect_php_version() {
    # Check for available PHP versions in multiple paths
    local socket_paths=(
        "/run/php"
        "/var/run/php"
    )
    
    local php_versions=""
    for path in "${socket_paths[@]}"; do
        if [ -d "$path" ]; then
            local versions=$(ls "$path"/php*-fpm.sock 2>/dev/null | grep -oP 'php\K[0-9.]+' | sort -V)
            if [ -n "$versions" ]; then
                php_versions="$versions"
                break
            fi
        fi
    done
    
    # If socket files found, use the highest version
    if [ -n "$php_versions" ]; then
        echo "$php_versions" | tail -1
        return 0
    fi
    
    # Fallback: check via systemctl
    local services=$(systemctl list-units --all --type=service --no-pager 2>/dev/null | grep -oP 'php[0-9.]+-fpm' | grep -oP '[0-9.]+' | sort -V)
    if [ -n "$services" ]; then
        echo "$services" | tail -1
        return 0
    fi
    
    # Try via php command
    if command -v php &> /dev/null; then
        php -v 2>/dev/null | head -1 | grep -oP 'PHP \K[0-9.]+'
        return 0
    fi
    
    # Fallback to latest common version
    echo "8.5"  # Default untuk Ubuntu 26.04
}

# Function to get PHP-FPM connection string
get_php_fpm_connection() {
    local php_version=$(detect_php_version)
    
    local connection=""
    case $ENVIRONMENT in
        "wsl")
            # WSL: Check if NTFS mount (need TCP)
            if mount | grep -q "/mnt/d.*type ntfs"; then
                connection="127.0.0.1:9000"  # TCP for NTFS
            else
                # Try multiple possible socket paths
                local socket_paths=(
                    "/run/php/php${php_version}-fpm.sock"      # Primary location
                    "/var/run/php/php${php_version}-fpm.sock"  # Fallback location
                )
                
                for socket_path in "${socket_paths[@]}"; do
                    if [ -S "$socket_path" ]; then
                        connection="unix:$socket_path"
                        break
                    fi
                done
                
                # If no socket found, try to find any PHP-FPM socket
                if [ -z "$connection" ]; then
                    local found_socket=$(find /run/php /var/run/php -name "php*-fpm.sock" 2>/dev/null | head -1)
                    if [ -n "$found_socket" ]; then
                        connection="unix:$found_socket"
                    else
                        connection="127.0.0.1:9000"  # Fallback to TCP
                    fi
                fi
            fi
            ;;
        "native")
            # Native: Try multiple socket paths
            local socket_paths=(
                "/run/php/php${php_version}-fpm.sock"      # Primary location
                "/var/run/php/php${php_version}-fpm.sock"  # Fallback location
            )
            
            for socket_path in "${socket_paths[@]}"; do
                if [ -S "$socket_path" ]; then
                    connection="unix:$socket_path"
                    break
                fi
            done
            
            # If no socket found, try to find any PHP-FPM socket
            if [ -z "$connection" ]; then
                local found_socket=$(find /run/php /var/run/php -name "php*-fpm.sock" 2>/dev/null | head -1)
                if [ -n "$found_socket" ]; then
                    connection="unix:$found_socket"
                else
                    connection="127.0.0.1:9000"  # Fallback to TCP
                fi
            fi
            ;;
    esac
    
    # Validate connection string
    if [[ "$connection" == unix:* ]]; then
        local socket_path="${connection#unix:}"
        if [ ! -S "$socket_path" ]; then
            echo -e "${ICON_WARN} Socket not found: $socket_path, falling back to TCP" >&2
            connection="127.0.0.1:9000"
        fi
    fi
    
    echo "$connection"
}

# Function to check and start PHP-FPM service
ensure_php_fpm_running() {
    local php_version=$(detect_php_version)
    local service_name="php${php_version}-fpm"
    
    # Check if service exists
    if systemctl list-units --all --type=service --no-pager 2>/dev/null | grep -q "$service_name"; then
        if ! systemctl is-active --quiet "$service_name"; then
            echo -e "${ICON_WARN} PHP-FPM service $service_name is not running"
            echo -e "${ICON_GEAR} Starting PHP-FPM service..."
            sudo systemctl start "$service_name"
            sleep 2
            if systemctl is-active --quiet "$service_name"; then
                echo -e "${ICON_CHECK} PHP-FPM service started"
            else
                echo -e "${ICON_WARN} Could not start $service_name, trying to find active PHP-FPM..."
                # Try to find any running PHP-FPM
                local active_service=$(systemctl list-units --all --type=service --no-pager 2>/dev/null | grep "php.*-fpm" | grep "active" | grep -oP 'php[0-9.]+-fpm' | head -1)
                if [ -n "$active_service" ]; then
                    echo -e "${ICON_INFO} Using active service: $active_service"
                else
                    echo -e "${ICON_WARN} No active PHP-FPM service found"
                fi
            fi
        else
            echo -e "${ICON_CHECK} PHP-FPM service $service_name is running"
        fi
    else
        echo -e "${ICON_WARN} PHP-FPM service $service_name not found"
        # Try to find any PHP-FPM service
        local available_service=$(systemctl list-units --all --type=service --no-pager 2>/dev/null | grep "php.*-fpm" | grep -oP 'php[0-9.]+-fpm' | head -1)
        if [ -n "$available_service" ]; then
            echo -e "${ICON_INFO} Found PHP-FPM service: $available_service"
            # Update detected version
            php_version=$(echo "$available_service" | grep -oP '[0-9.]+')
        fi
    fi
}

# Function to setup symlink
setup_symlink() {
    echo -e "${ICON_LINK} Setting up symlink..."
    
    # Remove old symlink OR directory
    if [ -L "/var/www/projects" ]; then
        # Jika symlink, hapus dengan -f
        sudo rm -f /var/www/projects
        echo -e "${ICON_CHECK} Removed old symlink"
    elif [ -d "/var/www/projects" ]; then
        # Jika folder, hapus dengan -rf
        sudo rm -rf /var/www/projects
        echo -e "${ICON_CHECK} Removed old projects directory"
    fi
    
    # Create symlink to projects directory
    sudo ln -s "$PROJECTS_ROOT" /var/www/projects
    
    echo -e "${ICON_CHECK} Symlink created: /var/www/projects -> $PROJECTS_ROOT"
    ls -la /var/www/projects
}

# Function to check if project exists
project_exists() {
    local project_type=$1
    local project_name=$2
    local project_path="$PROJECTS_ROOT/$project_type/$project_name"
    
    if [ -d "$project_path" ]; then
        return 0  # Project exists
    else
        return 1  # Project doesn't exist
    fi
}

# Function to check if domain is already configured
domain_exists() {
    local domain=$1
    if [ -f "$NGINX_AVAILABLE/$domain" ] || [ -L "$NGINX_ENABLED/$domain" ]; then
        return 0  # Domain exists
    else
        return 1  # Domain doesn't exist
    fi
}

# Function to check if domain is in hosts file
hosts_entry_exists() {
    local domain=$1
    
    case $ENVIRONMENT in
        "wsl")
            if powershell.exe -Command "
                \$content = Get-Content 'C:\Windows\System32\drivers\etc\hosts' -ErrorAction SilentlyContinue
                if (\$content -match \"127.0.0.1 $domain\") { exit 0 } else { exit 1 }
            " 2>/dev/null; then
                return 0  # Exists in hosts
            else
                return 1  # Not in hosts
            fi
            ;;
        "native")
            if grep -q "127.0.0.1 $domain" "$HOSTS_FILE"; then
                return 0  # Exists in hosts
            else
                return 1  # Not in hosts
            fi
            ;;
    esac
}

# Function to add domain to hosts file
add_to_hosts() {
    local domain=$1
    
    if hosts_entry_exists "$domain"; then
        echo -e "${ICON_INFO} Domain $domain already exists in hosts file"
        return 0
    fi
    
    echo -e "${ICON_GEAR} Adding $domain to hosts file..."
    
    case $ENVIRONMENT in
        "wsl")
            # Windows hosts file via PowerShell
            if powershell.exe -Command "Add-Content -Path 'C:\Windows\System32\drivers\etc\hosts' -Value '127.0.0.1 $domain' -Force" 2>/dev/null; then
                echo -e "${ICON_CHECK} Added $domain to Windows hosts file"
            else
                echo -e "${ICON_ERROR} Failed to add $domain to hosts file automatically"
                echo "Please manually add this line to C:\\Windows\\System32\\drivers\\etc\\hosts:"
                echo "127.0.0.1 $domain"
            fi
            ;;
        "native")
            # Linux hosts file
            if echo "127.0.0.1 $domain" | sudo tee -a "$HOSTS_FILE" >/dev/null; then
                echo -e "${ICON_CHECK} Added $domain to Linux hosts file"
            else
                echo -e "${ICON_ERROR} Failed to add $domain to hosts file"
            fi
            ;;
    esac
}

# Function to map project type to full name
map_project_type() {
    local short_type=$1
    case $short_type in
        "laravel"|"laravel")
            echo "laravel"
            ;;
        "nextjs"|"next")
            echo "nextjs"
            ;;
        "ci3"|"codeigniter3")
            echo "codeigniter3"
            ;;
        *)
            echo "$short_type"
            ;;
    esac
}

# Function to create new project OR setup existing project
create_project() {
    local project_type=$1
    local project_name=$2
    local domain=$3
    local force_recreate=${4:-false}
    local enable_ssl=${5:-false}
    
    if [ -z "$project_type" ] || [ -z "$project_name" ] || [ -z "$domain" ]; then
        echo -e "${ICON_ERROR} Usage: create_project <laravel|nextjs|ci3> <project-name> <domain> [force] [ssl]"
        echo "Example: create_project laravel myapp myapp.test"
        echo "Example: create_project ci3 myapp myapp.test force ssl"
        return 1
    fi
    
    # Map short project type to full name
    local full_project_type=$(map_project_type "$project_type")
    local project_path="$PROJECTS_ROOT/$full_project_type/$project_name"
    
    # Ensure www-data can access home directory first
    ensure_www_data_access
    
    # Check if project already exists
    if project_exists "$full_project_type" "$project_name"; then
        echo -e "${ICON_INFO} Project already exists: $project_path"
        
        if [ "$force_recreate" = "force" ]; then
            echo -e "${ICON_GEAR} Force recreating nginx configuration..."
        else
            echo -e "${ICON_INFO} Using existing project. To recreate nginx config, use 'force' parameter"
            echo "   Example: create_project $project_type $project_name $domain force"
            
            # Just setup nginx config without creating directories
            setup_nginx_config "$full_project_type" "$project_name" "$domain" "$enable_ssl"
            return 0
        fi
    fi
    
    echo -e "${ICON_GEAR} Creating $full_project_type project: $project_name"
    
    # Create project directory (only if not exists or force)
    if [ ! -d "$project_path" ] || [ "$force_recreate" = "force" ]; then
        mkdir -p "$project_path"
        echo -e "${ICON_CHECK} Created directory: $project_path"
        
        # Create framework-specific default structure
        create_project_structure "$full_project_type" "$project_name"
    fi
    
    # Setup nginx configuration
    setup_nginx_config "$full_project_type" "$project_name" "$domain" "$enable_ssl"
}

# Function to setup ONLY nginx config for existing project
setup_existing_project() {
    local project_type=$1
    local project_name=$2
    local domain=$3
    local enable_ssl=${4:-false}
    
    if [ -z "$project_type" ] || [ -z "$project_name" ] || [ -z "$domain" ]; then
        echo -e "${ICON_ERROR} Usage: setup_existing <laravel|nextjs|ci3> <project-name> <domain> [ssl]"
        echo "Example: setup_existing laravel myapp myapp.test"
        echo "Example: setup_existing ci3 myapp myapp.test ssl"
        return 1
    fi
    
    local full_project_type=$(map_project_type "$project_type")
    
    if ! project_exists "$full_project_type" "$project_name"; then
        echo -e "${ICON_ERROR} Project not found: $PROJECTS_ROOT/$full_project_type/$project_name"
        echo "   Use 'create_project' to create a new project"
        return 1
    fi
    
    echo -e "${ICON_GEAR} Setting up nginx configuration for existing project: $project_name"
    setup_nginx_config "$full_project_type" "$project_name" "$domain" "$enable_ssl"
}

# Function to enable SSL for existing project
enable_ssl() {
    local project_type=$1
    local project_name=$2
    local domain=${3:-"${project_name}.test"}
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo -e "${ICON_ERROR} Usage: enable_ssl <laravel|nextjs|ci3> <project-name> [domain]"
        echo "Example: enable_ssl laravel myapp myapp.test"
        return 1
    fi
    
    local full_project_type=$(map_project_type "$project_type")
    
    if ! project_exists "$full_project_type" "$project_name"; then
        echo -e "${ICON_ERROR} Project not found: $PROJECTS_ROOT/$full_project_type/$project_name"
        return 1
    fi
    
    echo -e "${ICON_SECURITY} Enabling SSL for: $domain"
    setup_nginx_config "$full_project_type" "$project_name" "$domain" "true"
}

# Function to disable SSL for existing project
disable_ssl() {
    local project_type=$1
    local project_name=$2
    local domain=${3:-"${project_name}.test"}
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo -e "${ICON_ERROR} Usage: disable_ssl <laravel|nextjs|ci3> <project-name> [domain]"
        echo "Example: disable_ssl laravel myapp myapp.test"
        return 1
    fi
    
    local full_project_type=$(map_project_type "$project_type")
    
    if ! project_exists "$full_project_type" "$project_name"; then
        echo -e "${ICON_ERROR} Project not found: $PROJECTS_ROOT/$full_project_type/$project_name"
        return 1
    fi
    
    echo -e "${ICON_SECURITY} Disabling SSL for: $domain"
    setup_nginx_config "$full_project_type" "$project_name" "$domain" "false"
}

# Function to fix project (recreate nginx config)
fix_project() {
    local project_type=$1
    local project_name=$2
    local domain=${3:-"${project_name}.test"}
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo -e "${ICON_ERROR} Usage: fix_project <laravel|nextjs|ci3> <project-name> [domain]"
        return 1
    fi
    
    local full_project_type=$(map_project_type "$project_type")
    
    if ! project_exists "$full_project_type" "$project_name"; then
        echo -e "${ICON_ERROR} Project not found: $PROJECTS_ROOT/$full_project_type/$project_name"
        return 1
    fi
    
    echo -e "${ICON_GEAR} Fixing project: $project_name"
    setup_nginx_config "$full_project_type" "$project_name" "$domain" "false"
}

# Function to create framework-specific structure
create_project_structure() {
    local project_type=$1
    local project_name=$2
    local project_path="$PROJECTS_ROOT/$project_type/$project_name"
    
    case $project_type in
        "codeigniter3")
            mkdir -p "$project_path/application"
            mkdir -p "$project_path/system" 
            mkdir -p "$project_path/assets"
            mkdir -p "$project_path/uploads"
            
            # Set proper permissions from the start
            sudo chown -R www-data:www-data "$project_path"
            sudo find "$project_path" -type d -exec chmod 755 {} \;
            sudo find "$project_path" -type f -exec chmod 644 {} \;
            
            # Writable directories
            sudo chmod -R 775 "$project_path/application/cache"
            sudo chmod -R 775 "$project_path/application/logs"
            sudo chmod -R 775 "$project_path/uploads"
            
            echo -e "${ICON_CHECK} Created CodeIgniter 3 folder structure with proper permissions"
            ;;
        "laravel")
            # Laravel will be installed via composer later
            # Set base permissions
            sudo chown -R www-data:www-data "$project_path"
            sudo find "$project_path" -type d -exec chmod 755 {} \;
            sudo find "$project_path" -type f -exec chmod 644 {} \;
            echo -e "${ICON_INFO} Laravel project ready for composer create-project"
            ;;
        "nextjs")
            # NextJS will be installed via npm later
            # Set base permissions
            sudo chown -R www-data:www-data "$project_path"
            sudo find "$project_path" -type d -exec chmod 755 {} \;
            sudo find "$project_path" -type f -exec chmod 644 {} \;
            echo -e "${ICON_INFO} NextJS project ready for create-next-app"
            ;;
    esac
}

# Function to setup nginx configuration with SSL support
setup_nginx_config() {
    local project_type=$1
    local project_name=$2
    local domain=$3
    local enable_ssl=${4:-false}
    
    # Check if domain already configured
    if domain_exists "$domain"; then
        echo -e "${ICON_WARN} Domain $domain already configured in nginx"
        echo "   Overwriting existing configuration..."
        sudo rm -f "$NGINX_AVAILABLE/$domain"
        sudo rm -f "$NGINX_ENABLED/$domain"
    fi
    
    # Detect PHP version and connection (hanya untuk PHP projects)
    local php_connection=""
    local php_version=""
    if [ "$project_type" != "nextjs" ]; then
        # Ensure PHP-FPM is running
        ensure_php_fpm_running
        
        php_connection=$(get_php_fpm_connection)
        php_version=$(detect_php_version)
        echo -e "${ICON_INFO} Detected PHP: $php_version"
        echo -e "${ICON_INFO} PHP-FPM Connection: $php_connection"
        
        # Verify PHP-FPM connection
        if [[ "$php_connection" == "127.0.0.1:9000" ]]; then
            echo -e "${ICON_WARN} Using TCP fallback for PHP-FPM"
        else
            echo -e "${ICON_CHECK} Using Unix socket for PHP-FPM"
        fi
    fi
    
    # Define correct root paths for each project type
    local nginx_root_path=""
    case $project_type in
        "laravel")
            nginx_root_path="/var/www/projects/laravel/$project_name/public"
            ;;
        "nextjs")
            nginx_root_path="/var/www/projects/nextjs/$project_name"
            ;;
        "codeigniter3")
            nginx_root_path="/var/www/projects/codeigniter3/$project_name"
            ;;
        *)
            echo -e "${ICON_ERROR} Unknown project type: $project_type"
            return 1
            ;;
    esac
    
    echo -e "${ICON_INFO} Nginx root path: $nginx_root_path"
    
    # Generate SSL certificate if enable_ssl
    local ssl_cert=""
    local ssl_key=""
    if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ]; then
        echo -e "${ICON_SECURITY} Setting up SSL for: $domain"
        
        # Validate and generate certificate
        if validate_ssl_certificate "$domain"; then
            ssl_cert="$CERT_ROOT/$domain.pem"
            ssl_key="$CERT_ROOT/$domain-key.pem"
            echo -e "${ICON_CHECK} SSL certificate ready"
            echo -e "${ICON_INFO} Certificate: $ssl_cert"
            echo -e "${ICON_INFO} Key: $ssl_key"
        else
            echo -e "${ICON_WARN} SSL certificate generation failed, continuing without SSL"
            enable_ssl="false"
        fi
    fi
    
    # Create nginx config with or without SSL
    if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ] && [ -f "$ssl_cert" ] && [ -f "$ssl_key" ]; then
        # Config dengan SSL
        if [ "$project_type" = "nextjs" ]; then
            # Next.js SSL config
            sudo tee "$NGINX_AVAILABLE/$domain" > /dev/null <<EOF
# Next.js Production Mode - Static Files with SSL
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $domain www.$domain;
    
    ssl_certificate $ssl_cert;
    ssl_certificate_key $ssl_key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;
    
    root $nginx_root_path/out;
    index index.html index.htm;
    
    # Static file caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # HTML files - minimal caching
    location ~* \.html$ {
        expires 5m;
        add_header Cache-Control "public, must-revalidate";
    }
    
    # SPA routing support
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    access_log /var/log/nginx/projects/${domain}-access.log;
    error_log /var/log/nginx/projects/${domain}-error.log;
}
EOF
            echo -e "${ICON_CHECK} SSL configuration applied for Next.js"
            
        else
            # PHP PROJECTS SSL CONFIG - WITH PROPER CERT INCLUDE
            if [ ! -f "$ssl_cert" ] || [ ! -f "$ssl_key" ]; then
                echo -e "${ICON_ERROR} SSL certificate files missing!"
                echo -e "${ICON_INFO} Cert: $ssl_cert"
                echo -e "${ICON_INFO} Key: $ssl_key"
                enable_ssl="false"
            else
                echo -e "${ICON_CHECK} SSL Certificate: $ssl_cert"
                echo -e "${ICON_CHECK} SSL Key: $ssl_key"
                
                sudo tee "$NGINX_AVAILABLE/$domain" > /dev/null <<EOF
# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $domain www.$domain;
    
    # SSL CERTIFICATE CONFIGURATION - INCLUDED
    ssl_certificate $ssl_cert;
    ssl_certificate_key $ssl_key;
    
    # SSL security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # APPLICATION CONFIGURATION
    root $nginx_root_path;
    index index.php index.html index.htm;

    access_log /var/log/nginx/projects/${domain}-access.log;
    error_log /var/log/nginx/projects/${domain}-error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass $php_connection;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
        fastcgi_param REQUEST_URI \$request_uri;
        fastcgi_param QUERY_STRING \$query_string;
        fastcgi_intercept_errors on;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
                echo -e "${ICON_CHECK} SSL configuration applied for PHP project"
                echo -e "${ICON_SECURITY} SSL Certificate included: $ssl_cert"
                echo -e "${ICON_SECURITY} SSL Key included: $ssl_key"
            fi
        fi
        
    else
        # CONFIG TANPA SSL (HTTP ONLY)
        if [ "$project_type" = "nextjs" ]; then
            # Next.js HTTP config
            sudo tee "$NGINX_AVAILABLE/$domain" > /dev/null <<EOF
# Next.js Production Mode - Static Files
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    
    root $nginx_root_path/out;
    index index.html index.htm;
    
    # Static file caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # HTML files - minimal caching
    location ~* \.html$ {
        expires 5m;
        add_header Cache-Control "public, must-revalidate";
    }
    
    # SPA routing support
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    access_log /var/log/nginx/projects/${domain}-access.log;
    error_log /var/log/nginx/projects/${domain}-error.log;
}
EOF
            echo -e "${ICON_CHECK} HTTP-only configuration applied for Next.js"
        else
            # PHP projects HTTP config
            sudo tee "$NGINX_AVAILABLE/$domain" > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    
    root $nginx_root_path;
    index index.php index.html index.htm;

    access_log /var/log/nginx/projects/${domain}-access.log;
    error_log /var/log/nginx/projects/${domain}-error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass $php_connection;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
        fastcgi_param REQUEST_URI \$request_uri;
        fastcgi_param QUERY_STRING \$query_string;
        fastcgi_intercept_errors on;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
            echo -e "${ICON_CHECK} HTTP-only configuration applied for PHP project"
        fi
    fi
    
    # Enable site
    sudo ln -sf "$NGINX_AVAILABLE/$domain" "$NGINX_ENABLED/$domain"
    
    # Add to hosts file
    add_to_hosts "$domain"
    
    # Test and reload nginx
    if sudo nginx -t; then
        sudo service nginx reload
        echo -e "${ICON_CHECK} Nginx configuration reloaded"
    else
        echo -e "${ICON_ERROR} Nginx configuration test failed"
        echo "Checking for configuration errors..."
        
        # Show specific error
        sudo nginx -t 2>&1 | head -10
        
        # Remove broken config
        sudo rm -f "$NGINX_AVAILABLE/$domain"
        sudo rm -f "$NGINX_ENABLED/$domain"
        echo "Removed broken configuration for: $domain"
        return 1
    fi
    
    echo -e "${ICON_SUCCESS} Project setup completed!"
    echo -e "${ICON_FOLDER} Local Path: $PROJECTS_ROOT/$project_type/$project_name"
    echo -e "${ICON_NETWORK} Nginx Path: $nginx_root_path"
    
    # Framework-specific messages
    case $project_type in
        "laravel"|"codeigniter3")
            echo -e "${ICON_CODE} PHP: $php_version via $php_connection"
            ;;
        "nextjs")
            echo -e "${ICON_NETWORK} Node.js: Static files serving"
            if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ]; then
                echo -e "${ICON_INFO} Mode: Production with SSL - No server required"
            else
                echo -e "${ICON_INFO} Mode: Production (Static) - No server required"
            fi
            ;;
    esac
    
    # SSL status dengan message yang sesuai
    if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ] && [ -f "$ssl_cert" ] && [ -f "$ssl_key" ]; then
        echo -e "${ICON_SECURITY} SSL: ENABLED"
        if [ "$project_type" = "nextjs" ]; then
            echo -e "${ICON_NETWORK} URL: https://$domain (Secure)"
            echo -e "${ICON_INFO} HTTP automatically redirects to HTTPS"
        else
            echo -e "${ICON_NETWORK} URLs: http://$domain → https://$domain"
        fi
    else
        echo -e "${ICON_SECURITY} SSL: DISABLED"
        echo -e "${ICON_NETWORK} URL: http://$domain"
    fi
    
    # Next.js specific instructions
    if [ "$project_type" = "nextjs" ]; then
        echo ""
        echo -e "${CYAN}NEXT.JS HYBRID INSTRUCTIONS:${NC}"
        
        if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ]; then
            echo -e "  ${GREEN}🔒 Production Mode with SSL:${NC} (Current)"
            echo -e "    → Access: https://$domain (secure, always available)"
            echo -e "    → Build: npm run build:production"
            echo -e "    → Auto-build: pj-watch-nextjs $project_name"
        else
            echo -e "  ${GREEN}🎯 Production Mode:${NC} (Current)"
            echo -e "    → Access: http://$domain (always available)"
            echo -e "    → Build: npm run build:production"
            echo -e "    → Auto-build: pj-watch-nextjs $project_name"
        fi
        
        echo ""
        echo -e "  ${BLUE}🔧 Development Mode:${NC}"
        echo -e "    → Switch: pj-development-nextjs $project_name"
        echo -e "    → Start: npm run dev"
        echo -e "    → Access: http://localhost:3001 (hot reload)"
        
        # Auto-create placeholder untuk SSL projects
        if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ]; then
            local project_path="$PROJECTS_ROOT/nextjs/$project_name"
            mkdir -p "$project_path/out"
            
            if [ ! -f "$project_path/out/index.html" ]; then
                cat > "$project_path/out/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Next.js - SSL Ready</title>
    <style>
        body { font-family: Arial, sans-serif; padding: 2rem; text-align: center; }
        .ssl-ready { background: #e8f5e8; padding: 1rem; border-radius: 5px; border: 2px solid #4caf50; }
        .instructions { background: #f0f0f0; padding: 1rem; margin: 2rem auto; max-width: 500px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="ssl-ready">
        <h1>🔒 SSL Ready!</h1>
        <p>Your Next.js project is configured for HTTPS</p>
        <p><strong>Domain:</strong> DOMAIN_PLACEHOLDER</p>
        <p><strong>Status:</strong> SSL Certificate Installed</p>
    </div>
    <div class="instructions">
        <h3>Next Steps:</h3>
        <p>1. Build your Next.js project:</p>
        <code>npm run build:production</code>
        <p>2. Or enable auto-build:</p>
        <code>pj-watch-nextjs PROJECT_NAME_PLACEHOLDER</code>
        <p>3. Your site is available at: <strong>https://DOMAIN_PLACEHOLDER</strong></p>
    </div>
</body>
</html>
EOF
                # Replace placeholders
                sed -i "s/DOMAIN_PLACEHOLDER/$domain/g" "$project_path/out/index.html"
                sed -i "s/PROJECT_NAME_PLACEHOLDER/$project_name/g" "$project_path/out/index.html"
                echo -e "${ICON_CHECK} Created SSL-ready placeholder page for immediate testing"
            fi
        fi
    fi
}

# Function to list all projects with status
list_projects() {
    echo -e "${CYAN}${ICON_LIST} PROJECTS OVERVIEW - Environment: $ENVIRONMENT${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    
    # Check each project type
    for project_type in laravel nextjs codeigniter3; do
        echo ""
        case $project_type in
            "laravel") echo -e "${ICON_CODE} Laravel Projects:" ;;
            "nextjs") echo -e "${ICON_NETWORK} NextJS Projects:" ;;
            "codeigniter3") echo -e "${ICON_GEAR} CodeIgniter 3 Projects:" ;;
        esac
        
        if [ -d "$PROJECTS_ROOT/$project_type" ]; then
            find "$PROJECTS_ROOT/$project_type" -maxdepth 1 -type d | tail -n +2 | while read dir; do
                local name=$(basename "$dir")
                local domain="${name}.test"
                local nginx_config="$NGINX_AVAILABLE/$domain"
                
                if [ -f "$nginx_config" ]; then
                    if grep -q "listen 443 ssl" "$nginx_config"; then
                        echo -e "   ${ICON_SECURITY} $name (https://$domain)"
                    else
                        echo -e "   ${ICON_NETWORK} $name (http://$domain)"
                    fi
                else
                    echo -e "   ${ICON_WARN} $name (no nginx config)"
                fi
            done
        else
            echo "   No $project_type projects"
        fi
    done
    
    # Show symlink status
    echo ""
    echo -e "${CYAN}${ICON_LINK} SYMLINK STATUS${NC}"
    if [ -L "/var/www/projects" ]; then
        echo -e "   ${ICON_CHECK} /var/www/projects -> $(readlink /var/www/projects)"
    else
        echo -e "   ${ICON_ERROR} /var/www/projects symlink not found"
    fi
}

# Function to open project in VS Code
code_project() {
    local project_type=$1
    local project_name=$2
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo -e "${ICON_ERROR} Usage: code_project <laravel|nextjs|ci3> <project-name>"
        return 1
    fi
    
    local full_project_type=$(map_project_type "$project_type")
    local project_path="$PROJECTS_ROOT/$full_project_type/$project_name"
    
    if [ -d "$project_path" ]; then
        code "$project_path"
        echo -e "${ICON_CHECK} Opening $project_path in VS Code"
    else
        echo -e "${ICON_ERROR} Project not found: $project_path"
    fi
}

# Function to delete project
delete_project() {
    local project_type=$1
    local project_name=$2
    local remove_files=${3:-false}
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo -e "${ICON_ERROR} Usage: delete_project <laravel|nextjs|ci3> <project-name> [remove-files]"
        echo "Examples:"
        echo "  delete_project laravel myapp              # Remove nginx config only"
        echo "  delete_project ci3 myapp remove-files     # Remove project completely"
        return 1
    fi
    
    local full_project_type=$(map_project_type "$project_type")
    local project_path="$PROJECTS_ROOT/$full_project_type/$project_name"
    local domain="${project_name}.test"
    
    # Remove nginx config
    if domain_exists "$domain"; then
        sudo rm -f "$NGINX_AVAILABLE/$domain"
        sudo rm -f "$NGINX_ENABLED/$domain"
        sudo service nginx reload
        echo -e "${ICON_CHECK} Removed nginx config for: $domain"
    else
        echo -e "${ICON_INFO} No nginx config found for: $domain"
    fi
    
    # Remove SSL certificates
    if [ -f "$CERT_ROOT/$domain.pem" ]; then
        rm -f "$CERT_ROOT/$domain.pem"
        rm -f "$CERT_ROOT/$domain-key.pem"
        echo -e "${ICON_CHECK} Removed SSL certificates for: $domain"
    fi
    
    # Remove project files if requested
    if [ "$remove_files" = "remove-files" ] && [ -d "$project_path" ]; then
        rm -rf "$project_path"
        echo -e "${ICON_CHECK} Removed project directory: $project_path"
    elif [ -d "$project_path" ]; then
        echo -e "${ICON_INFO} Project files kept: $project_path"
    fi
    
    echo -e "${ICON_SUCCESS} Cleanup completed!"
}

# Function to show environment info
show_environment_info() {
    show_header
    echo -e "${CYAN}ENVIRONMENT INFORMATION${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${ICON_INFO} Current User: $CURRENT_USER"
    echo -e "${ICON_INFO} Environment: $ENVIRONMENT"
    echo -e "${ICON_FOLDER} Projects Root: $PROJECTS_ROOT"
    echo -e "${ICON_FOLDER} Certificates: $CERT_ROOT"
    echo -e "${ICON_FOLDER} Scripts: $SCRIPTS_ROOT"
    
    # PHP version detection with fallback
    local php_version=$(detect_php_version)
    echo -e "${ICON_CODE} PHP Version: $php_version"
    
    # PHP-FPM connection
    local php_connection=$(get_php_fpm_connection)
    echo -e "${ICON_LINK} PHP-FPM Connection: $php_connection"
    
    # Show available PHP-FPM services
    echo -e "${ICON_INFO} Available PHP-FPM services:"
    systemctl list-units --all --type=service --no-pager 2>/dev/null | grep "php.*-fpm" | while read line; do
        echo "   $line"
    done
    echo ""
    
    # Test essential services
    echo -e "${CYAN}SERVICE STATUS${NC}"
    if systemctl is-active --quiet nginx; then
        echo -e "  ${ICON_CHECK} Nginx: RUNNING"
    else
        echo -e "  ${ICON_ERROR} Nginx: STOPPED"
    fi
    
    if systemctl is-active --quiet mariadb 2>/dev/null || systemctl is-active --quiet mysql 2>/dev/null; then
        echo -e "  ${ICON_CHECK} Database: RUNNING"
    else
        echo -e "  ${ICON_WARN} Database: STOPPED or not installed"
    fi
    
    # Check PHP-FPM services
    local php_running=false
    for version in $(detect_php_version); do
        if systemctl is-active --quiet "php${version}-fpm" 2>/dev/null; then
            echo -e "  ${ICON_CHECK} PHP $version FPM: RUNNING"
            php_running=true
        fi
    done
    if [ "$php_running" = false ]; then
        echo -e "  ${ICON_WARN} PHP-FPM: No active service found"
    fi
    
    # Check home directory permission
    local home_perm=$(stat -c "%a" "/home/$CURRENT_USER")
    echo -e "  ${ICON_INFO} Home Directory Permission: $home_perm"
    if [ "$home_perm" -lt 755 ]; then
        echo -e "  ${ICON_WARN} Home directory permission might be too restrictive"
    fi
}

# Function to check if project exists (public function)
check_project_exists() {
    local project_type=$1
    local project_name=$2
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo -e "${ICON_ERROR} Usage: exists <laravel|nextjs|ci3> <project-name>"
        return 1
    fi
    
    local full_project_type=$(map_project_type "$project_type")
    
    if project_exists "$full_project_type" "$project_name"; then
        echo -e "${ICON_CHECK} Project exists: $PROJECTS_ROOT/$full_project_type/$project_name"
        return 0
    else
        echo -e "${ICON_ERROR} Project not found: $PROJECTS_ROOT/$full_project_type/$project_name"
        return 1
    fi
}

# Function to fix permissions for projects
fix_permissions() {
    local project_type=$1
    local project_name=$2
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo -e "${ICON_ERROR} Usage: fix_permissions <laravel|nextjs|ci3> <project-name>"
        return 1
    fi
    
    local full_project_type=$(map_project_type "$project_type")
    local project_path="$PROJECTS_ROOT/$full_project_type/$project_name"
    
    if [ ! -d "$project_path" ]; then
        echo -e "${ICON_ERROR} Project not found: $project_path"
        return 1
    fi
    
    echo -e "${ICON_GEAR} Fixing permissions for: $full_project_type/$project_name"
    
    # First ensure home directory is accessible
    ensure_www_data_access
    
    # Fix ownership for PHP-FPM
    sudo chown -R www-data:www-data "$project_path"
    
    # Fix permissions
    sudo find "$project_path" -type d -exec chmod 755 {} \;
    sudo find "$project_path" -type f -exec chmod 644 {} \;
    
    # Special permissions for writable directories
    case $full_project_type in
        "codeigniter3")
            sudo chmod -R 775 "$project_path/application/cache"
            sudo chmod -R 775 "$project_path/application/logs"
            sudo chmod -R 775 "$project_path/uploads"
            ;;
        "laravel")
            sudo chmod -R 775 "$project_path/storage"
            sudo chmod -R 775 "$project_path/bootstrap/cache"
            ;;
    esac
    
    echo -e "${ICON_CHECK} Permissions fixed for: $project_path"
}

# Function to verify project accessibility
verify_project_access() {
    local project_type=$1
    local project_name=$2
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo -e "${ICON_ERROR} Usage: verify_access <laravel|nextjs|ci3> <project-name>"
        return 1
    fi
    
    local full_project_type=$(map_project_type "$project_type")
    local project_path="$PROJECTS_ROOT/$full_project_type/$project_name"
    local nginx_path="/var/www/projects/$full_project_type/$project_name"
    
    echo -e "${ICON_GEAR} Verifying access for: $full_project_type/$project_name"
    
    # Check if project exists
    if [ ! -d "$project_path" ]; then
        echo -e "${ICON_ERROR} Project directory not found: $project_path"
        return 1
    fi
    
    # Check if symlink exists and works
    if [ ! -L "/var/www/projects" ]; then
        echo -e "${ICON_ERROR} Symlink /var/www/projects not found"
        return 1
    fi
    
    # Check if nginx can access the path
    if [ ! -d "$nginx_path" ]; then
        echo -e "${ICON_ERROR} Nginx cannot access: $nginx_path"
        echo "Symlink might be broken"
        return 1
    fi
    
    # Check permissions
    local perms=$(stat -c "%A %U %G" "$project_path")
    echo -e "${ICON_INFO} Permissions: $perms"
    
    # Test PHP file access as www-data
    if sudo -u www-data test -r "$project_path/index.php"; then
        echo -e "${ICON_CHECK} PHP-FPM can read index.php"
    else
        echo -e "${ICON_ERROR} PHP-FPM cannot read index.php"
        echo -e "${ICON_INFO} Running home directory permission fix..."
        ensure_www_data_access
        echo -e "${ICON_INFO} Try running: pj-fix-permissions $project_type $project_name"
    fi
    
    echo -e "${ICON_CHECK} Project access verified"
}

# Function to fix home directory permission specifically
fix_home_permission() {
    echo -e "${ICON_GEAR} Fixing home directory permission for www-data access..."
    
    local home_dir="/home/$CURRENT_USER"
    local current_perm=$(stat -c "%a" "$home_dir")
    
    echo -e "${ICON_INFO} Current home directory permission: $current_perm"
    
    if [ "$current_perm" -lt 755 ]; then
        echo -e "${ICON_WARN} Home directory permission is too restrictive for www-data"
        echo -e "${ICON_INFO} Setting home directory to 755..."
        sudo chmod 755 "$home_dir"
        echo -e "${ICON_CHECK} Home directory permission updated to 755"
    else
        echo -e "${ICON_CHECK} Home directory permission is already sufficient: $current_perm"
    fi
    
    # Ensure Projects directory chain is accessible
    local projects_dir="$HOME_DIR/Projects"
    if [ -d "$projects_dir" ]; then
        sudo chmod 755 "$projects_dir"
        echo -e "${ICON_CHECK} Projects directory permission ensured"
    fi
    
    if [ -d "$PROJECTS_ROOT" ]; then
        sudo chmod 755 "$PROJECTS_ROOT"
        echo -e "${ICON_CHECK} Projects www directory permission ensured"
    fi
    
    echo -e "${ICON_SUCCESS} Home directory permissions fixed for web server access"
}

# Function to troubleshoot connection issues
troubleshoot_connection() {
    local domain=$1
    
    if [ -z "$domain" ]; then
        domain="localhost"
    fi
    
    echo -e "${ICON_GEAR} Troubleshooting connection to: $domain"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    
    # 1. Check Nginx status
    echo -e "\n${ICON_INFO} 1. Checking Nginx status..."
    if systemctl is-active --quiet nginx; then
        echo -e "   ${ICON_CHECK} Nginx is RUNNING"
    else
        echo -e "   ${ICON_ERROR} Nginx is NOT RUNNING"
        echo -e "   ${ICON_GEAR} Starting Nginx..."
        sudo systemctl start nginx
        sleep 2
        if systemctl is-active --quiet nginx; then
            echo -e "   ${ICON_CHECK} Nginx started successfully"
        else
            echo -e "   ${ICON_ERROR} Failed to start Nginx"
            sudo systemctl status nginx --no-pager
            return 1
        fi
    fi
    
    # 2. Check Nginx configuration
    echo -e "\n${ICON_INFO} 2. Checking Nginx configuration..."
    if sudo nginx -t; then
        echo -e "   ${ICON_CHECK} Nginx configuration test passed"
    else
        echo -e "   ${ICON_ERROR} Nginx configuration test failed"
        return 1
    fi
    
    # 3. Check hosts file entry
    echo -e "\n${ICON_INFO} 3. Checking hosts file..."
    if grep -q "$domain" "$HOSTS_FILE"; then
        echo -e "   ${ICON_CHECK} Domain found in hosts file"
    else
        echo -e "   ${ICON_ERROR} Domain NOT found in hosts file: $domain"
        echo -e "   ${ICON_GEAR} Adding to hosts file..."
        add_to_hosts "$domain"
    fi
    
    # 4. Check if domain resolves
    echo -e "\n${ICON_INFO} 4. Checking DNS resolution..."
    if ping -c 1 -W 1 "$domain" &> /dev/null; then
        echo -e "   ${ICON_CHECK} Domain resolves correctly: $domain"
    else
        echo -e "   ${ICON_WARN} Domain does not ping, but might be normal for local domains"
    fi
    
    # 5. Test connection to localhost first
    echo -e "\n${ICON_INFO} 5. Testing basic connectivity..."
    if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 | grep -q "200\|301\|302"; then
        echo -e "   ${ICON_CHECK} Localhost connection successful"
    else
        echo -e "   ${ICON_ERROR} Cannot connect to localhost - Nginx issue"
        return 1
    fi
    
    # 6. Test specific domain
    echo -e "\n${ICON_INFO} 6. Testing domain: $domain"
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://$domain)
    if [ "$response" = "200" ] || [ "$response" = "301" ] || [ "$response" = "302" ]; then
        echo -e "   ${ICON_CHECK} Domain connection successful: HTTP $response"
    else
        echo -e "   ${ICON_ERROR} Domain connection failed: HTTP $response"
        echo -e "   ${ICON_INFO} Checking Nginx site configuration..."
        
        # Check if site config exists
        if [ -f "/etc/nginx/sites-available/$domain" ]; then
            echo -e "   ${ICON_CHECK} Site config exists: /etc/nginx/sites-available/$domain"
            
            # Check if enabled
            if [ -L "/etc/nginx/sites-enabled/$domain" ]; then
                echo -e "   ${ICON_CHECK} Site is enabled"
            else
                echo -e "   ${ICON_ERROR} Site is NOT enabled"
                echo -e "   ${ICON_GEAR} Enabling site..."
                sudo ln -sf "/etc/nginx/sites-available/$domain" "/etc/nginx/sites-enabled/$domain"
                sudo systemctl reload nginx
            fi
        else
            echo -e "   ${ICON_ERROR} Site config not found: /etc/nginx/sites-available/$domain"
        fi
    fi
    
    echo -e "\n${ICON_SUCCESS} Troubleshooting completed!"
}

# Function to show network status
show_network_status() {
    echo -e "${CYAN}${ICON_NETWORK} NETWORK STATUS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    
    # Nginx status
    echo -e "\n${ICON_SERVER} Nginx Status:"
    if systemctl is-active --quiet nginx; then
        echo -e "   ${ICON_CHECK} Running"
        echo -e "   ${ICON_INFO} Active sites:"
        sudo nginx -T 2>/dev/null | grep "server_name " | grep -v "_\|default" | sort | uniq | sed 's/^/     /'
    else
        echo -e "   ${ICON_ERROR} Stopped"
    fi
    
    # PHP-FPM status
    echo -e "\n${ICON_CODE} PHP-FPM Status:"
    for version in 8.2 8.1 7.4; do
        if systemctl is-active --quiet "php${version}-fpm"; then
            echo -e "   ${ICON_CHECK} php${version}-fpm: Running"
        else
            echo -e "   ${ICON_WARN} php${version}-fpm: Stopped"
        fi
    done
    
    # Hosts entries
    echo -e "\n${ICON_NETWORK} Hosts File Entries:"
    grep -E "^(127.0.0.1|::1)" "$HOSTS_FILE" | grep -v "localhost" | head -10 | sed 's/^/     /'
    if ! grep -q "127.0.0.1" "$HOSTS_FILE" | grep -v "localhost"; then
        echo -e "   ${ICON_WARN} No custom domains found in hosts file"
    fi
}

# Function to restart web services
restart_services() {
    echo -e "${ICON_GEAR} Restarting web services..."
    
    # Restart Nginx
    echo -e "${ICON_INFO} Restarting Nginx..."
    sudo systemctl restart nginx
    if systemctl is-active --quiet nginx; then
        echo -e "   ${ICON_CHECK} Nginx restarted successfully"
    else
        echo -e "   ${ICON_ERROR} Failed to restart Nginx"
        sudo systemctl status nginx --no-pager
        return 1
    fi
    
    # Restart PHP-FPM services (dynamic detection)
    echo -e "${ICON_INFO} Restarting PHP-FPM services..."
    local php_services=$(systemctl list-units --all --type=service --no-pager 2>/dev/null | grep "php.*-fpm" | grep -oP 'php[0-9.]+-fpm')
    
    if [ -n "$php_services" ]; then
        for service in $php_services; do
            if systemctl is-active --quiet "$service"; then
                sudo systemctl restart "$service"
                if systemctl is-active --quiet "$service"; then
                    echo -e "   ${ICON_CHECK} $service restarted"
                else
                    echo -e "   ${ICON_WARN} $service restart failed"
                fi
            fi
        done
    else
        echo -e "   ${ICON_WARN} No PHP-FPM services found"
    fi
    
    # Restart MariaDB/MySQL if running
    if systemctl is-active --quiet mariadb 2>/dev/null; then
        echo -e "${ICON_INFO} Restarting MariaDB..."
        sudo systemctl restart mariadb
        if systemctl is-active --quiet mariadb; then
            echo -e "   ${ICON_CHECK} MariaDB restarted"
        else
            echo -e "   ${ICON_WARN} MariaDB restart failed"
        fi
    elif systemctl is-active --quiet mysql 2>/dev/null; then
        echo -e "${ICON_INFO} Restarting MySQL..."
        sudo systemctl restart mysql
        if systemctl is-active --quiet mysql; then
            echo -e "   ${ICON_CHECK} MySQL restarted"
        else
            echo -e "   ${ICON_WARN} MySQL restart failed"
        fi
    fi
    
    echo -e "${ICON_SUCCESS} All services restarted successfully!"
    echo ""
    echo -e "${CYAN}Current Service Status:${NC}"
    show_network_status
}

# Function untuk setup Next.js hybrid environment
setup_nextjs_hybrid() {
    local project_name=$1
    local domain=$2
    local enable_ssl=${3:-false}
    local default_mode=${4:-"production"}  # production | development
    
    echo -e "${ICON_GEAR} Setting up Next.js Hybrid Environment: $project_name"
    
    local project_path="$PROJECTS_ROOT/nextjs/$project_name"
    
    # Create project directory
    mkdir -p "$project_path"
    
    # Create enhanced package.json dengan semua scripts
    if [ ! -f "$project_path/package.json" ]; then
        echo -e "${ICON_INFO} Creating Next.js project with hybrid scripts..."
        cat > "$project_path/package.json" << EOF
{
  "name": "$project_name",
  "version": "1.0.0",
  "scripts": {
    "dev": "next dev -p 3001",
    "build": "next build",
    "start": "next start -p 3001",
    "export": "next build && next export",
    "build:watch": "chokidar 'pages/**/*' 'components/**/*' 'styles/**/*' 'app/**/*' -c 'npm run build && npm run export'",
    "build:production": "npm run build && npm run export",
    "serve:static": "serve out -p 3002",
    "dev:with-proxy": "npm run dev & npm run serve:static",
    "switch:production": "echo 'Switching to production mode...' && npm run build:production",
    "switch:development": "echo 'Switching to development mode...'"
  },
  "dependencies": {
    "next": "latest",
    "react": "latest",
    "react-dom": "latest",
    "serve": "latest"
  },
  "devDependencies": {
    "chokidar-cli": "latest",
    "concurrently": "latest"
  }
}
EOF
    fi
    
    # Create project structure
    mkdir -p "$project_path/pages"
    mkdir -p "$project_path/components" 
    mkdir -p "$project_path/styles"
    mkdir -p "$project_path/public"
    mkdir -p "$project_path/out"  # Static export directory
    
    # Create hybrid homepage
    cat > "$project_path/pages/index.js" << 'EOF'
import { useState, useEffect } from 'react'

export default function Home() {
  const [lastBuilt, setLastBuilt] = useState('')
  const [currentMode, setCurrentMode] = useState('production')
  
  useEffect(() => {
    setLastBuilt(new Date().toLocaleString())
    // Detect mode from URL atau environment
    if (window.location.port === '3001') {
      setCurrentMode('development')
    } else {
      setCurrentMode('production')
    }
  }, [])
  
  return (
    <div style={{ padding: '2rem', fontFamily: 'Arial, sans-serif', maxWidth: '800px', margin: '0 auto' }}>
      <h1>🚀 Next.js Hybrid Environment</h1>
      
      <div style={{ 
        background: currentMode === 'development' ? '#e8f5e8' : '#e8f4ff', 
        padding: '1rem', 
        margin: '1rem 0', 
        borderRadius: '5px',
        border: `2px solid ${currentMode === 'development' ? '#4caf50' : '#2196f3'}`
      }}>
        <strong>Current Mode:</strong> 
        <span style={{ 
          color: currentMode === 'development' ? '#2e7d32' : '#1976d2',
          fontWeight: 'bold',
          marginLeft: '0.5rem'
        }}>
          {currentMode.toUpperCase()}
        </span>
        {currentMode === 'development' && (
          <span style={{ color: '#4caf50', marginLeft: '1rem' }}>● Live</span>
        )}
        {currentMode === 'production' && (
          <span style={{ color: '#2196f3', marginLeft: '1rem' }}>● Static</span>
        )}
      </div>
      
      <div style={{ background: '#f5f5f5', padding: '1rem', borderRadius: '5px' }}>
        <strong>Last Built:</strong> {lastBuilt || 'Not built yet'}
      </div>
      
      <div style={{ marginTop: '2rem', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
        <div style={{ border: '1px solid #ddd', padding: '1rem', borderRadius: '5px' }}>
          <h3>🎯 Production Mode</h3>
          <p><strong>Access:</strong> http://YOUR-DOMAIN.test</p>
          <p><strong>Features:</strong></p>
          <ul>
            <li>Always accessible</li>
            <li>Static files</li>
            <li>Fast loading</li>
            <li>No server required</li>
          </ul>
        </div>
        
        <div style={{ border: '1px solid #ddd', padding: '1rem', borderRadius: '5px' }}>
          <h3>🔧 Development Mode</h3>
          <p><strong>Access:</strong> http://localhost:3001</p>
          <p><strong>Features:</strong></p>
          <ul>
            <li>Hot reload</li>
            <li>Live development</li>
            <li>Debug tools</li>
            <li>Instant updates</li>
          </ul>
        </div>
      </div>
      
      <div style={{ marginTop: '2rem', padding: '1rem', background: '#fff3cd', borderRadius: '5px' }}>
        <h3>🔄 Switch Between Modes:</h3>
        <p>Use the project manager commands to switch between modes:</p>
        <code>pj-production-nextjs {process.env.PROJECT_NAME || 'project-name'}</code><br/>
        <code>pj-development-nextjs {process.env.PROJECT_NAME || 'project-name'}</code>
      </div>
    </div>
  )
}
EOF

    # Setup initial Nginx config berdasarkan default mode
    if [ "$default_mode" = "production" ]; then
        setup_nextjs_production_mode "$project_name" "$domain" "$enable_ssl"
    else
        setup_nextjs_development_mode "$project_name" "$domain" "$enable_ssl"
    fi
    
    echo -e "${ICON_SUCCESS} Next.js Hybrid Environment setup completed!"
    echo -e "${ICON_FOLDER} Project Path: $project_path"
    echo ""
    echo -e "${CYAN}AVAILABLE MODES:${NC}"
    echo -e "  ${GREEN}🎯 Production Mode${NC}  - Static files, always on"
    echo -e "    Access: http://$domain"
    echo -e "  ${BLUE}🔧 Development Mode${NC} - Live server, hot reload"  
    echo -e "    Access: http://localhost:3001"
    echo ""
    echo -e "${YELLOW}SWITCH COMMANDS:${NC}"
    echo "  pj-production-nextjs $project_name    # Switch to production mode"
    echo "  pj-development-nextjs $project_name   # Switch to development mode"
    echo "  pj-watch-nextjs $project_name         # Auto-build for production"
    echo ""
    echo -e "${GREEN}QUICK START:${NC}"
    echo "  cd $project_path"
    echo "  npm install"
    echo "  # Choose your mode above ↑"
}

# Function untuk Production Mode (Static files)
setup_nextjs_production_mode() {
    local project_name=$1
    local domain=$2
    local enable_ssl=${3:-false}
    
    local project_path="$PROJECTS_ROOT/nextjs/$project_name"
    local static_path="$project_path/out"
    local ssl_cert=""
    local ssl_key=""
    
    echo -e "${ICON_GEAR} Switching to PRODUCTION mode: $project_name"
    
    # Ensure static directory exists
    mkdir -p "$static_path"
    
    # Create build status file
    if [ ! -f "$static_path/index.html" ]; then
        cat > "$static_path/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Next.js - Production Mode</title>
    <style>
        body { font-family: Arial, sans-serif; padding: 2rem; text-align: center; }
        .production { background: #e8f4ff; padding: 1rem; border-radius: 5px; border: 2px solid #2196f3; }
        .instructions { background: #f0f0f0; padding: 1rem; margin: 2rem auto; max-width: 500px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="production">
        <h1>🎯 Production Mode</h1>
        <p>Static files served via Nginx</p>
    </div>
    <div class="instructions">
        <h3>Run these commands to build:</h3>
        <code>npm run build:production</code><br><br>
        <strong>Or enable auto-build:</strong><br>
        <code>pj-watch-nextjs '$project_name'</code>
    </div>
</body>
</html>
EOF
    fi
    
    # Generate SSL jika needed
    if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ]; then
        if generate_ssl_cert "$domain"; then
            ssl_cert="$CERT_ROOT/$domain.pem"
            ssl_key="$CERT_ROOT/$domain-key.pem"
        fi
    fi
    
    # Production Nginx Config - Static Files
    if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ] && [ -f "$ssl_cert" ] && [ -f "$ssl_key" ]; then
        sudo tee "$NGINX_AVAILABLE/$domain" > /dev/null <<EOF
# Next.js Production Mode - Static Files with SSL
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $domain www.$domain;
    
    ssl_certificate $ssl_cert;
    ssl_certificate_key $ssl_key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;
    
    root $static_path;
    index index.html index.htm;
    
    # Static file caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # HTML files - minimal caching
    location ~* \.html$ {
        expires 5m;
        add_header Cache-Control "public, must-revalidate";
    }
    
    # SPA routing support
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    access_log /var/log/nginx/projects/${domain}-access.log;
    error_log /var/log/nginx/projects/${domain}-error.log;
}
EOF
    else
        sudo tee "$NGINX_AVAILABLE/$domain" > /dev/null <<EOF
# Next.js Production Mode - Static Files
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    
    root $static_path;
    index index.html index.htm;
    
    # Static file caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # HTML files - minimal caching
    location ~* \.html$ {
        expires 5m;
        add_header Cache-Control "public, must-revalidate";
    }
    
    # SPA routing support
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    access_log /var/log/nginx/projects/${domain}-access.log;
    error_log /var/log/nginx/projects/${domain}-error.log;
}
EOF
    fi
    
    # Apply configuration
    sudo ln -sf "$NGINX_AVAILABLE/$domain" "$NGINX_ENABLED/$domain"
    add_to_hosts "$domain"
    
    if sudo nginx -t; then
        sudo service nginx reload
        echo -e "${ICON_CHECK} Switched to PRODUCTION mode"
        if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ]; then
            echo -e "${CYAN}Access: https://$domain${NC}"
        else
            echo -e "${CYAN}Access: http://$domain${NC}"
        fi
    else
        echo -e "${ICON_ERROR} Failed to switch to production mode"
        return 1
    fi
}

# Function untuk Development Mode (Proxy to dev server)
setup_nextjs_development_mode() {
    local project_name=$1
    local domain=$2
    local enable_ssl=${3:-false}
    
    local project_path="$PROJECTS_ROOT/nextjs/$project_name"
    local ssl_cert=""
    local ssl_key=""
    
    echo -e "${ICON_GEAR} Switching to DEVELOPMENT mode: $project_name"
    
    # Generate SSL jika needed
    if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ]; then
        if generate_ssl_cert "$domain"; then
            ssl_cert="$CERT_ROOT/$domain.pem"
            ssl_key="$CERT_ROOT/$domain-key.pem"
        fi
    fi
    
    # Development Nginx Config - Proxy to Dev Server
    if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ] && [ -f "$ssl_cert" ] && [ -f "$ssl_key" ]; then
        sudo tee "$NGINX_AVAILABLE/$domain" > /dev/null <<EOF
# Next.js Development Mode - Proxy to Dev Server with SSL
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $domain www.$domain;
    
    ssl_certificate $ssl_cert;
    ssl_certificate_key $ssl_key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;
    
    # Proxy to Next.js dev server (port 3001)
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # WebSocket support for HMR
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Longer timeouts for development
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    access_log /var/log/nginx/projects/${domain}-access.log;
    error_log /var/log/nginx/projects/${domain}-error.log;
}
EOF
    else
        sudo tee "$NGINX_AVAILABLE/$domain" > /dev/null <<EOF
# Next.js Development Mode - Proxy to Dev Server
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    
    # Proxy to Next.js dev server (port 3001)
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # WebSocket support for HMR
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Longer timeouts for development
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    access_log /var/log/nginx/projects/${domain}-access.log;
    error_log /var/log/nginx/projects/${domain}-error.log;
}
EOF
    fi
    
    # Apply configuration
    sudo ln -sf "$NGINX_AVAILABLE/$domain" "$NGINX_ENABLED/$domain"
    add_to_hosts "$domain"
    
    if sudo nginx -t; then
        sudo service nginx reload
        echo -e "${ICON_CHECK} Switched to DEVELOPMENT mode"
        if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ]; then
            echo -e "${CYAN}Access via proxy: https://$domain${NC}"
        else
            echo -e "${CYAN}Access via proxy: http://$domain${NC}"
        fi
        echo -e "${CYAN}Access directly: http://localhost:3001${NC}"
        echo -e "${YELLOW}Remember to start dev server: npm run dev${NC}"
    else
        echo -e "${ICON_ERROR} Failed to switch to development mode"
        return 1
    fi
}

# Function untuk switch ke production mode
switch_nextjs_production() {
    local project_name=$1
    
    if [ -z "$project_name" ]; then
        echo -e "${ICON_ERROR} Usage: switch-nextjs-production <project-name>"
        return 1
    fi
    
    local project_path="$PROJECTS_ROOT/nextjs/$project_name"
    
    if [ ! -d "$project_path" ]; then
        echo -e "${ICON_ERROR} Next.js project not found: $project_path"
        return 1
    fi
    
    # Get domain from existing config or use default
    local domain="${project_name}.test"
    
    # Check current SSL status
    local enable_ssl="false"
    if grep -q "listen 443 ssl" "/etc/nginx/sites-available/$domain" 2>/dev/null; then
        enable_ssl="true"
    fi
    
    setup_nextjs_production_mode "$project_name" "$domain" "$enable_ssl"
    
    echo -e "${ICON_SUCCESS} Now in PRODUCTION mode!"
    echo -e "${GREEN}To build your project:${NC}"
    echo "  cd $project_path"
    echo "  npm run build:production"
    echo ""
    echo -e "${GREEN}For auto-rebuild:${NC}"
    echo "  pj-watch-nextjs $project_name"
}

# Function untuk switch ke development mode  
switch_nextjs_development() {
    local project_name=$1
    
    if [ -z "$project_name" ]; then
        echo -e "${ICON_ERROR} Usage: switch-nextjs-development <project-name>"
        return 1
    fi
    
    local project_path="$PROJECTS_ROOT/nextjs/$project_name"
    
    if [ ! -d "$project_path" ]; then
        echo -e "${ICON_ERROR} Next.js project not found: $project_path"
        return 1
    fi
    
    # Get domain from existing config or use default
    local domain="${project_name}.test"
    
    # Check current SSL status
    local enable_ssl="false"
    if grep -q "listen 443 ssl" "/etc/nginx/sites-available/$domain" 2>/dev/null; then
        enable_ssl="true"
    fi
    
    setup_nextjs_development_mode "$project_name" "$domain" "$enable_ssl"
    
    echo -e "${ICON_SUCCESS} Now in DEVELOPMENT mode!"
    echo -e "${BLUE}Start development server:${NC}"
    echo "  cd $project_path"
    echo "  npm run dev"
    echo ""
    echo -e "${BLUE}Access via:${NC}"
    if [ "$enable_ssl" = "true" ]; then
        echo "  https://$domain (through proxy)"
    else
        echo "  http://$domain (through proxy)"
    fi
    echo "  http://localhost:3001 (direct)"
}

# Enhanced watcher dengan mode awareness
start_nextjs_watcher() {
    local project_name=$1
    
    if [ -z "$project_name" ]; then
        echo -e "${ICON_ERROR} Usage: start-nextjs-watcher <project-name>"
        return 1
    fi
    
    local project_path="$PROJECTS_ROOT/nextjs/$project_name"
    
    if [ ! -d "$project_path" ]; then
        echo -e "${ICON_ERROR} Next.js project not found: $project_path"
        return 1
    fi
    
    echo -e "${ICON_GEAR} Starting Next.js Auto-build Watcher: $project_name"
    
    cd "$project_path"
    
    # Check current mode
    if grep -q "Proxy to Next.js dev server" "/etc/nginx/sites-available/${project_name}.test" 2>/dev/null; then
        echo -e "${ICON_WARN} Currently in DEVELOPMENT mode - switch to PRODUCTION for auto-build"
        echo -e "${YELLOW}Run: pj-production-nextjs $project_name${NC}"
        return 1
    fi
    
    # Check SSL status for URL
    local ssl_enabled="false"
    if grep -q "listen 443 ssl" "/etc/nginx/sites-available/${project_name}.test" 2>/dev/null; then
        ssl_enabled="true"
    fi
    
    # Install dependencies if not installed
    if [ ! -d "node_modules" ]; then
        echo -e "${ICON_INFO} Installing dependencies..."
        npm install
    fi
    
    # Initial build
    echo -e "${ICON_INFO} Running initial build..."
    npm run build:production
    
    echo -e "${ICON_SUCCESS} Auto-build watcher started!"
    echo -e "${CYAN}Mode: PRODUCTION (Static files)${NC}"
    echo -e "${CYAN}Watching for file changes...${NC}"
    if [ "$ssl_enabled" = "true" ]; then
        echo -e "${CYAN}Access: https://${project_name}.test${NC}"
    else
        echo -e "${CYAN}Access: http://${project_name}.test${NC}"
    fi
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    
    # Start file watcher with better output
    npx chokidar 'pages/**/*' 'components/**/*' 'styles/**/*' 'app/**/*' 'public/**/*' \
        -c 'echo "📦 [$(date +"%T")] Changes detected → Rebuilding..." && npm run build:production && echo "✅ [$(date +"%T")] Build completed - Refresh browser!"'
}

# Function untuk one-time build Next.js production
build_nextjs_production() {
    local project_name=$1
    
    if [ -z "$project_name" ]; then
        echo -e "${ICON_ERROR} Usage: build-nextjs <project-name>"
        return 1
    fi
    
    local project_path="$PROJECTS_ROOT/nextjs/$project_name"
    
    if [ ! -d "$project_path" ]; then
        echo -e "${ICON_ERROR} Next.js project not found: $project_path"
        return 1
    fi
    
    echo -e "${ICON_GEAR} Building Next.js for production: $project_name"
    
    cd "$project_path"
    
    # Install dependencies jika belum
    if [ ! -d "node_modules" ]; then
        echo -e "${ICON_INFO} Installing dependencies..."
        npm install
    fi
    
    # Build production
    if npm run build:production; then
        echo -e "${ICON_SUCCESS} Production build completed!"
        # Check SSL status for URL
        local ssl_enabled="false"
        if grep -q "listen 443 ssl" "/etc/nginx/sites-available/${project_name}.test" 2>/dev/null; then
            ssl_enabled="true"
        fi
        if [ "$ssl_enabled" = "true" ]; then
            echo -e "${CYAN}Access: https://${project_name}.test${NC}"
        else
            echo -e "${CYAN}Access: http://${project_name}.test${NC}"
        fi
    else
        echo -e "${ICON_ERROR} Build failed!"
        return 1
    fi
}

# Function to repair/upgrade nginx configuration for all projects or specific project
repair_nginx_config() {
    local project_type=$1
    local project_name=$2
    
    echo -e "${ICON_GEAR} Repairing/Upgrading Nginx configuration..."
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    
    # If specific project given
    if [ -n "$project_type" ] && [ -n "$project_name" ]; then
        local full_project_type=$(map_project_type "$project_type")
        local domain="${project_name}.test"
        
        if ! project_exists "$full_project_type" "$project_name"; then
            echo -e "${ICON_ERROR} Project not found: $project_type/$project_name"
            return 1
        fi
        
        echo -e "${ICON_INFO} Repairing configuration for: $project_type/$project_name"
        
        # Detect current SSL status
        local ssl_enabled="false"
        if [ -f "$NGINX_AVAILABLE/$domain" ] && grep -q "listen 443 ssl" "$NGINX_AVAILABLE/$domain"; then
            ssl_enabled="true"
        fi
        
        # Recreate nginx config with current settings
        setup_nginx_config "$full_project_type" "$project_name" "$domain" "$ssl_enabled"
        
        echo -e "${ICON_SUCCESS} Configuration repaired for: $domain"
        
    else
        # Repair all projects
        echo -e "${ICON_INFO} Repairing all project configurations..."
        local repaired=0
        local failed=0
        
        for project_type in laravel nextjs codeigniter3; do
            if [ -d "$PROJECTS_ROOT/$project_type" ]; then
                find "$PROJECTS_ROOT/$project_type" -maxdepth 1 -type d | tail -n +2 | while read dir; do
                    local name=$(basename "$dir")
                    local domain="${name}.test"
                    local full_project_type=$(map_project_type "$project_type")
                    
                    echo -e "${ICON_GEAR} Repairing: $project_type/$name"
                    
                    # Detect current SSL status
                    local ssl_enabled="false"
                    if [ -f "$NGINX_AVAILABLE/$domain" ] && grep -q "listen 443 ssl" "$NGINX_AVAILABLE/$domain"; then
                        ssl_enabled="true"
                    fi
                    
                    # Backup old config
                    if [ -f "$NGINX_AVAILABLE/$domain" ]; then
                        sudo cp "$NGINX_AVAILABLE/$domain" "$NGINX_AVAILABLE/${domain}.backup"
                    fi
                    
                    # Recreate config
                    if setup_nginx_config "$full_project_type" "$name" "$domain" "$ssl_enabled"; then
                        ((repaired++))
                        echo -e "${ICON_CHECK} Repaired: $domain"
                    else
                        ((failed++))
                        echo -e "${ICON_ERROR} Failed to repair: $domain"
                    fi
                done
            fi
        done
        
        echo ""
        echo -e "${ICON_SUCCESS} Repair completed!"
        echo -e "${ICON_INFO} Repaired: $repaired projects"
        if [ $failed -gt 0 ]; then
            echo -e "${ICON_WARN} Failed: $failed projects"
        fi
    fi
}

# Function to upgrade/change PHP version
upgrade_php_version() {
    local project_type=$1
    local project_name=$2
    local target_version=$3
    
    if [ -z "$target_version" ]; then
        echo -e "${ICON_ERROR} Usage: upgrade_php <laravel|ci3> <project-name> <php-version>"
        echo "Example: upgrade_php laravel myapp 8.5"
        echo "Example: upgrade_php ci3 myapp 8.2"
        return 1
    fi
    
    # Check if project exists
    local full_project_type=$(map_project_type "$project_type")
    if ! project_exists "$full_project_type" "$project_name"; then
        echo -e "${ICON_ERROR} Project not found: $project_type/$project_name"
        return 1
    fi
    
    echo -e "${ICON_GEAR} Upgrading PHP version for: $project_type/$project_name"
    echo -e "${ICON_INFO} Target PHP Version: $target_version"
    
    # Check if target PHP-FPM exists
    local socket_path="/run/php/php${target_version}-fpm.sock"
    if [ ! -S "$socket_path" ]; then
        # Try fallback location
        socket_path="/var/run/php/php${target_version}-fpm.sock"
        if [ ! -S "$socket_path" ]; then
            echo -e "${ICON_WARN} Socket not found: /run/php/php${target_version}-fpm.sock or /var/run/php/php${target_version}-fpm.sock"
            
            # Check if service exists
            if systemctl list-units --all --type=service --no-pager 2>/dev/null | grep -q "php${target_version}-fpm"; then
                echo -e "${ICON_INFO} Service exists but not running. Starting..."
                sudo systemctl start "php${target_version}-fpm"
                sleep 2
                if [ ! -S "$socket_path" ]; then
                    echo -e "${ICON_ERROR} Failed to start PHP ${target_version} FPM"
                    echo -e "${ICON_INFO} Available PHP versions:"
                    ls /run/php/php*-fpm.sock 2>/dev/null | grep -oP 'php\K[0-9.]+' || echo "No PHP-FPM services found"
                    return 1
                fi
            else
                echo -e "${ICON_ERROR} PHP ${target_version} FPM not installed"
                echo -e "${ICON_INFO} Available PHP versions:"
                ls /run/php/php*-fpm.sock 2>/dev/null | grep -oP 'php\K[0-9.]+' || echo "No PHP-FPM services found"
                return 1
            fi
        fi
    fi
    
    # Update project PHP version
    local project_path="$PROJECTS_ROOT/$full_project_type/$project_name"
    
    # For Laravel: Update .env PHP version
    if [ "$full_project_type" = "laravel" ]; then
        if [ -f "$project_path/.env" ]; then
            sed -i "s/^PHP_VERSION=.*/PHP_VERSION=${target_version}/" "$project_path/.env"
            echo -e "${ICON_CHECK} Updated .env PHP_VERSION to $target_version"
        fi
        
        # Update composer.json
        if [ -f "$project_path/composer.json" ]; then
            sed -i "s/\"php\": \".*\"/\"php\": \">=${target_version}\"/" "$project_path/composer.json"
            echo -e "${ICON_CHECK} Updated composer.json PHP requirement"
        fi
    fi
    
    # Recreate nginx config with new PHP version
    local domain="${project_name}.test"
    local ssl_enabled="false"
    if [ -f "$NGINX_AVAILABLE/$domain" ] && grep -q "listen 443 ssl" "$NGINX_AVAILABLE/$domain"; then
        ssl_enabled="true"
    fi
    
    # Force set PHP version for this project
    setup_nginx_config "$full_project_type" "$project_name" "$domain" "$ssl_enabled"
    
    echo -e "${ICON_SUCCESS} PHP version upgraded to $target_version"
    echo -e "${ICON_INFO} Project: $project_path"
    echo -e "${ICON_CODE} PHP-FPM: $target_version via $socket_path"
}

# Function to change PHP version interactively
change_php_version() {
    local project_type=$1
    local project_name=$2
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo -e "${ICON_ERROR} Usage: change_php <laravel|ci3> <project-name>"
        return 1
    fi
    
    local full_project_type=$(map_project_type "$project_type")
    if ! project_exists "$full_project_type" "$project_name"; then
        echo -e "${ICON_ERROR} Project not found: $project_type/$project_name"
        return 1
    fi
    
    echo -e "${ICON_GEAR} Changing PHP version for: $project_type/$project_name"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    
    # Get available PHP versions from both paths
    local available_versions=()
    local socket_files=$(ls /run/php/php*-fpm.sock 2>/dev/null)
    if [ -z "$socket_files" ]; then
        socket_files=$(ls /var/run/php/php*-fpm.sock 2>/dev/null)
    fi
    
    if [ -z "$socket_files" ]; then
        echo -e "${ICON_ERROR} No PHP-FPM services found"
        return 1
    fi
    
    # Parse available versions
    for socket in $socket_files; do
        local version=$(basename "$socket" | grep -oP 'php\K[0-9.]+')
        if [ -n "$version" ]; then
            available_versions+=("$version")
        fi
    done
    
    # Sort versions
    IFS=$'\n' available_versions=($(sort -V <<<"${available_versions[*]}"))
    
    echo -e "${CYAN}Available PHP Versions:${NC}"
    local i=1
    for version in "${available_versions[@]}"; do
        local status=""
        if systemctl is-active --quiet "php${version}-fpm" 2>/dev/null; then
            status=" (RUNNING)"
        else
            status=" (STOPPED)"
        fi
        echo "  $i) PHP $version$status"
        ((i++))
    done
    
    echo ""
    echo -e "${YELLOW}Enter version number to switch (1-${#available_versions[@]}):${NC} "
    read -r choice
    
    # Validate input
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#available_versions[@]} ]; then
        echo -e "${ICON_ERROR} Invalid selection"
        return 1
    fi
    
    local selected_version="${available_versions[$((choice-1))]}"
    echo -e "${ICON_INFO} Selected PHP: $selected_version"
    
    # Upgrade to selected version
    upgrade_php_version "$project_type" "$project_name" "$selected_version"
}

# Function to list all PHP versions available
list_php_versions() {
    echo -e "${CYAN}${ICON_CODE} PHP VERSIONS STATUS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check via sockets - primary path
    echo -e "${ICON_INFO} PHP-FPM Sockets (/run/php):"
    local socket_files=$(ls /run/php/php*-fpm.sock 2>/dev/null)
    if [ -n "$socket_files" ]; then
        for socket in $socket_files; do
            local version=$(basename "$socket" | grep -oP 'php\K[0-9.]+')
            local status=""
            local service="php${version}-fpm"
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                status="${GREEN}RUNNING${NC}"
            else
                status="${RED}STOPPED${NC}"
            fi
            echo -e "   PHP $version: $status (socket: $socket)"
        done
    else
        echo -e "   ${ICON_WARN} No PHP-FPM sockets found in /run/php"
    fi
    
    echo ""
    echo -e "${ICON_INFO} PHP-FPM Services:"
    local services=$(systemctl list-units --all --type=service --no-pager 2>/dev/null | grep "php.*-fpm")
    if [ -n "$services" ]; then
        echo "$services" | while read line; do
            echo "   $line"
        done
    else
        echo -e "   ${ICON_WARN} No PHP-FPM services found"
    fi
    
    echo ""
    echo -e "${ICON_INFO} PHP CLI Version:"
    if command -v php &> /dev/null; then
        php -v 2>&1 | head -1
    else
        echo -e "   ${ICON_WARN} PHP CLI not found"
    fi
}

# Function to repair SSL certificates for project
repair_ssl() {
    local project_type=$1
    local project_name=$2
    local domain=${3:-"${project_name}.test"}
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo -e "${ICON_ERROR} Usage: repair_ssl <laravel|nextjs|ci3> <project-name> [domain]"
        return 1
    fi
    
    local full_project_type=$(map_project_type "$project_type")
    
    if ! project_exists "$full_project_type" "$project_name"; then
        echo -e "${ICON_ERROR} Project not found: $PROJECTS_ROOT/$full_project_type/$project_name"
        return 1
    fi
    
    echo -e "${ICON_GEAR} Repairing SSL for: $project_type/$project_name"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    
    # Remove old certificates
    if [ -f "$CERT_ROOT/$domain.pem" ]; then
        echo -e "${ICON_INFO} Removing old certificate..."
        rm -f "$CERT_ROOT/$domain.pem"
        rm -f "$CERT_ROOT/$domain-key.pem"
    fi
    
    # Generate new certificate
    if generate_ssl_cert "$domain"; then
        echo -e "${ICON_CHECK} New SSL certificate generated"
        
        # Recreate nginx config with SSL
        setup_nginx_config "$full_project_type" "$project_name" "$domain" "true"
        
        echo -e "${ICON_SUCCESS} SSL repaired for: $domain"
        echo -e "${ICON_NETWORK} Access: https://$domain"
    else
        echo -e "${ICON_ERROR} Failed to repair SSL for: $domain"
        return 1
    fi
}

# Function to check and validate current configuration
check_config() {
    local project_type=$1
    local project_name=$2
    
    echo -e "${ICON_GEAR} Checking configuration..."
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    
    if [ -n "$project_type" ] && [ -n "$project_name" ]; then
        # Check specific project
        local full_project_type=$(map_project_type "$project_type")
        local domain="${project_name}.test"
        local project_path="$PROJECTS_ROOT/$full_project_type/$project_name"
        
        if [ ! -d "$project_path" ]; then
            echo -e "${ICON_ERROR} Project not found: $project_path"
            return 1
        fi
        
        echo -e "${ICON_INFO} Checking project: $full_project_type/$project_name"
        echo -e "${ICON_INFO} Path: $project_path"
        
        # Check nginx config
        if [ -f "$NGINX_AVAILABLE/$domain" ]; then
            echo -e "${ICON_CHECK} Nginx config exists: $NGINX_AVAILABLE/$domain"
            
            # Check SSL
            if grep -q "ssl_certificate" "$NGINX_AVAILABLE/$domain"; then
                local cert_path=$(grep "ssl_certificate" "$NGINX_AVAILABLE/$domain" | head -1 | awk '{print $2}' | tr -d ';')
                if [ -f "$cert_path" ]; then
                    echo -e "${ICON_CHECK} SSL certificate found: $cert_path"
                else
                    echo -e "${ICON_ERROR} SSL certificate not found: $cert_path"
                fi
            else
                echo -e "${ICON_WARN} SSL not configured"
            fi
            
            # Check PHP-FPM
            if grep -q "fastcgi_pass" "$NGINX_AVAILABLE/$domain"; then
                local fpm_connection=$(grep "fastcgi_pass" "$NGINX_AVAILABLE/$domain" | head -1 | awk '{print $2}' | tr -d ';')
                echo -e "${ICON_INFO} PHP-FPM: $fpm_connection"
                
                if [[ "$fpm_connection" == unix:* ]]; then
                    local socket_path="${fpm_connection#unix:}"
                    if [ -S "$socket_path" ]; then
                        echo -e "${ICON_CHECK} Socket exists: $socket_path"
                    else
                        echo -e "${ICON_ERROR} Socket not found: $socket_path"
                    fi
                fi
            fi
        else
            echo -e "${ICON_ERROR} Nginx config not found: $NGINX_AVAILABLE/$domain"
        fi
        
        # Check symlink
        if [ -L "$NGINX_ENABLED/$domain" ]; then
            echo -e "${ICON_CHECK} Site enabled: $NGINX_ENABLED/$domain"
        else
            echo -e "${ICON_ERROR} Site not enabled"
        fi
        
    else
        # Check all projects
        echo -e "${ICON_INFO} Checking all projects..."
        for project_type in laravel nextjs codeigniter3; do
            if [ -d "$PROJECTS_ROOT/$project_type" ]; then
                find "$PROJECTS_ROOT/$project_type" -maxdepth 1 -type d | tail -n +2 | while read dir; do
                    local name=$(basename "$dir")
                    local domain="${name}.test"
                    echo ""
                    echo -e "${CYAN}Checking: $project_type/$name${NC}"
                    
                    if [ -f "$NGINX_AVAILABLE/$domain" ]; then
                        echo -e "  ${ICON_CHECK} Config exists"
                        if grep -q "ssl_certificate" "$NGINX_AVAILABLE/$domain"; then
                            echo -e "  ${ICON_SECURITY} SSL enabled"
                        else
                            echo -e "  ${ICON_WARN} SSL disabled"
                        fi
                    else
                        echo -e "  ${ICON_ERROR} Config missing"
                    fi
                done
            fi
        done
    fi
}

# Function to show detailed help with aliases
show_detailed_help() {
    show_header
    echo -e "${CYAN}AVAILABLE COMMANDS & ALIASES${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}MAIN COMMANDS:${NC}"
    echo "  project create <type> <name> <domain> [force] [ssl]"
    echo "  project setup <type> <name> <domain> [ssl]"
    echo "  project list"
    echo "  project code <type> <name>"
    echo "  project delete <type> <name> [remove-files]"
    echo "  project exists <type> <name>"
    echo "  project fix <type> <name> [domain]"
    echo "  project enable-ssl <type> <name> [domain]"
    echo "  project disable-ssl <type> <name> [domain]"
    echo "  project mkcert-setup"
    echo "  project trust-setup"
    echo "  project symlink"
    echo "  project info"
    echo "  project env"
    echo "  project setup-alias"
    echo "  project alias-status"
    echo "  project fix-permissions"
    echo "  project verify-access"
    echo "  project fix-home-permission"
    echo "  project troubleshoot [domain]"
    echo "  project network-status"
    echo "  project restart-services"
    echo "  project production-nextjs <name>"
    echo "  project development-nextjs <name>"
    echo "  project watch-nextjs <name>"
    echo "  project build-nextjs <name>"
    echo ""
    echo -e "${YELLOW}REPAIR & UPGRADE COMMANDS:${NC}"
    echo "  project repair [type] [name]"
    echo "  project upgrade-php <type> <name> <version>"
    echo "  project change-php <type> <name>"
    echo "  project php-list"
    echo "  project repair-ssl <type> <name> [domain]"
    echo "  project check-config [type] [name]"
    echo ""
    echo -e "${YELLOW}QUICK ALIASES:${NC}"
    echo "  ${GREEN}Project Management:${NC}"
    echo "  pj-create <type> <name> <domain> [ssl]"
    echo "  pj-setup <type> <name> <domain> [ssl]"
    echo "  pj-list"
    echo "  pj-code <type> <name>"
    echo "  pj-delete <type> <name> [remove-files]"
    echo "  pj-exists <type> <name>"
    echo "  pj-fix <type> <name> [domain]"
    echo "  pj-enable-ssl <type> <name> [domain]"
    echo "  pj-disable-ssl <type> <name> [domain]"
    echo ""
    echo "  ${BLUE}System & Security:${NC}"
    echo "  pj-mkcert"
    echo "  pj-trust"
    echo "  pj-symlink"
    echo "  pj-info"
    echo "  pj-env"
    echo "  pj-alias"
    echo "  pj-restart-services"
    echo ""
    echo "  ${PURPLE}Permissions & Access:${NC}"
    echo "  pj-fix-permissions"
    echo "  pj-verify-access"
    echo "  pj-fix-home-permission"
    echo ""
    echo "  ${RED}Troubleshooting:${NC}"
    echo "  pj-troubleshoot [domain]"
    echo "  pj-network-status"
    echo ""
    echo "  ${CYAN}Next.js Specific:${NC}"
    echo "  pj-production-nextjs <name>"
    echo "  pj-development-nextjs <name>"
    echo "  pj-watch-nextjs <name>"
    echo "  pj-build-nextjs <name>"
    echo ""
    echo "  ${PURPLE}Repair Aliases:${NC}"
    echo "  pj-repair [type] [name]         - Repair nginx config"
    echo "  pj-upgrade-php <type> <name> <version> - Upgrade PHP version"
    echo "  pj-change-php <type> <name>     - Change PHP version interactive"
    echo "  pj-php-list                     - List PHP versions"
    echo "  pj-repair-ssl <type> <name> [domain] - Repair SSL certificate"
    echo "  pj-check-config [type] [name]   - Check configuration"
    echo ""
    echo -e "${BLUE}EXAMPLES:${NC}"
    echo "  ${GREEN}Basic Usage:${NC}"
    echo "  pj-create laravel myapp myapp.test"
    echo "  pj-create ci3 myapp myapp.test ssl"
    echo "  pj-setup laravel existing-app app.test"
    echo "  pj-exists ci3 myapp"
    echo "  pj-fix laravel myapp"
    echo "  pj-enable-ssl ci3 myapp"
    echo "  pj-list"
    echo ""
    echo "  ${CYAN}Next.js Hybrid Workflow:${NC}"
    echo "  pj-create nextjs samos-next samos-next.test"
    echo "  pj-production-nextjs samos-next    # Static mode (always accessible)"
    echo "  pj-watch-nextjs samos-next         # Auto-build on changes"
    echo "  pj-development-nextjs samos-next   # Dev mode (hot reload)"
    echo "  # Then: cd ~/Projects/www/nextjs/samos-next && npm run dev"
    echo ""
    echo "  ${RED}Troubleshooting:${NC}"
    echo "  pj-troubleshoot myapp.test"
    echo "  pj-network-status"
    echo "  pj-restart-services"
    echo "  pj-fix-home-permission"
    echo ""
    echo "  ${PURPLE}Repair Examples:${NC}"
    echo "  pj-repair                       # Repair all projects"
    echo "  pj-repair laravel myapp         # Repair specific project"
    echo "  pj-upgrade-php laravel myapp 8.5 # Upgrade PHP to 8.5"
    echo "  pj-change-php laravel myapp     # Interactive PHP version change"
    echo "  pj-php-list                     # List all PHP versions"
    echo "  pj-repair-ssl ci3 myapp         # Repair SSL certificate"
    echo "  pj-check-config laravel myapp   # Check project configuration"
    echo ""
    echo -e "${PURPLE}PROJECT TYPES:${NC}"
    echo "  laravel, nextjs, ci3 (codeigniter3)"
    echo ""
    echo -e "${CYAN}NEXT.JS HYBRID ENVIRONMENT:${NC}"
    echo "  🎯 ${GREEN}Production Mode${NC} - Static files, always accessible"
    echo "     → pj-production-nextjs <name>"
    echo "     → Access: http://domain.test (instantly)"
    echo "     → Features: Fast, no server needed, auto-build available"
    echo ""
    echo "  🔧 ${BLUE}Development Mode${NC} - Live server with hot reload"
    echo "     → pj-development-nextjs <name>"
    echo "     → Access: http://domain.test (proxy) or http://localhost:3001"
    echo "     → Features: Hot reload, debug tools, instant updates"
    echo ""
    echo "  🔄 ${YELLOW}Auto-build Watcher${NC} - Build on file changes"
    echo "     → pj-watch-nextjs <name>"
    echo "     → Requires: Production mode"
    echo "     → Features: Automatic rebuilds, browser refresh ready"
    echo ""
    echo -e "${RED}TROUBLESHOOTING GUIDE:${NC}"
    echo "  ❌ 'Could not connect to server'"
    echo "     → pj-troubleshoot domain.test"
    echo "     → pj-restart-services"
    echo "     → pj-network-status"
    echo ""
    echo "  ❌ 'Primary script unknown'"
    echo "     → pj-fix-home-permission"
    echo "     → pj-fix-permissions <type> <name>"
    echo "     → pj-verify-access <type> <name>"
    echo ""
    echo "  ❌ Next.js not working"
    echo "     → pj-production-nextjs <name> (for static mode)"
    echo "     → pj-development-nextjs <name> (for dev server)"
    echo "     → Check mode: pj-network-status"
    echo ""
    echo "  ❌ SSL certificate warnings"
    echo "     → pj-trust-setup"
    echo "     → pj-mkcert-setup"
    echo "     → pj-repair-ssl <type> <name>"
    echo ""
    echo "  ❌ Nginx configuration errors"
    echo "     → pj-fix <type> <name>"
    echo "     → pj-troubleshoot domain.test"
    echo "     → pj-check-config <type> <name>"
    echo ""
    echo -e "${GREEN}QUICK START FOR NEXT.JS:${NC}"
    echo "  1. pj-create nextjs mynextapp mynextapp.test"
    echo "  2. cd ~/Projects/www/nextjs/mynextapp"
    echo "  3. npm install"
    echo "  4. Choose your mode:"
    echo "     - pj-production-nextjs mynextapp + pj-watch-nextjs mynextapp"
    echo "     - OR pj-development-nextjs mynextapp + npm run dev"
    echo "  5. Access: http://mynextapp.test"
}

# Main function dispatcher
project_manager() {
    case $1 in
        "create")
            create_project $2 $3 $4 $5 $6
            ;;
        "setup")
            setup_existing_project $2 $3 $4 $5
            ;;
        "list")
            show_header
            list_projects
            ;;
        "code")
            code_project $2 $3
            ;;
        "delete")
            delete_project $2 $3 $4
            ;;
        "exists")
            check_project_exists $2 $3
            ;;
        "fix")
            fix_project $2 $3 $4
            ;;
        "enable-ssl")
            enable_ssl $2 $3 $4
            ;;
        "disable-ssl")
            disable_ssl $2 $3 $4
            ;;
        "mkcert-setup")
            setup_mkcert
            ;;
        "trust-setup")
            setup_browser_trust
            ;;
        "symlink")
            setup_symlink
            ;;
        "info")
            show_environment_info
            ;;
        "env")
            show_header
            echo -e "${CYAN}CURRENT ENVIRONMENT PATHS${NC}"
            echo "PROJECTS_ROOT: $PROJECTS_ROOT"
            echo "CERT_ROOT: $CERT_ROOT"
            echo "HOSTS_FILE: $HOSTS_FILE"
            echo "ENVIRONMENT: $ENVIRONMENT"
            ;;
        "setup-alias"|"alias")
            setup_aliases
            ;;
        "alias-status")
            show_alias_status
            ;;
        "fix-permissions")
            fix_permissions $2 $3
            ;;
        "verify-access")
            verify_project_access $2 $3
            ;;
        "fix-home-permission")
            fix_home_permission
            ;;
        "troubleshoot")
            troubleshoot_connection $2
            ;;
        "network-status")
            show_network_status
            ;;
        "restart-services")
            restart_services
            ;;
        "production-nextjs")
            switch_nextjs_production $2
            ;;
        "development-nextjs")
            switch_nextjs_development $2
            ;;
        "watch-nextjs")
            start_nextjs_watcher $2
            ;;
        "build-nextjs")
            build_nextjs_production $2
            ;;
        "help"|"--help"|"-h")
            show_detailed_help
            ;;
        "repair")
            repair_nginx_config $2 $3
            ;;
        "upgrade-php")
            upgrade_php_version $2 $3 $4
            ;;
        "change-php")
            change_php_version $2 $3
            ;;
        "php-list")
            list_php_versions
            ;;
        "repair-ssl")
            repair_ssl $2 $3 $4
            ;;
        "check-config")
            check_config $2 $3
            ;;
        *)
            # Jika tidak ada argumen, show help
            if [ $# -eq 0 ]; then
                show_detailed_help
            else
                echo -e "${ICON_ERROR} Unknown command: $1"
                echo "Use 'project help' for available commands"
                echo "Or 'project setup-alias' to install quick aliases"
            fi
            ;;
    esac
}

# Run the project manager
project_manager "$@"