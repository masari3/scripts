#!/bin/bash

# =============================================
# DEVELOPMENT ENVIRONMENT SETUP SCRIPT
# Description: Install Git, Nginx, MariaDB, PHP 8.2+, Node.js, Composer, mkcert, and VS Code
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root or with sudo"
    echo "Usage: sudo ./setup-ubuntu.sh"
    exit 1
fi

# Show welcome message
echo -e "${PURPLE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║               DEVELOPMENT ENVIRONMENT SETUP                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "This script will install the following components:"
echo "  ${ICON_CODE} Git Version Control"
echo "  ${ICON_SERVER} Nginx Web Server"
echo "  ${ICON_DATABASE} MariaDB Database Server"
echo "  ${ICON_CODE} PHP 8.2+ with Extensions"
echo "  ${ICON_NETWORK} Node.js & npm"
echo "  ${ICON_CODE} Composer (PHP)"
echo "  ${ICON_SECURITY} mkcert for HTTPS"
echo "  ${ICON_CODE} Visual Studio Code"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Update system
log_step "Updating system packages..."
apt update && apt upgrade -y
log_info "System packages updated successfully"

# Install dependencies
log_step "Installing dependencies..."
apt install -y curl wget gnupg software-properties-common ca-certificates apt-transport-https lsb-release
log_info "Dependencies installed successfully"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 0. Install Git
log_step "Installing Git..."
if command_exists git; then
    log_warn "Git already installed: $(git --version)"
else
    apt install -y git
    log_info "Git installed successfully: $(git --version)"
fi

# 1. Install Nginx Latest
log_step "Installing Nginx..."
if command_exists nginx; then
    log_warn "Nginx already installed"
else
    apt install -y nginx
    systemctl enable nginx
    systemctl start nginx
    log_info "Nginx installed and started successfully"
fi

# 2. Install MariaDB Latest
log_step "Installing MariaDB..."
if command_exists mysql; then
    log_warn "MariaDB/MySQL already installed"
else
    # Add MariaDB repository
    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash
    apt update
    apt install -y mariadb-server mariadb-client
    systemctl enable mariadb
    systemctl start mariadb
    
    # Secure MariaDB installation
    log_step "Securing MariaDB installation..."
    mysql_secure_installation <<EOF

y
y
y
y
y
EOF
    log_info "MariaDB installed and secured successfully"
fi

# 3. Install PHP 8.2+ with extensions
log_step "Installing PHP 8.2+ with extensions..."
if command_exists php; then
    PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
    log_warn "PHP already installed: version $PHP_VERSION"
else
    # Add PHP repository
    apt install -y software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt update
    
    # Install PHP 8.2 with comprehensive extensions
    log_step "Installing PHP 8.2 with extensions..."
    apt install -y php8.2 php8.2-fpm php8.2-common php8.2-mysql \
    php8.2-xml php8.2-xmlrpc php8.2-curl php8.2-gd php8.2-imagick \
    php8.2-cli php8.2-dev php8.2-imap php8.2-mbstring php8.2-opcache \
    php8.2-soap php8.2-zip php8.2-bcmath php8.2-intl php8.2-readline
    
    # Install PHP 8.3 as alternative
    log_step "Installing PHP 8.3 as alternative..."
    apt install -y php8.3 php8.3-fpm php8.3-common php8.3-mysql \
    php8.3-xml php8.3-curl php8.3-gd php8.3-mbstring \
    php8.3-zip php8.3-bcmath
    
    systemctl enable php8.2-fpm
    systemctl start php8.2-fpm
    log_info "PHP 8.2 installed successfully: $(php8.2 -v | head -n 1)"
fi

# 4. Install Node.js and NPM
log_step "Installing Node.js and npm..."
if command_exists node; then
    log_warn "Node.js already installed: $(node -v)"
else
    # Using NodeSource repository for latest Node.js
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
    
    # Update npm to latest
    npm install -g npm@latest
    log_info "Node.js installed successfully: $(node -v)"
    log_info "npm installed: $(npm -v)"
fi

# 5. Install Composer
log_step "Installing Composer..."
if command_exists composer; then
    log_warn "Composer already installed: $(composer --version 2>/dev/null | head -n 1)"
else
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    php composer-setup.php
    php -r "unlink('composer-setup.php');"
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
    log_info "Composer installed successfully"
fi

# 6. Install mkcert for HTTPS localhost
log_step "Installing mkcert for local HTTPS..."
if command_exists mkcert; then
    log_warn "mkcert already installed"
else
    # Install mkcert
    apt install -y libnss3-tools
    wget -O mkcert https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64
    chmod +x mkcert
    mv mkcert /usr/local/bin/
    
    # Setup local CA
    mkcert -install
    log_info "mkcert installed and local CA setup completed"
fi

# 7. Install Visual Studio Code
log_step "Installing Visual Studio Code..."
if command_exists code; then
    log_warn "VS Code already installed: $(code --version 2>/dev/null | head -n 1 || echo 'Installed')"
else
    # Install dependencies
    apt install -y wget gpg apt-transport-https
    
    # Download Microsoft GPG key
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    
    # Add VS Code repository
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
    tee /etc/apt/sources.list.d/vscode.list > /dev/null
    
    # Update package list and install
    apt update
    apt install -y code
    
    # Cleanup
    rm -f packages.microsoft.gpg
    
    log_info "VS Code installed successfully: $(code --version | head -n 1)"
    
    # Install common VS Code extensions
    log_step "Installing common VS Code extensions..."
    
    # PHP extensions
    code --install-extension bmewburn.vscode-intelephense-client --force
    code --install-extension felixfbecker.php-debug --force
    code --install-extension felixfbecker.php-pack --force
    
    # JavaScript/Node.js extensions
    code --install-extension ms-vscode.vscode-typescript-next --force
    code --install-extension ms-vscode.vscode-json --force
    
    # Web development
    code --install-extension ritwickdey.liveserver --force
    code --install-extension bradlc.vscode-tailwindcss --force
    
    # Git
    code --install-extension eamodio.gitlens --force
    
    # Themes & Icons
    code --install-extension pkief.material-icon-theme --force
    
    log_info "VS Code extensions installed successfully"
fi

# Configure services and permissions
log_step "Configuring services and permissions..."
mkdir -p /var/www/projects
mkdir -p /var/log/nginx/projects
chown -R www-data:www-data /var/www
chmod -R 755 /var/www
log_info "Services configured successfully"

# Test Nginx with curl
log_step "Testing Nginx service..."
sleep 2  # Give Nginx time to start

if curl -s http://localhost > /dev/null; then
    log_info "${ICON_CHECK} Nginx installed and running - curl test: SUCCESS"
else
    log_error "${ICON_ERROR} Nginx test failed - Service might not be running"
    log_info "Checking Nginx status..."
    systemctl status nginx --no-pager
fi

# Display installation summary
echo ""
echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                     INSTALLATION SUMMARY                       ║${NC}"
echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
log_info "The following components have been installed:"
echo "  ${ICON_CODE}  Git: $(git --version 2>/dev/null | head -n 1 || echo 'Installed')"
echo "  ${ICON_SERVER}  Nginx: $(nginx -v 2>&1)"
echo "  ${ICON_DATABASE}  MariaDB: $(mysql --version 2>/dev/null || echo 'Installed')"
echo "  ${ICON_CODE}  PHP: $(php -v 2>/dev/null | head -n 1 || echo 'Installed')"
echo "  ${ICON_NETWORK}  Node.js: $(node -v 2>/dev/null || echo 'Installed')"
echo "  ${ICON_NETWORK}  npm: $(npm -v 2>/dev/null || echo 'Installed')"
echo "  ${ICON_CODE}  Composer: $(composer --version 2>/dev/null | head -n 1 || echo 'Installed')"
echo "  ${ICON_SECURITY}  mkcert: $(mkcert -version 2>/dev/null || echo 'Installed')"
echo "  ${ICON_CODE}  VS Code: $(code --version 2>/dev/null | head -n 1 || echo 'Installed')"

echo ""
log_info "MANUAL TESTING COMMANDS:"
echo "  Test Nginx:    curl -I http://localhost"
echo "  Test PHP:      php -v"
echo "  Test MySQL:    sudo mysql -e 'SHOW DATABASES;'"
echo "  Test Node.js:  node -v"
echo "  Test Composer: composer --version"
echo "  Test Git:      git --version"
echo "  Test VS Code:  code --version"

echo ""
log_info "COMMON DEVELOPMENT COMMANDS:"
echo "  git clone <repository>"
echo "  composer install"
echo "  npm install"
echo "  sudo systemctl restart nginx"
echo "  sudo systemctl restart php8.2-fpm"
echo "  sudo systemctl restart mariadb"

echo ""
echo -e "${GREEN}${ICON_SUCCESS} DEVELOPMENT ENVIRONMENT SETUP COMPLETED SUCCESSFULLY!${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  - Use project-manager.sh to create your first project"
echo "  - Example: ./project-manager.sh create laravel myapp myapp.test"
echo "  - Open VS Code: code /var/www/projects/"
echo ""
