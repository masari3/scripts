#!/bin/bash

# UPDATED PATHS - SESUAI DENGAN FIX YANG BEKERJA
PROJECTS_ROOT="/mnt/d/projects/www"
SCRIPTS_ROOT="/mnt/d/projects/scripts"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
HOSTS_FILE="/mnt/c/Windows/System32/drivers/etc/hosts"
CERT_ROOT="/mnt/d/projects/certs"

# Function to setup mkcert environment
setup_mkcert() {
    echo "🔐 Setting up mkcert for SSL certificates..."
    
    # Install mkcert jika belum ada
    if ! command -v mkcert &> /dev/null; then
        echo "📦 Installing mkcert..."
        sudo apt update
        sudo apt install libnss3-tools -y
        wget -O mkcert https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64
        chmod +x mkcert
        sudo mv mkcert /usr/local/bin/
    fi
    
    # Setup local CA jika belum ada
    if [ ! -f "$HOME/.local/share/mkcert/rootCA.pem" ]; then
        echo "📝 Creating local Certificate Authority..."
        mkcert -install
    fi
    
    # Create certs directory jika belum ada
    mkdir -p "$CERT_ROOT"
    
    echo "✅ mkcert setup completed"
}

# Function to setup browser trust for mkcert
setup_browser_trust() {
    echo "🔐 Setting up browser trust for mkcert..."
    
    # Setup mkcert jika belum
    setup_mkcert
    
    # Pastikan certs directory ada
    mkdir -p "$CERT_ROOT"
    
    # Export root CA
    local root_ca_path="$HOME/.local/share/mkcert/rootCA.pem"
    
    if [ ! -f "$root_ca_path" ]; then
        echo "❌ mkcert root CA not found"
        return 1
    fi
    
    # Copy root CA to certs directory
    cp "$root_ca_path" "$CERT_ROOT/rootCA.pem"
    
    # Convert to .crt format untuk Windows
    openssl x509 -outform der -in "$root_ca_path" -out "$CERT_ROOT/rootCA.crt" 2>/dev/null
    
    echo "✅ Root CA exported:"
    echo "   PEM: $CERT_ROOT/rootCA.pem"
    echo "   CRT: $CERT_ROOT/rootCA.crt"
    echo ""
    echo "📝 INSTRUCTIONS TO TRUST CERTIFICATE:"
    echo "====================================="
    echo "1. Open File Explorer and go to: D:\\projects\\certs\\"
    echo "2. Double-click 'rootCA.crt'"
    echo "3. Click 'Install Certificate'"
    echo "4. Choose 'Current User' or 'Local Machine'"
    echo "5. Select 'Place all certificates in the following store'"
    echo "6. Click 'Browse' and select 'Trusted Root Certification Authorities'"
    echo "7. Click 'OK' and 'Finish'"
    echo "8. RESTART YOUR BROWSER"
    echo ""
    echo "🔍 After installation, SSL warnings should disappear!"
    
    # Create PowerShell script untuk auto-install
    cat > "$CERT_ROOT/trust-certificate.ps1" << 'EOF'
# trust-certificate.ps1 - Run as Administrator
param([switch]$CurrentUser = $true)

$CertPath = "D:\projects\certs\rootCA.crt"

if (-not (Test-Path $CertPath)) {
    Write-Host "❌ Certificate file not found: $CertPath" -ForegroundColor Red
    exit 1
}

try {
    $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
    
    if ($CurrentUser) {
        $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "CurrentUser")
    } else {
        $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
    }
    
    $Store.Open("ReadWrite")
    $Store.Add($Cert)
    $Store.Close()
    
    Write-Host "✅ Certificate installed to Trusted Root Certification Authorities" -ForegroundColor Green
    Write-Host "💡 Please restart your browser" -ForegroundColor Yellow
} catch {
    Write-Host "❌ Failed to install certificate: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Try running PowerShell as Administrator" -ForegroundColor Yellow
}
EOF

    echo "📁 PowerShell script created: $CERT_ROOT/trust-certificate.ps1"
    echo "💡 Run in PowerShell Admin: .\trust-certificate.ps1"
}

# Function to generate SSL certificate for domain
generate_ssl_cert() {
    local domain=$1
    
    if [ -z "$domain" ]; then
        echo "❌ Domain is required for SSL certificate"
        return 1
    fi
    
    echo "🔐 Generating SSL certificate for: $domain"
    
    # Setup mkcert jika belum
    setup_mkcert
    
    # Pastikan certs directory ada
    mkdir -p "$CERT_ROOT"
    
    # Generate certificate di certs directory
    cd "$CERT_ROOT"
    
    # Hapus certificate lama jika ada (termasuk yang +1, +2, dll)
    rm -f "$domain"*.pem
    rm -f "$domain"-key*.pem
    
    # Generate certificate dengan nama yang konsisten
    if mkcert "$domain" "www.$domain" "localhost.$domain"; then
        # Cari file certificate yang baru dibuat (bisa dengan +number)
        local cert_file=$(ls -1 | grep -E "^${domain}(\+[0-9]+)?\.pem$" | head -1)
        local key_file=$(ls -1 | grep -E "^${domain}(\+[0-9]+)?-key\.pem$" | head -1)
        
        if [ -n "$cert_file" ] && [ -n "$key_file" ]; then
            # Rename file ke nama yang konsisten
            mv "$cert_file" "$domain.pem"
            mv "$key_file" "$domain-key.pem"
            
            echo "✅ SSL certificate generated:"
            echo "   Cert: $CERT_ROOT/$domain.pem"
            echo "   Key:  $CERT_ROOT/$domain-key.pem"
            return 0
        else
            echo "❌ Certificate files not found after generation"
            echo "   Available files:"
            ls -la *.pem 2>/dev/null || echo "   No .pem files found"
            return 1
        fi
    else
        echo "❌ Failed to generate SSL certificate"
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
    
    # Check if socket exists for detected version
    if [ -S "/var/run/php/php${php_version}-fpm.sock" ]; then
        echo "unix:/var/run/php/php${php_version}-fpm.sock"
    else
        # Fallback to TCP
        echo "127.0.0.1:9000"
    fi
}

# Function to show PHP version information
show_php_info() {
    echo "🔍 PHP Version Information"
    echo "========================="
    
    # Check PHP CLI version
    echo "📟 PHP CLI:"
    php -v 2>/dev/null | head -1 || echo "❌ PHP CLI not found"
    
    # Check available PHP-FPM versions
    echo ""
    echo "🚀 PHP-FPM Services:"
    for version in 8.2 8.1 7.4; do
        if systemctl is-active --quiet "php${version}-fpm"; then
            echo "   ✅ php${version}-fpm: ACTIVE"
        elif systemctl is-enabled --quiet "php${version}-fpm"; then
            echo "   ❌ php${version}-fpm: INSTALLED but not active"
        else
            echo "   ⚠️  php${version}-fpm: NOT FOUND"
        fi
    done
    
    # Check sockets
    echo ""
    echo "🔌 PHP-FPM Sockets:"
    ls -la /var/run/php/ 2>/dev/null | grep sock || echo "   No sockets found"
    
    # Detected version
    echo ""
    echo "🎯 Auto-detected:"
    echo "   Version: $(detect_php_version)"
    echo "   Connection: $(get_php_fpm_connection)"
}

# Function to setup symlink
setup_symlink() {
    echo "🔗 Setting up symlink..."
    
    # Hapus symlink lama jika ada
    sudo rm -f /var/www/projects
    
    # Buat symlink ke D:\projects\www
    sudo ln -s "$PROJECTS_ROOT" /var/www/projects
    
    echo "✅ Symlink created: /var/www/projects -> $PROJECTS_ROOT"
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
    if powershell.exe -Command "
        \$content = Get-Content 'C:\Windows\System32\drivers\etc\hosts' -ErrorAction SilentlyContinue
        if (\$content -match \"127.0.0.1 $domain\") { exit 0 } else { exit 1 }
    " 2>/dev/null; then
        return 0  # Exists in hosts
    else
        return 1  # Not in hosts
    fi
}

# Function to create new project OR setup existing project
create_project() {
    local project_type=$1
    local project_name=$2
    local domain=$3
    local force_recreate=${4:-false}
    local enable_ssl=${5:-false}
    
    if [ -z "$project_type" ] || [ -z "$project_name" ] || [ -z "$domain" ]; then
        echo "Usage: create_project <laravel|nextjs|codeigniter3> <project-name> <domain> [force] [ssl]"
        echo "Example: create_project laravel myapp myapp.test"
        echo "Example: create_project laravel myapp myapp.test force ssl"
        return 1
    fi
    
    local project_path="$PROJECTS_ROOT/$project_type/$project_name"
    
    # Check if project already exists
    if project_exists "$project_type" "$project_name"; then
        echo "📁 Project already exists: $project_path"
        
        if [ "$force_recreate" = "force" ]; then
            echo "🔄 Force recreating nginx configuration..."
        else
            echo "ℹ️  Using existing project. To recreate nginx config, use 'force' parameter"
            echo "   Example: create_project $project_type $project_name $domain force"
            
            # Just setup nginx config without creating directories
            setup_nginx_config "$project_type" "$project_name" "$domain" "$enable_ssl"
            return 0
        fi
    fi
    
    echo "🚀 Creating $project_type project: $project_name"
    
    # Create project directory (only if not exists or force)
    if [ ! -d "$project_path" ] || [ "$force_recreate" = "force" ]; then
        mkdir -p "$project_path"
        echo "✅ Created directory: $project_path"
        
        # Create framework-specific default structure
        create_project_structure "$project_type" "$project_name"
    fi
    
    # Setup nginx configuration
    setup_nginx_config "$project_type" "$project_name" "$domain" "$enable_ssl"
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
            echo "✅ Created CodeIgniter 3 folder structure"
            ;;
        "laravel")
            # Laravel will be installed via composer later
            echo "📝 Laravel project ready for composer create-project"
            ;;
        "nextjs")
            # NextJS will be installed via npm later
            echo "📝 NextJS project ready for create-next-app"
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
        echo "⚠️  Domain $domain already configured in nginx"
        echo "   Overwriting existing configuration..."
        sudo rm -f "$NGINX_AVAILABLE/$domain"
        sudo rm -f "$NGINX_ENABLED/$domain"
    fi
    
    # Detect PHP version and connection
    local php_connection=$(get_php_fpm_connection)
    local php_version=$(detect_php_version)
    
    echo "🔍 Detected PHP: $php_version"
    echo "🔗 PHP-FPM Connection: $php_connection"
    
    # UPDATED: Define correct root paths for each project type
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
            echo "❌ Unknown project type: $project_type"
            return 1
            ;;
    esac
    
    echo "📁 Nginx root path: $nginx_root_path"
    
    # Generate SSL certificate jika enable_ssl
    local ssl_cert=""
    local ssl_key=""
    if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ]; then
        if generate_ssl_cert "$domain"; then
            ssl_cert="$CERT_ROOT/$domain.pem"
            ssl_key="$CERT_ROOT/$domain-key.pem"
            echo "🔐 SSL enabled for: $domain"
            
            # Verify certificate files exist
            if [ ! -f "$ssl_cert" ] || [ ! -f "$ssl_key" ]; then
                echo "❌ SSL certificate files not found, disabling SSL"
                enable_ssl="false"
            fi
        else
            echo "⚠️  SSL certificate generation failed, continuing without SSL"
            enable_ssl="false"
        fi
    fi
    
    # Create nginx config dengan atau tanpa SSL
    if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ]; then
        # Config dengan SSL - FIXED http2 directive
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
    http2 on;
    server_name $domain www.$domain;
    
    # SSL certificates
    ssl_certificate $ssl_cert;
    ssl_certificate_key $ssl_key;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    root $nginx_root_path;
    index index.php index.html index.htm;

    access_log /var/log/nginx/projects/${domain}-access.log;
    error_log /var/log/nginx/projects/${domain}-error.log;

    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass $php_connection;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    else
        # Config tanpa SSL (HTTP only)
        sudo tee "$NGINX_AVAILABLE/$domain" > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    
    # Prevent HTTPS redirect for local development
    if (\$scheme = https) {
        return 301 http://\$server_name\$request_uri;
    }
    
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
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    fi
    
    # Enable site
    sudo ln -sf "$NGINX_AVAILABLE/$domain" "$NGINX_ENABLED/$domain"
    
    # Add to Windows hosts file
    add_to_hosts "$domain"
    
    # Test and reload nginx
    if sudo nginx -t; then
        sudo service nginx reload
        echo "✅ Nginx configuration reloaded"
    else
        echo "❌ Nginx configuration test failed"
        echo "💡 Checking for common issues..."
        
        # Check if logs directory exists
        if [ ! -d "/var/log/nginx/projects" ]; then
            echo "📁 Creating missing logs directory..."
            sudo mkdir -p /var/log/nginx/projects
            sudo chmod 755 /var/log/nginx/projects
        fi
        
        # Check symlink
        if [ ! -L "/var/www/projects" ]; then
            echo "🔗 Symlink missing, creating..."
            setup_symlink
        fi
        
        # Check SSL certificates if SSL was enabled
        if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ]; then
            echo "🔐 Checking SSL certificates..."
            if [ ! -f "$ssl_cert" ]; then
                echo "❌ SSL certificate not found: $ssl_cert"
                echo "💡 Regenerating SSL certificate..."
                generate_ssl_cert "$domain"
            fi
            if [ ! -f "$ssl_key" ]; then
                echo "❌ SSL key not found: $ssl_key"
            fi
        fi
        
        return 1
    fi
    
    echo "🎉 Project setup completed!"
    echo "📁 Local Path: $PROJECTS_ROOT/$project_type/$project_name"
    echo "🌐 Nginx Path: $nginx_root_path"
    echo "🔗 PHP: $php_version via $php_connection"
    if [ "$enable_ssl" = "ssl" ] || [ "$enable_ssl" = "true" ]; then
        echo "🔐 SSL: ENABLED (https://$domain)"
        echo "🔗 URL: https://$domain"
    else
        echo "🔐 SSL: DISABLED"
        echo "🔗 URL: http://$domain"
    fi
}

# Function to add domain to Windows hosts (IMPROVED)
add_to_hosts() {
    local domain=$1
    
    if hosts_entry_exists "$domain"; then
        echo "ℹ️  Domain $domain already exists in hosts file"
        return 0
    fi
    
    echo "Adding $domain to Windows hosts file..."
    
    # Method 1: Try direct PowerShell command
    if powershell.exe -Command "Add-Content -Path 'C:\Windows\System32\drivers\etc\hosts' -Value '127.0.0.1 $domain' -Force" 2>/dev/null; then
        echo "✅ Added $domain to hosts file"
        return 0
    fi
    
    # Method 2: Manual instruction
    echo "❌ Failed to add $domain to hosts file automatically"
    echo "📝 Please manually add this line to C:\\Windows\\System32\\drivers\\etc\\hosts:"
    echo "   127.0.0.1 $domain"
    echo "   (Run Notepad as Administrator to edit hosts file)"
}

# Function to setup ONLY nginx config for existing project
setup_existing_project() {
    local project_type=$1
    local project_name=$2
    local domain=$3
    local enable_ssl=${4:-false}
    
    if [ -z "$project_type" ] || [ -z "$project_name" ] || [ -z "$domain" ]; then
        echo "Usage: setup_existing <laravel|nextjs|codeigniter3> <project-name> <domain> [ssl]"
        echo "Example: setup_existing laravel myapp myapp.test"
        echo "Example: setup_existing laravel myapp myapp.test ssl"
        return 1
    fi
    
    if ! project_exists "$project_type" "$project_name"; then
        echo "❌ Project not found: $PROJECTS_ROOT/$project_type/$project_name"
        echo "   Use 'create_project' to create a new project"
        return 1
    fi
    
    echo "🔧 Setting up nginx configuration for existing project: $project_name"
    setup_nginx_config "$project_type" "$project_name" "$domain" "$enable_ssl"
}

# Function to enable SSL for existing project
enable_ssl() {
    local project_type=$1
    local project_name=$2
    local domain=${3:-"${project_name}.test"}
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo "Usage: enable_ssl <laravel|nextjs|codeigniter3> <project-name> [domain]"
        echo "Example: enable_ssl laravel myapp myapp.test"
        return 1
    fi
    
    if ! project_exists "$project_type" "$project_name"; then
        echo "❌ Project not found: $PROJECTS_ROOT/$project_type/$project_name"
        return 1
    fi
    
    echo "🔐 Enabling SSL for: $domain"
    setup_nginx_config "$project_type" "$project_name" "$domain" "true"
}

# Function to disable SSL for existing project
disable_ssl() {
    local project_type=$1
    local project_name=$2
    local domain=${3:-"${project_name}.test"}
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo "Usage: disable_ssl <laravel|nextjs|codeigniter3> <project-name> [domain]"
        echo "Example: disable_ssl laravel myapp myapp.test"
        return 1
    fi
    
    if ! project_exists "$project_type" "$project_name"; then
        echo "❌ Project not found: $PROJECTS_ROOT/$project_type/$project_name"
        return 1
    fi
    
    echo "🔓 Disabling SSL for: $domain"
    setup_nginx_config "$project_type" "$project_name" "$domain" "false"
}

# Function to list all projects with status
list_projects() {
    echo "📂 Projects Overview - Correct Location: $PROJECTS_ROOT/<type>/<project>"
    echo "======================================================================"
    
    # Check each project type
    for project_type in laravel nextjs codeigniter3; do
        echo ""
        case $project_type in
            "laravel") echo "🚀 Laravel Projects:" ;;
            "nextjs") echo "⚡ NextJS Projects:" ;;
            "codeigniter3") echo "🔧 CodeIgniter 3 Projects:" ;;
        esac
        
        if [ -d "$PROJECTS_ROOT/$project_type" ]; then
            find "$PROJECTS_ROOT/$project_type" -maxdepth 1 -type d | tail -n +2 | while read dir; do
                local name=$(basename "$dir")
                local domain="${name}.test"
                local nginx_config="$NGINX_AVAILABLE/$domain"
                
                if [ -f "$nginx_config" ]; then
                    if grep -q "listen 443 ssl" "$nginx_config"; then
                        echo "   🔐 $name (https://$domain)"
                    else
                        echo "   🌐 $name (http://$domain)"
                    fi
                else
                    echo "   ❌ $name (no nginx config)"
                fi
            done
        else
            echo "   No $project_type projects"
        fi
    done
    
    # List all configured domains
    echo ""
    echo "🌐 Active Nginx Sites:"
    sudo nginx -T 2>/dev/null | grep "server_name " | grep -v "_\|default" | sort | uniq | head -10
    
    # Show symlink status
    echo ""
    echo "🔗 Symlink Status:"
    if [ -L "/var/www/projects" ]; then
        echo "   ✅ /var/www/projects -> $(readlink /var/www/projects)"
    else
        echo "   ❌ /var/www/projects symlink not found"
    fi
    
    # Show SSL status
    echo ""
    echo "🔐 SSL Certificates:"
    if [ -d "$CERT_ROOT" ]; then
        find "$CERT_ROOT" -name "*.pem" -not -name "*-key.pem" | while read cert; do
            local domain_name=$(basename "$cert" .pem)
            echo "   ✅ $domain_name"
        done
    else
        echo "   No SSL certificates found"
    fi
}

# Function to open project in VS Code
code_project() {
    local project_type=$1
    local project_name=$2
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo "Usage: code_project <laravel|nextjs|codeigniter3> <project-name>"
        return 1
    fi
    
    local project_path="$PROJECTS_ROOT/$project_type/$project_name"
    
    if [ -d "$project_path" ]; then
        code "$project_path"
        echo "✅ Opening $project_path in VS Code"
    else
        echo "❌ Project not found: $project_path"
        echo "   Available projects:"
        list_projects | grep -A 10 "$project_type" | grep "$project_name" || true
    fi
}

# Function to delete project
delete_project() {
    local project_type=$1
    local project_name=$2
    local remove_files=${3:-false}
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo "Usage: delete_project <laravel|nextjs|codeigniter3> <project-name> [remove-files]"
        echo "Examples:"
        echo "  delete_project laravel myapp              # Remove nginx config only"
        echo "  delete_project laravel myapp remove-files # Remove project completely"
        return 1
    fi
    
    local project_path="$PROJECTS_ROOT/$project_type/$project_name"
    local domain="${project_name}.test"
    
    # Remove nginx config
    if domain_exists "$domain"; then
        sudo rm -f "$NGINX_AVAILABLE/$domain"
        sudo rm -f "$NGINX_ENABLED/$domain"
        sudo service nginx reload
        echo "✅ Removed nginx config for: $domain"
    else
        echo "ℹ️  No nginx config found for: $domain"
    fi
    
    # Remove SSL certificates
    if [ -f "$CERT_ROOT/$domain.pem" ]; then
        rm -f "$CERT_ROOT/$domain.pem"
        rm -f "$CERT_ROOT/$domain-key.pem"
        echo "✅ Removed SSL certificates for: $domain"
    fi
    
    # Remove project files if requested
    if [ "$remove_files" = "remove-files" ] && [ -d "$project_path" ]; then
        rm -rf "$project_path"
        echo "✅ Removed project directory: $project_path"
    elif [ -d "$project_path" ]; then
        echo "ℹ️  Project files kept: $project_path"
    fi
    
    echo "🎉 Cleanup completed!"
}

# Function to fix project (recreate nginx config)
fix_project() {
    local project_type=$1
    local project_name=$2
    local domain=${3:-"${project_name}.test"}
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo "Usage: fix_project <laravel|nextjs|codeigniter3> <project-name> [domain]"
        return 1
    fi
    
    if ! project_exists "$project_type" "$project_name"; then
        echo "❌ Project not found: $PROJECTS_ROOT/$project_type/$project_name"
        return 1
    fi
    
    echo "🔧 Fixing project: $project_name"
    setup_nginx_config "$project_type" "$project_name" "$domain" "false"
}

# Function to fix permissions for NTFS
fix_ntfs_permissions() {
    local project_type=$1
    local project_name=$2
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo "Usage: fix_ntfs_permissions <laravel|nextjs|codeigniter3> <project-name>"
        return 1
    fi
    
    echo "🔧 Applying NTFS permission fix for: $project_type/$project_name"
    
    # For NTFS, we use TCP connection so no special permission needed
    echo "✅ NTFS projects use TCP connection - no special permissions needed"
    echo "💡 Using TCP connection to PHP-FPM on 127.0.0.1:9000"
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
        "enable-ssl")
            enable_ssl $2 $3 $4
            ;;
        "disable-ssl")
            disable_ssl $2 $3 $4
            ;;
        "mkcert-setup")
            setup_mkcert
            ;;
        "list")
            list_projects
            ;;
        "code")
            code_project $2 $3
            ;;
        "delete")
            delete_project $2 $3 $4
            ;;
        "fix")
            fix_project $2 $3 $4
            ;;
        "symlink")
            setup_symlink
            ;;
        "permissions")
            fix_ntfs_permissions $2 $3
            ;;
        "hosts")
            add_to_hosts $2
            ;;
        "exists")
            project_exists $2 $3 && echo "✅ Project exists" || echo "❌ Project not found"
            ;;
        "php-info")
            show_php_info
            ;;
        "path")
            echo "📁 Project Root: $PROJECTS_ROOT"
            echo "📁 Scripts Root: $SCRIPTS_ROOT"
            echo "🔗 Nginx Root: /var/www/projects -> $(readlink /var/www/projects 2>/dev/null || echo 'Not set')"
            echo "🔗 PHP-FPM: $(get_php_fpm_connection)"
            echo "🔐 Certificates: $CERT_ROOT"
            echo "📁 Nginx Paths:"
            echo "   - Laravel: /var/www/projects/laravel/{project}/public"
            echo "   - NextJS: /var/www/projects/nextjs/{project}"
            echo "   - CodeIgniter3: /var/www/projects/codeigniter3/{project}"
            ;;
        *)
            echo "🏗️  Project Manager v2.0 - WITH SSL SUPPORT"
            echo "=========================================="
            echo "📁 Project Location: $PROJECTS_ROOT/<type>/<project>"
            echo "📁 Scripts Location: $SCRIPTS_ROOT"
            echo "🔗 Symlink: /var/www/projects -> $PROJECTS_ROOT"
            echo "🔗 PHP-FPM: Auto-detected"
            echo "🔐 SSL: mkcert support"
            echo ""
            echo "Commands:"
            echo "  create <type> <name> <domain> [force] [ssl] - Create new project"
            echo "  setup <type> <name> <domain> [ssl]         - Setup nginx for existing project"
            echo "  enable-ssl <type> <name> [domain]          - Enable SSL for project"
            echo "  disable-ssl <type> <name> [domain]         - Disable SSL for project"
            echo "  mkcert-setup                               - Setup mkcert environment"
            echo "  list                                       - List all projects with status"
            echo "  code <type> <name>                         - Open project in VS Code"
            echo "  delete <type> <name> [remove-files]        - Remove nginx config (and files)"
            echo "  fix <type> <name> [domain]                 - Recreate nginx config"
            echo "  symlink                                    - Setup correct symlink"
            echo "  permissions <type> <name>                  - NTFS permission info"
            echo "  hosts <domain>                             - Add domain to hosts"
            echo "  exists <type> <name>                       - Check if project exists"
            echo "  php-info                                   - Show PHP version info"
            echo "  path                                       - Show all paths"
            echo ""
            echo "Project Types: laravel, nextjs, codeigniter3"
            echo ""
            echo "Examples:"
            echo "  project create laravel myapp myapp.test"
            echo "  project create laravel myapp myapp.test force ssl"
            echo "  project setup codeigniter3 pmb pmb.test ssl"
            echo "  project enable-ssl laravel myapp"
            echo "  project mkcert-setup"
            echo "  project php-info"
            echo "  project list"
            ;;
    esac
}

# Aliases for easy access
alias project="project_manager"
alias pj-create="project_manager create"
alias pj-setup="project_manager setup"
alias pj-enable-ssl="project_manager enable-ssl"
alias pj-disable-ssl="project_manager disable-ssl"
alias pj-mkcert="project_manager mkcert-setup"
alias pj-list="project_manager list"
alias pj-code="project_manager code"
alias pj-delete="project_manager delete"
alias pj-fix="project_manager fix"
alias pj-symlink="project_manager symlink"
alias pj-permissions="project_manager permissions"
alias pj-php="project_manager php-info"
alias pj-path="project_manager path"