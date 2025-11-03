#!/bin/bash

# UPDATED PATHS - SESUAI DENGAN FIX YANG BEKERJA
PROJECTS_ROOT="/mnt/d/projects/www"  # ← PATH YANG BENAR
SCRIPTS_ROOT="/mnt/d/projects/scripts"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
HOSTS_FILE="/mnt/c/Windows/System32/drivers/etc/hosts"

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
    
    if [ -z "$project_type" ] || [ -z "$project_name" ] || [ -z "$domain" ]; then
        echo "Usage: create_project <laravel|nextjs|codeigniter3> <project-name> <domain> [force]"
        echo "Example: create_project laravel myapp myapp.test"
        echo "Example: create_project laravel myapp myapp.test force (recreate config)"
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
            setup_nginx_config "$project_type" "$project_name" "$domain"
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
    setup_nginx_config "$project_type" "$project_name" "$domain"
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

# Function to setup nginx configuration with CORRECT PATHS
setup_nginx_config() {
    local project_type=$1
    local project_name=$2
    local domain=$3
    
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
    
    # Create nginx config dengan path yang benar dan PHP connection yang terdeteksi
    sudo tee "$NGINX_AVAILABLE/$domain" > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain;
    
    # PREVENT HTTPS REDIRECT
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
        
        return 1
    fi
    
    echo "🎉 Project setup completed!"
    echo "📁 Local Path: $PROJECTS_ROOT/$project_type/$project_name"
    echo "🌐 Nginx Path: $nginx_root_path"
    echo "🔗 PHP: $php_version via $php_connection"
    echo "🔗 URL: http://$domain"
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
    
    if [ -z "$project_type" ] || [ -z "$project_name" ] || [ -z "$domain" ]; then
        echo "Usage: setup_existing <laravel|nextjs|codeigniter3> <project-name> <domain>"
        echo "Example: setup_existing laravel myapp myapp.test"
        return 1
    fi
    
    if ! project_exists "$project_type" "$project_name"; then
        echo "❌ Project not found: $PROJECTS_ROOT/$project_type/$project_name"
        echo "   Use 'create_project' to create a new project"
        return 1
    fi
    
    echo "🔧 Setting up nginx configuration for existing project: $project_name"
    setup_nginx_config "$project_type" "$project_name" "$domain"
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
                if domain_exists "$domain"; then
                    echo "   ✅ $name (http://$domain)"
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
    setup_nginx_config "$project_type" "$project_name" "$domain"
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
            create_project $2 $3 $4 $5
            ;;
        "setup")
            setup_existing_project $2 $3 $4
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
            echo "📁 Nginx Paths:"
            echo "   - Laravel: /var/www/projects/laravel/{project}/public"
            echo "   - NextJS: /var/www/projects/nextjs/{project}"
            echo "   - CodeIgniter3: /var/www/projects/codeigniter3/{project}"
            ;;
        *)
            echo "🏗️  Project Manager - FIXED SETUP"
            echo "================================"
            echo "📁 Project Location: $PROJECTS_ROOT/<type>/<project>"
            echo "📁 Scripts Location: $SCRIPTS_ROOT"
            echo "🔗 Symlink: /var/www/projects -> $PROJECTS_ROOT"
            echo "🔗 PHP-FPM: Auto-detected"
            echo ""
            echo "Commands:"
            echo "  create <type> <name> <domain> [force]    - Create new project"
            echo "  setup <type> <name> <domain>            - Setup nginx for existing project"
            echo "  list                                    - List all projects with status"
            echo "  code <type> <name>                      - Open project in VS Code"
            echo "  delete <type> <name> [remove-files]     - Remove nginx config (and files)"
            echo "  fix <type> <name> [domain]              - Recreate nginx config"
            echo "  symlink                                 - Setup correct symlink"
            echo "  permissions <type> <name>               - NTFS permission info"
            echo "  hosts <domain>                          - Add domain to hosts"
            echo "  exists <type> <name>                    - Check if project exists"
            echo "  php-info                                - Show PHP version info"
            echo "  path                                    - Show all paths"
            echo ""
            echo "Project Types: laravel, nextjs, codeigniter3"
            echo ""
            echo "Examples:"
            echo "  project create laravel myapp myapp.test"
            echo "  project setup codeigniter3 pmb pmb.test"
            echo "  project php-info                        # Check PHP version"
            echo "  project symlink"
            echo "  project path"
            echo "  project list"
            ;;
    esac
}

# Aliases for easy access
alias project="project_manager"
alias pj-create="project_manager create"
alias pj-setup="project_manager setup"
alias pj-list="project_manager list"
alias pj-code="project_manager code"
alias pj-delete="project_manager delete"
alias pj-fix="project_manager fix"
alias pj-symlink="project_manager symlink"
alias pj-permissions="project_manager permissions"
alias pj-php="project_manager php-info"
alias pj-path="project_manager path"