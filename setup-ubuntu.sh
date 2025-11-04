#!/bin/bash

# Script Setup Environment Development
# Oleh: DS
# Description: Install Git, Nginx, MariaDB, PHP 8.2+, Node.js, Composer, dan mkcert

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Script harus dijalankan sebagai root atau menggunakan sudo"
    exit 1
fi

# Update system
log_info "Memperbarui sistem..."
apt update && apt upgrade -y

# Install dependencies
log_info "Menginstall dependencies..."
apt install -y curl wget gnupg software-properties-common ca-certificates apt-transport-https lsb-release

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 0. Install Git
log_info "Menginstall Git..."
if command_exists git; then
    log_warn "Git sudah terinstall (versi: $(git --version))"
else
    apt install -y git
    log_info "Git berhasil diinstall (versi: $(git --version))"
fi

# 1. Install Nginx Latest
log_info "Menginstall Nginx..."
if command_exists nginx; then
    log_warn "Nginx sudah terinstall"
else
    apt install -y nginx
    systemctl enable nginx
    systemctl start nginx
    log_info "Nginx berhasil diinstall"
fi

# 2. Install MariaDB Latest
log_info "Menginstall MariaDB..."
if command_exists mysql; then
    log_warn "MariaDB/MySQL sudah terinstall"
else
    # Add MariaDB repository
    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash
    apt update
    apt install -y mariadb-server mariadb-client
    systemctl enable mariadb
    systemctl start mariadb
    
    # Secure MariaDB installation
    log_info "Menjalankan mysql_secure_installation..."
    mysql_secure_installation <<EOF

y
y
y
y
y
EOF
    log_info "MariaDB berhasil diinstall"
fi

# 3. Install PHP 8.2+ dengan ekstensi lengkap
log_info "Menginstall PHP 8.2+ dan ekstensi..."
if command_exists php; then
    PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
    log_warn "PHP sudah terinstall (versi: $PHP_VERSION)"
else
    # Add PHP repository
    apt install -y software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt update
    
    # Install PHP 8.2 dengan ekstensi lengkap
    apt install -y php8.2 php8.2-fpm php8.2-common php8.2-mysql \
    php8.2-xml php8.2-xmlrpc php8.2-curl php8.2-gd php8.2-imagick \
    php8.2-cli php8.2-dev php8.2-imap php8.2-mbstring php8.2-opcache \
    php8.2-soap php8.2-zip php8.2-bcmath php8.2-intl php8.2-readline
    
    # Install PHP 8.3 juga (optional)
    apt install -y php8.3 php8.3-fpm php8.3-common php8.3-mysql \
    php8.3-xml php8.3-curl php8.3-gd php8.3-mbstring \
    php8.3-zip php8.3-bcmath
    
    systemctl enable php8.2-fpm
    systemctl start php8.2-fpm
    log_info "PHP 8.2 berhasil diinstall"
fi

# 4. Install Node.js dan NPM
log_info "Menginstall Node.js dan NPM..."
if command_exists node; then
    log_warn "Node.js sudah terinstall (versi: $(node -v))"
else
    # Using NodeSource repository for latest Node.js
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
    
    # Update npm to latest
    npm install -g npm@latest
    log_info "Node.js berhasil diinstall (versi: $(node -v))"
fi

# 5. Install Composer
log_info "Menginstall Composer..."
if command_exists composer; then
    log_warn "Composer sudah terinstall (versi: $(composer --version 2>/dev/null | head -n 1))"
else
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    php composer-setup.php
    php -r "unlink('composer-setup.php');"
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
    log_info "Composer berhasil diinstall"
fi

# 6. Install mkcert untuk HTTPS localhost
log_info "Menginstall mkcert..."
if command_exists mkcert; then
    log_warn "mkcert sudah terinstall"
else
    # Install mkcert
    apt install -y libnss3-tools
    wget -O mkcert https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64
    chmod +x mkcert
    mv mkcert /usr/local/bin/
    
    # Setup local CA
    mkcert -install
    
    log_info "mkcert berhasil diinstall"
fi

# Test Nginx dengan curl
log_info "Testing Nginx dengan curl..."
sleep 2  # Beri waktu untuk Nginx start

if curl -s http://localhost > /dev/null; then
    log_info "✅ Nginx berhasil diinstall dan berjalan - Test curl localhost: SUKSES"
else
    log_error "❌ Nginx test gagal - Service mungkin tidak berjalan"
    log_info "Memeriksa status Nginx..."
    systemctl status nginx --no-pager
fi

# Display installation summary
log_info "=== INSTALASI SELESAI ==="
log_info "Berikut yang telah diinstall:"
echo "1. Git: $(git --version 2>/dev/null | head -n 1 || echo 'Terinstall')"
echo "2. Nginx: $(nginx -v 2>&1)"
echo "3. MariaDB: $(mysql --version 2>/dev/null || echo 'Terinstall')"
echo "4. PHP: $(php -v 2>/dev/null | head -n 1 || echo 'Terinstall')"
echo "5. Node.js: $(node -v 2>/dev/null || echo 'Terinstall')"
echo "6. NPM: $(npm -v 2>/dev/null || echo 'Terinstall')"
echo "7. Composer: $(composer --version 2>/dev/null | head -n 1 || echo 'Terinstall')"
echo "8. mkcert: $(mkcert -version 2>/dev/null || echo 'Terinstall')"

log_info "=== TESTING MANUAL ==="
echo "Test Nginx:    curl -I http://localhost"
echo "Test PHP:      php -v"
echo "Test MySQL:    sudo mysql -e 'SHOW DATABASES;'"
echo "Test Node.js:  node -v"
echo "Test Composer: composer --version"
echo "Test Git:      git --version"

log_info "=== PERINTAH UMUM ==="
echo "git clone <repository>"
echo "composer install"
echo "npm install"
echo "sudo systemctl restart nginx"
echo "sudo systemctl restart php8.2-fpm"
echo "sudo systemctl restart mariadb"

log_info "Setup environment selesai!"
