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
        ""
    )
    
    # Append aliases to shell config
    for alias_line in "${aliases[@]}"; do
        echo "$alias_line" >> "$shell_config"
    done
    
    echo -e "${ICON_CHECK} Aliases added to $shell_config"
    echo ""
    echo -e "${CYAN}AVAILABLE ALIASES:${NC}"
    echo "  project, pj          - Main project manager"
    echo "  pj-create            - Create new project"
    echo "  pj-setup             - Setup existing project"
    echo "  pj-list              - List all projects"
    echo "  pj-code              - Open project in VS Code"
    echo "  pj-delete            - Delete project"
    echo "  pj-mkcert            - Setup mkcert for SSL"
    echo "  pj-trust             - Setup browser trust"
    echo "  pj-symlink           - Setup projects symlink"
    echo "  pj-info              - Show environment info"
    echo "  pj-env               - Show environment paths"
    echo "  pj-exists            - Check if project exists"
    echo "  pj-fix               - Fix project configuration"
    echo "  pj-enable-ssl        - Enable SSL for project"
    echo "  pj-disable-ssl       - Disable SSL for project"
    echo "  pj-alias             - Setup aliases (this command)"
    echo "  pj-fix-permissions   - Fix project permissions"
    echo "  pj-verify-access     - Verify project web accessibility"
    echo "  pj-fix-home-permission - Fix home directory permission"
    echo "  pj-troubleshoot      - Troubleshoot connection issues"
    echo "  pj-network-status    - Show network and service status"
    echo "  pj-restart-services  - Restart web services"
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

# Function to detect PHP version
detect_php_version() {
    # Check for available PHP versions
    if [ -S "/var/run/php/php8.2-fpm.sock" ]; then
        echo "8.2"
    elif [ -S "/var/run/php/php8.1-fpm.sock" ]; then
        echo "8.1"
    elif [ -S "/var/run/php/php7.4-fpm.sock" ]; then
        echo "7.4"
    else
        # Fallback: check which PHP-FPM services are available
        if systemctl is-active --quiet php8.2-fpm; then
            echo "8.2"
        elif systemctl is-active --quiet php8.1-fpm; then
            echo "8.1"
        elif systemctl is-active --quiet php7.4-fpm; then
            echo "7.4"
        else
            echo "8.2"  # Default fallback
        fi
    fi
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
                connection="unix:/var/run/php/php${php_version}-fpm.sock"
            fi
            ;;
        "native")
            # Native: Always use sockets (more efficient)
            connection="unix:/var/run/php/php${php_version}-fpm.sock"
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

# Function to setup symlink
setup_symlink() {
    echo -e "${ICON_LINK} Setting up symlink..."
    
    # Remove old symlink if exists
    sudo rm -f /var/www/projects
    
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
    
    # Detect PHP version and connection
    local php_connection=$(get_php_fpm_connection)
    local php_version=$(detect_php_version)
    
    echo -e "${ICON_INFO} Detected PHP: $php_version"
    echo -e "${ICON_INFO} PHP-FPM Connection: $php_connection"
    
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
        
        if generate_ssl_cert "$domain"; then
            ssl_cert="$CERT_ROOT/$domain.pem"
            ssl_key="$CERT_ROOT/$domain-key.pem"
            echo -e "${ICON_CHECK} SSL certificate ready"
        else
            echo -e "${ICON_WARN} SSL certificate generation failed, continuing without SSL"
            enable_ssl="false"
        fi
    fi
    
    # Create nginx config with or without SSL
    if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ] && [ -f "$ssl_cert" ] && [ -f "$ssl_key" ]; then
        # Config with SSL - FIXED: Use actual value, not variable
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
    
    # SSL certificates
    ssl_certificate $ssl_cert;
    ssl_certificate_key $ssl_key;
    
    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;
    
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
        echo -e "${ICON_CHECK} SSL configuration applied"
    else
        # Config without SSL (HTTP only) - FIXED: Use actual value, not variable
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
        echo -e "${ICON_CHECK} HTTP-only configuration applied"
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
    echo -e "${ICON_CODE} PHP: $php_version via $php_connection"
    if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ] && [ -f "$ssl_cert" ] && [ -f "$ssl_key" ]; then
        echo -e "${ICON_SECURITY} SSL: ENABLED"
        echo -e "${ICON_NETWORK} URLs: http://$domain → https://$domain"
    else
        echo -e "${ICON_SECURITY} SSL: DISABLED"
        echo -e "${ICON_NETWORK} URL: http://$domain"
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
    echo -e "${ICON_CODE} PHP Version: $(detect_php_version)"
    echo -e "${ICON_LINK} PHP-FPM Connection: $(get_php_fpm_connection)"
    echo ""
    
    # Test essential services
    echo -e "${CYAN}SERVICE STATUS${NC}"
    if systemctl is-active --quiet nginx; then
        echo -e "  ${ICON_CHECK} Nginx: RUNNING"
    else
        echo -e "  ${ICON_ERROR} Nginx: STOPPED"
    fi
    
    if systemctl is-active --quiet mariadb; then
        echo -e "  ${ICON_CHECK} MariaDB: RUNNING"
    else
        echo -e "  ${ICON_ERROR} MariaDB: STOPPED"
    fi
    
    if systemctl is-active --quiet php8.2-fpm; then
        echo -e "  ${ICON_CHECK} PHP 8.2 FPM: RUNNING"
    else
        echo -e "  ${ICON_WARN} PHP 8.2 FPM: INACTIVE"
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
    
    # Restart PHP-FPM services
    echo -e "${ICON_INFO} Restarting PHP-FPM services..."
    for version in 8.2 8.1 7.4; do
        if systemctl is-active --quiet "php${version}-fpm"; then
            sudo systemctl restart "php${version}-fpm"
            if systemctl is-active --quiet "php${version}-fpm"; then
                echo -e "   ${ICON_CHECK} PHP ${version} FPM restarted"
            else
                echo -e "   ${ICON_WARN} PHP ${version} FPM restart failed"
            fi
        fi
    done
    
    # Restart MariaDB if running
    if systemctl is-active --quiet mariadb; then
        echo -e "${ICON_INFO} Restarting MariaDB..."
        sudo systemctl restart mariadb
        if systemctl is-active --quiet mariadb; then
            echo -e "   ${ICON_CHECK} MariaDB restarted"
        else
            echo -e "   ${ICON_WARN} MariaDB restart failed"
        fi
    fi
    
    echo -e "${ICON_SUCCESS} All services restarted successfully!"
    echo ""
    echo -e "${CYAN}Current Service Status:${NC}"
    show_network_status
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
    echo ""
    echo -e "${YELLOW}QUICK ALIASES:${NC}"
    echo "  pj-create <type> <name> <domain> [ssl]"
    echo "  pj-setup <type> <name> <domain> [ssl]"
    echo "  pj-list"
    echo "  pj-code <type> <name>"
    echo "  pj-delete <type> <name> [remove-files]"
    echo "  pj-exists <type> <name>"
    echo "  pj-fix <type> <name> [domain]"
    echo "  pj-enable-ssl <type> <name> [domain]"
    echo "  pj-disable-ssl <type> <name> [domain]"
    echo "  pj-mkcert"
    echo "  pj-trust"
    echo "  pj-symlink"
    echo "  pj-info"
    echo "  pj-env"
    echo "  pj-alias"
    echo "  pj-fix-permissions"
    echo "  pj-verify-access"
    echo "  pj-fix-home-permission"
    echo "  pj-troubleshoot [domain]"
    echo "  pj-network-status"
    echo "  pj-restart-services"
    echo ""
    echo -e "${BLUE}EXAMPLES:${NC}"
    echo "  pj-create laravel myapp myapp.test"
    echo "  pj-create ci3 myapp myapp.test ssl"
    echo "  pj-setup laravel existing-app app.test"
    echo "  pj-exists ci3 myapp"
    echo "  pj-fix laravel myapp"
    echo "  pj-enable-ssl ci3 myapp"
    echo "  pj-troubleshoot myapp.test"
    echo "  pj-network-status"
    echo "  pj-restart-services"
    echo "  pj-list"
    echo "  pj-fix-home-permission"
    echo ""
    echo -e "${PURPLE}PROJECT TYPES:${NC}"
    echo "  laravel, nextjs, ci3 (codeigniter3)"
    echo ""
    echo -e "${CYAN}TROUBLESHOOTING GUIDE:${NC}"
    echo "  If website not accessible:"
    echo "  1. pj-troubleshoot domain.test    - Auto-diagnose connection issues"
    echo "  2. pj-network-status              - Check service status"
    echo "  3. pj-restart-services            - Restart Nginx & PHP-FPM"
    echo "  4. pj-fix-home-permission         - Fix permission issues"
    echo "  5. pj-fix-permissions <type> <name> - Fix project permissions"
    echo ""
    echo -e "${YELLOW}COMMON ISSUES & SOLUTIONS:${NC}"
    echo "  ❌ 'Could not connect to server'"
    echo "     → pj-troubleshoot domain.test"
    echo "     → pj-restart-services"
    echo ""
    echo "  ❌ 'Primary script unknown'"
    echo "     → pj-fix-home-permission"
    echo "     → pj-fix-permissions <type> <name>"
    echo "     → pj-verify-access <type> <name>"
    echo ""
    echo "  ❌ SSL certificate warnings"
    echo "     → pj-trust-setup"
    echo "     → pj-mkcert-setup"
    echo ""
    echo "  ❌ Nginx configuration errors"
    echo "     → pj-fix <type> <name>"
    echo "     → pj-troubleshoot domain.test"
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
        "help"|"--help"|"-h")
            show_detailed_help
            ;;
        *)
            # Jika tidak ada argumen, show help
            if [ $# -eq 0 ]; then
                show_detailed_help
            else
                echo -e "${ICON_ERROR} Unknown command: $1"
                echo "Use 'project help' for available commands"
            fi
            ;;
    esac
}

# Run the project manager
project_manager "$@"