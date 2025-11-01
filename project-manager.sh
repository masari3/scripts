#!/bin/bash

# UPDATED PATHS BASED ON NEW STRUCTURE
PROJECTS_ROOT="$HOME/projects/www"
SCRIPTS_ROOT="$HOME/projects/scripts"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
HOSTS_FILE="/mnt/c/Windows/System32/drivers/etc/hosts"

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
    
    # Detect PHP version
    local php_version=$(detect_php_version)
    echo "🔍 Detected PHP version: $php_version"
    
    # Create nginx config dengan PHP version yang terdeteksi
    sudo tee "$NGINX_AVAILABLE/$domain" > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    
    server_name $domain;
    
    root $nginx_root_path;
    index index.php index.html index.htm;

    access_log /var/log/nginx/projects/${domain}-access.log;
    error_log /var/log/nginx/projects/${domain}-error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/${php_version}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
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
        
        # Check if project directory exists in symlink location
        local symlink_path="/var/www/projects/$project_type/$project_name"
        if [ ! -d "$symlink_path" ]; then
            echo "❌ Project not found in symlink location: $symlink_path"
            echo "💡 Make sure the project exists in ~/projects/www/$project_type/$project_name"
        fi
        
        return 1
    fi
    
    echo "🎉 Project setup completed!"
    echo "📁 Local Path: $PROJECTS_ROOT/$project_type/$project_name"
    echo "🌐 Nginx Path: $nginx_root_path"
    echo "🔗 URL: http://$domain"
}

# Function to add domain to Windows hosts (IMPROVED)
add_to_hosts() {
    local domain=$1
    
    # Check if already exists
    if hosts_entry_exists "$domain"; then
        echo "ℹ️  Domain $domain already exists in hosts file"
        return 0
    fi
    
    echo "Adding $domain to Windows hosts file..."
    
    # Method 1: Try direct PowerShell command
    if powershell.exe -Command "Add-Content -Path 'C:\Windows\System32\drivers\etc\hosts' -Value '127.0.0.1 $domain' -Force" 2>/dev/null; then
        echo "✅ Added $domain to hosts file (Method 1)"
        return 0
    fi
    
    # Method 2: Try with Start-Process (Run as Admin)
    if powershell.exe -Command "Start-Process PowerShell -ArgumentList '-Command', 'Add-Content -Path \\\"C:\Windows\System32\drivers\etc\hosts\\\" -Value \\\"127.0.0.1 $domain\\\" -Force' -Verb RunAs" 2>/dev/null; then
        echo "✅ Added $domain to hosts file (Method 2 - Admin)"
        return 0
    fi
    
    # Method 3: Manual echo to hosts file via WSL
    echo "Trying WSL method..."
    if echo "127.0.0.1 $domain" | sudo tee -a /mnt/c/Windows/System32/drivers/etc/hosts > /dev/null 2>&1; then
        echo "✅ Added $domain to hosts file (Method 3 - WSL)"
        return 0
    fi
    
    # Method 4: Final fallback - manual instruction
    echo "❌ Failed to add $domain to hosts file automatically"
    echo "📝 Please manually add this line to C:\\Windows\\System32\\drivers\\etc\\hosts:"
    echo "   127.0.0.1 $domain"
    echo ""
    echo "💡 Quick manual fix:"
    echo "   1. Press Win + X, then A (Windows Terminal Admin)"
    echo "   2. Run: Add-Content -Path 'C:\\Windows\\System32\\drivers\\etc\\hosts' -Value '127.0.0.1 $domain'"
    echo "   3. Or use Notepad as Administrator"
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

# Function to migrate flat project to structured
migrate_project() {
    local project_name=$1
    local project_type=$2
    local domain=$3
    
    if [ -z "$project_name" ] || [ -z "$project_type" ]; then
        echo "Usage: migrate_project <project-name> <project-type> [domain]"
        echo "Example: migrate_project pmb codeigniter3 pmb.test"
        return 1
    fi
    
    local flat_path="$PROJECTS_ROOT/$project_name"
    local structured_path="$PROJECTS_ROOT/$project_type/$project_name"
    
    if [ ! -d "$flat_path" ]; then
        echo "❌ Project not found in flat structure: $flat_path"
        return 1
    fi
    
    if [ -d "$structured_path" ]; then
        echo "⚠️  Project already exists in structured location: $structured_path"
        echo "   Using existing structured project"
    else
        echo "🚚 Moving project from flat to structured location..."
        mkdir -p "$PROJECTS_ROOT/$project_type"
        mv "$flat_path" "$structured_path"
        echo "✅ Moved to: $structured_path"
    fi
    
    # Setup nginx config
    local final_domain=${domain:-"$project_name.test"}
    setup_nginx_config "$project_type" "$project_name" "$final_domain"
}

# Function to list all projects with status
list_projects() {
    echo "📂 Projects Overview - Structured Location: ~/projects/www/<type>/<project>"
    echo "========================================================================"
    
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
    
    # Check for flat projects (old structure)
    echo ""
    echo "📁 Flat Projects (to be migrated):"
    find "$PROJECTS_ROOT" -maxdepth 1 -type d | tail -n +2 | while read dir; do
        local name=$(basename "$dir")
        # Skip if it's a project type folder
        if [[ "$name" != "laravel" && "$name" != "nextjs" && "$name" != "codeigniter3" ]]; then
            echo "   📦 $name (needs migration)"
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

# Function to detect PHP version
detect_php_version() {
    # Check for available PHP versions
    if [ -S "/var/run/php/php8.2-fpm.sock" ]; then
        echo "php8.2"
    elif [ -S "/var/run/php/php8.1-fpm.sock" ]; then
        echo "php8.1"
    elif [ -S "/var/run/php/php7.4-fpm.sock" ]; then
        echo "php7.4"
    else
        echo "php8.1"  # fallback
    fi
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

# Function to fix symlink
fix_symlink() {
    echo "🔗 Checking symlink..."
    
    if [ -L "/var/www/projects" ]; then
        local current_target=$(readlink /var/www/projects)
        echo "ℹ️  Current symlink: /var/www/projects -> $current_target"
        
        if [ "$current_target" != "$HOME/projects/www" ]; then
            echo "🔄 Updating symlink to new location..."
            sudo rm -f /var/www/projects
            sudo ln -s "$HOME/projects/www" /var/www/projects
            echo "✅ Symlink updated"
        else
            echo "✅ Symlink already points to correct location"
        fi
    else
        echo "🔗 Creating new symlink..."
        sudo ln -s "$HOME/projects/www" /var/www/projects
        echo "✅ Symlink created: /var/www/projects -> $HOME/projects/www"
    fi
    
    echo "🔗 Final symlink status:"
    ls -la /var/www/projects
}

# Function to fix permissions for projects
fix_permissions() {
    local project_type=$1
    local project_name=$2
    
    if [ -z "$project_type" ] || [ -z "$project_name" ]; then
        echo "Usage: fix_permissions <laravel|nextjs|codeigniter3> <project-name>"
        return 1
    fi
    
    local project_path="/var/www/projects/$project_type/$project_name"
    
    if [ ! -d "$project_path" ]; then
        echo "❌ Project not found: $project_path"
        return 1
    fi
    
    echo "🔧 Fixing permissions for: $project_path"
    
    # Set ownership to www-data but keep user access
    sudo chown -R $USER:www-data "$project_path"
    
    # Set directory permissions
    sudo find "$project_path" -type d -exec sudo chmod 755 {} \;
    
    # Set file permissions
    sudo find "$project_path" -type f -exec sudo chmod 644 {} \;
    
    # Framework-specific permission fixes
    case $project_type in
        "codeigniter3")
            if [ -d "$project_path/application/cache" ]; then
                sudo chmod -R 775 "$project_path/application/cache"
                echo "✅ Fixed cache permissions"
            fi
            if [ -d "$project_path/application/logs" ]; then
                sudo chmod -R 775 "$project_path/application/logs"
                echo "✅ Fixed logs permissions"
            fi
            if [ -d "$project_path/uploads" ]; then
                sudo chmod -R 775 "$project_path/uploads"
                echo "✅ Fixed uploads permissions"
            fi
            ;;
        "laravel")
            if [ -d "$project_path/storage" ]; then
                sudo chmod -R 775 "$project_path/storage"
                echo "✅ Fixed storage permissions"
            fi
            if [ -d "$project_path/bootstrap/cache" ]; then
                sudo chmod -R 775 "$project_path/bootstrap/cache"
                echo "✅ Fixed bootstrap cache permissions"
            fi
            ;;
    esac
    
    echo "✅ Permissions fixed for $project_name"
    
    # Restart services
    sudo service nginx reload
    sudo service php8.1-fpm restart
    
    echo "✅ Services reloaded"
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
        "migrate")
            migrate_project $2 $3 $4
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
        "permissions")    # ← BARU DITAMBAHKAN
            fix_permissions $2 $3
            ;;
        "symlink")
            fix_symlink
            ;;
        "hosts")
            add_to_hosts $2
            ;;
        "exists")
            project_exists $2 $3 && echo "✅ Project exists" || echo "❌ Project not found"
            ;;
        "path")
            echo "📁 Project Root: $PROJECTS_ROOT"
            echo "📁 Scripts Root: $SCRIPTS_ROOT"
            echo "🔗 Nginx Root: /var/www/projects"
            echo "📁 Nginx Paths:"
            echo "   - Laravel: /var/www/projects/laravel/{project}/public"
            echo "   - NextJS: /var/www/projects/nextjs/{project}"
            echo "   - CodeIgniter3: /var/www/projects/codeigniter3/{project}"
            ;;
        *)
            echo "🏗️  Project Manager - Structured Setup"
            echo "======================================"
            echo "📁 Project Location: ~/projects/www/<type>/<project>"
            echo "📁 Scripts Location: ~/projects/scripts/"
            echo ""
            echo "Commands:"
            echo "  create <type> <name> <domain> [force]    - Create new project"
            echo "  setup <type> <name> <domain>            - Setup nginx for existing project"
            echo "  migrate <name> <type> [domain]          - Move flat project to structured"
            echo "  list                                    - List all projects with status"
            echo "  code <type> <name>                      - Open project in VS Code"
            echo "  delete <type> <name> [remove-files]     - Remove nginx config (and files)"
            echo "  fix <type> <name> [domain]              - Recreate nginx config"
            echo "  permissions <type> <name>               - Fix file permissions"  # ← BARU
            echo "  symlink                                 - Fix symlink to new location"
            echo "  hosts <domain>                          - Add domain to hosts"
            echo "  exists <type> <name>                    - Check if project exists"
            echo "  path                                    - Show all paths"
            echo ""
            echo "Project Types: laravel, nextjs, codeigniter3"
            echo ""
            echo "Examples:"
            echo "  project create laravel myapp myapp.test"
            echo "  project migrate pmb codeigniter3 pmb.test"
            echo "  project permissions codeigniter3 pmb    # Fix permission issues"
            echo "  project setup codeigniter3 pmb pmb.test"
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
alias pj-migrate="project_manager migrate"
alias pj-list="project_manager list"
alias pj-code="project_manager code"
alias pj-delete="project_manager delete"
alias pj-fix="project_manager fix"
alias pj-symlink="project_manager symlink"
alias pj-path="project_manager path"
alias pj-permissions="project_manager permissions" 