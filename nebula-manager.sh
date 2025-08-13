#!/bin/bash

###################################################################
########################## Configuration ##########################
###################################################################
SERVER_CONF="/etc/nebula/nebula-manager.conf"                                                                           # Nebula Manager conf file location
###################################################################
###################################################################

###################################################################
########################## Other Settings #########################
###################################################################
SERVER_CONF_URL="https://raw.githubusercontent.com/jordanhillis/nebula-manager/refs/heads/main/nebula-manager.conf" # Template URL for Nebula Manager conf file  
NEBULA_TEMPLATE_URL="https://raw.githubusercontent.com/slackhq/nebula/refs/heads/master/examples/config.yml"        # Template URL for Nebula config.yml
NEBULA_API_RELEASES_URL="https://api.github.com/repos/slackhq/nebula/releases/latest"                               # API URL to latest release of Nebula
VERSION="1.0.0"                                                                                                     # Script version
declare -A PKG_BASE=(
  [awk]="gawk"
  [curl]="curl"
  [find]="findutils"
  [grep]="grep"
  [jq]="jq"
  [ping]="iputils-ping"
  [sed]="sed"
  [sudo]="sudo"
  [systemctl]="systemd"
  [tar]="tar"
  [wget]="wget"
  [yq]="yq"
  [sha256sum]="coreutils"
  [iperf3]="iperf3"
)                                                                                                                   # Requires binaries and associated packages from repo
declare -A PKG_RH_OVERRIDE=(
  [ping]="iputils"
)                                                                                                                   # Required packages for Red Hat
MENU_PATH="Main Menu"                                                                                               # Main menu header
NEBULA_VERSION=""                                                                                                   # Placeholder for Nebula version installed
SCRIPT_URL="https://raw.githubusercontent.com/jordanhillis/nebula-manager/main/nebula-manager.sh"                   # URL to the script on GitHub
VERSION_URL="https://raw.githubusercontent.com/jordanhillis/nebula-manager/main/latest_version.txt"                 # URL to the scripts latest version
RELEASE_PAGE="https://github.com/jordanhillis/nebula-manager"                                                       # URL to the script GitHub repo
VERSION_CACHE_FILE="/tmp/nebula-manager-version.cache"                                                              # File path to cache version checking to
VERSION_CACHE_TTL_SECONDS=$((6 * 3600))                                                                             # How long to cache version checking for (6 hours)
SCRIPT_PATH="$(readlink -f "$0")"                                                                                   # Current script path
AUTO_UPDATE_CMD="$SCRIPT_PATH --auto-update-nebula"                                                                 # Full path of script and the auto-update-nebula arg
CRON_COMMENT="# Auto-update Nebula"                                                                                 # Comment for cron job for auto-update-nebula
# Define color codes for better output formatting
RESET='\033[0m'
BOLD='\033[1m'
# Text Colors
BLACK="\e[30m"
GRAY="\e[30m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[37m"
ORANGE="\e[38;5;202m"
# Background Colors
BG_BLACK="\e[40m"
BG_RED="\e[41m"
BG_GREEN="\e[42m"
BG_YELLOW="\e[43m"
BG_BLUE="\e[44m"
BG_MAGENTA="\e[45m"
BG_CYAN="\e[46m"
BG_WHITE="\e[47m"
BG_ORANGE="\e[48;5;202m"
BG_GRAY="\e[48;5;240m"
BG_LIGHT_GRAY="\e[48;5;250m"
BG_LIGHT_BLACK="\e[48;5;233m"
###################################################################
###################################################################

# Function to generate icons
get_icon() {
  if [[ "$USE_ICONS" == "false" ]]; then
    echo ""
    return
  fi
  case "$1" in
    certificate)     echo "📜 " ;;
    configuration)   echo "🔧 " ;;
    connectivity)    echo "📡 " ;;
    maintenance)     echo "🧰 " ;;
    exit)            echo "🚪 " ;;
    start)           echo "🧩 " ;;
    update)          echo "⬆️ " ;;
    schedule)        echo "⏰ " ;;
    install)         echo "📥 " ;;
    uninstall)       echo "🔥 " ;;
    validate)        echo "✅ " ;;
    edit)            echo "📝 " ;;
    firewall)        echo "🧱 " ;;
    left-arrow)      echo "⬅️ " ;;
    right-arrow)     echo "➡️ " ;;
    security)        echo "🔐 " ;;
    list)            echo "📄 " ;;
    create)          echo "🆕 " ;;
    inspect)         echo "🔍 " ;;
    revoke)          echo "⛔ " ;;
    delete)          echo "🗑️ " ;;
    ping)            echo "📶 " ;;
    status)          echo "📈 " ;;
    trace)           echo "🗺️ " ;;
    scan)            echo "🔎 " ;;
    logs)            echo "🧾 " ;;
    tools)           echo "🧰 " ;;
    backup)          echo "💾 " ;;
    restore)         echo "♻️ " ;;
    info)            echo "ℹ️ " ;;
    warning)         echo "⚠️ " ;;
    error)           echo "❌ " ;;
    success)         echo "✔️ " ;;
    question)        echo "❓ " ;;
    download)        echo "📦 " ;;
    upload)          echo "📤 " ;;
    lock)            echo "🔐 " ;;
    s_success)       echo "✔ " ;;
    s_error)         echo "✘ " ;;
    back)            echo "↩️ " ;;
    menu)            echo "📋 " ;;
    home)            echo "🏠 " ;;
    refresh)         echo "🔄 " ;;
    package)         echo "📦 " ;;
    link)            echo "🔗 " ;;
    hour-glass)      echo "⏳ " ;;
    *)               echo "" ;;
  esac
}

# Function to display status with color
show_status() {
    local status="$1"
    if [[ "$status" == "success" ]]; then
        echo -e -n "${GREEN}[${BOLD}✔${RESET}${GREEN}]${RESET}"
    elif [[ "$status" == "error" ]]; then
        echo -e -n "${RED}[${BOLD}✘${RESET}${RED}]${RESET}"
    elif [[ "$status" == "question" ]]; then
        echo -e -n "${CYAN}[${BOLD}?${RESET}${CYAN}]${RESET}"
    elif [[ "$status" == "warning" ]]; then
        echo -e -n "${YELLOW}[${BOLD}!${RESET}${YELLOW}]${RESET}"      
    else
        echo -e -n "${YELLOW}[${BOLD}-${RESET}${YELLOW}]${RESET}"
    fi
}

# Function to detect architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64) echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        *) echo -e "$(show_status 'error') Unsupported architecture"; exit 1 ;;
    esac
}

# Helper: resolve package for current distro
pkg_for() {
  local bin="$1"
  if [[ -f /etc/redhat-release ]] && [[ -n "${PKG_RH_OVERRIDE[$bin]:-}" ]]; then
    printf '%s' "${PKG_RH_OVERRIDE[$bin]}"
  else
    printf '%s' "${PKG_BASE[$bin]}"
  fi
}

# Function to check required packages
check_dependencies() {
  [[ "$IGNORE_DEPENDENCY_CHECK" == true ]] && return
  local install_cmd
  if [[ -f /etc/debian_version ]]; then
    install_cmd="apt install"
  elif [[ -f /etc/redhat-release ]]; then
    install_cmd="dnf install"
  else
    echo -e "${RED}[✘] Unsupported distribution.${RESET}"; return 1
  fi
  local missing=() bin pkg
  for bin in "${!PKG_BASE[@]}"; do
    command -v "$bin" &>/dev/null && continue
    pkg="$(pkg_for "$bin")"
    # skip duplicates if multiple bins map to same pkg and already queued
    [[ " ${missing[*]} " == *" $pkg "* ]] || missing+=("$pkg")
  done
  if (( ${#missing[@]} )); then
    echo -e "${RED}[✘] Missing dependencies:${RESET}"
    printf '  - %s\n' "${missing[@]}"
    echo -e "\nInstall with:\n  ${YELLOW}sudo $install_cmd ${missing[*]}${RESET}"
    exit 1
  fi
}

# Function to check installed version of Nebula
check_nebula_installed() {
    if command -v nebula &> /dev/null; then
        NEBULA_VERSION=$("$NEBULA_BIN_PATH/nebula" --version | grep "Version" | awk '{print $2}')
        return 0
    else
        return 1
    fi
}

# Function to check nebula config file for errors
check_nebula_config() {
    local config_file="${1:-$NEBULA_DIR/config.yml}"
    local filter="$2"
    # Ensure the config file exists
    if [[ ! -f "$config_file" ]]; then
        echo -e "$(show_status 'error') ${RED}Nebula config file not found at $config_file. Exiting...${RESET}"
        return 1
    fi
    echo -e "$(show_status 'info') ${CYAN}Testing Nebula config: ${config_file}${RESET}"
    local output
    output=$("$NEBULA_BIN_PATH/nebula" -test -config "$config_file" 2>&1)
    local status=$?
    if [[ $status -eq 0 ]]; then
        echo -e "$(show_status 'success') ${GREEN}Nebula config is valid${RESET} $(get_icon 'validate')"
        return 0
    else
        echo -e "$(show_status 'error') ${RED}Nebula config is invalid. Details:${RESET}"
        if [[ "$filter" == "error" ]]; then
            echo "$output" | grep -Ei 'error|failed'
        else
            echo -e "    ${YELLOW}$output${RESET}"
        fi
        return 1
    fi
}

# Function to get the latest version from GitHub
get_latest_version() {
    local cache_file="/tmp/nebula_latest_version.cache"
    local cache_ttl=$((60 * 60))  # 1 hour in seconds
    local now ts
    # If cache exists and is fresh, return it
    if [[ -f "$cache_file" ]]; then
        ts=$(stat -c %Y "$cache_file" 2>/dev/null)
        now=$(date +%s)
        if (( now - ts < cache_ttl )); then
            cat "$cache_file"
            return 0
        fi
    fi
    # Otherwise fetch from API
    local latest_version
    latest_version=$(curl -s $NEBULA_API_RELEASES_URL \
        | jq -r ".tag_name")
    latest_version=${latest_version#v}  # Remove 'v' prefix
    # Save to cache
    echo -n "$latest_version" > "$cache_file"
    echo -n "$latest_version"
}

# Function to compare versions and ask if they want to update
check_for_nebula_update() {
    local installed_version=$NEBULA_VERSION
    local latest_version=$(get_latest_version)
    if [[ "$installed_version" == "$latest_version" ]]; then
        echo -e "$(show_status 'success') ${GREEN}You already have the latest version of Nebula installed ($latest_version)${RESET}"
    else
        echo -e "$(show_status 'info') ${YELLOW}A newer version of Nebula is available: $latest_version (Installed: $installed_version)${RESET}"
        read -p "$(show_status 'question') Do you want to update Nebula to the latest version? (y/n): " answer
        if [[ "$answer" == "y" ]]; then
            install_nebula "$latest_version"
        else
            IGNORE_NEBULA_UPDATE=true
            echo -e "$(show_status 'error') ${YELLOW}Update canceled.${RESET}"
        fi
    fi
}

# Function to install a specific version of Nebula from official GitHub repo
install_nebula() {
    local latest_version="${1:-$(get_latest_version)}"
    local os=""
    local arch=$(detect_arch)
    local tmp_dir="/tmp/nebula_install"
    # Detect first-time install
    local first_install=false
    if ! check_nebula_installed; then
        first_install=true
    fi
    # Determine the OS
    case "$OSTYPE" in
        linux-gnu*) os="linux" ;;
        darwin*) os="darwin" ;;
        msys*) os="windows"; arch="amd64.zip" ;;  # Windows is typically 64-bit for Nebula
        *) echo -e "$(show_status 'error') Unsupported OS. Exiting."; exit 1 ;;
    esac
    # Create a temporary directory to work in
    mkdir -p "$tmp_dir"
    cd "$tmp_dir" || { echo "Failed to switch to temporary directory $tmp_dir. Exiting."; exit 1; }
    # Fetch the latest release download URL from GitHub
    download_url=$(curl -s $NEBULA_API_RELEASES_URL \
        | jq -r ".assets[] | select(.browser_download_url | contains(\"${os}\") and contains(\"${arch}\")) | .browser_download_url")
    # Check if the download URL is valid
    if [ -z "$download_url" ]; then
        echo -e "$(show_status 'error') Failed to find a matching Nebula release. Exiting."
        exit 1
    fi
    # Show the version being downloaded
    echo -e "$(show_status 'info') Downloading Nebula version $latest_version from $download_url..."
    wget -q "$download_url" -O nebula.tar.gz || { echo "Download failed. Exiting."; exit 1; }
    # Extract the archive
    echo -e "$(show_status 'info') Extracting Nebula version $latest_version..."
    if [[ "$os" == "windows" ]]; then
        unzip nebula.tar.gz -d nebula || { echo "Failed to extract. Exiting."; exit 1; }
    else
        tar -xzf nebula.tar.gz || { echo "Failed to extract. Exiting."; exit 1; }
    fi
    # Check if the binary files exist and are executable
    if [[ ! -x "nebula" || ! -x "nebula-cert" ]]; then
        echo -e "$(show_status 'error') Nebula binaries are not executable or missing. Exiting."
        exit 1
    fi
    # Backup existing binaries if they exist
    backup_dir="/tmp/nebula-temp-backup"
    mkdir -p "$backup_dir"
    for binary in nebula nebula-cert; do
        if [[ -f "$NEBULA_BIN_PATH/$binary" ]]; then
            cp "$NEBULA_BIN_PATH/$binary" "$backup_dir/$binary.bak"
            echo -e "$(show_status 'info') Backed up $binary to $backup_dir/$binary.bak"
        fi
    done
    # Move the binaries to /usr/local/bin and ensure proper permissions
    echo -e "$(show_status 'info') Installing Nebula version $latest_version..."
    sudo mv nebula nebula-cert "$NEBULA_BIN_PATH" || { echo "Failed to move binaries. Exiting."; exit 1; }
    sudo chmod +x "$NEBULA_BIN_PATH/nebula" "$NEBULA_BIN_PATH/nebula-cert" || { echo "Failed to set executable permissions. Exiting."; exit 1; }
    if [[ -z "$AUTO_UPDATE" ]]; then
        # Set up directories and config file
        setup_nebula_config
        # Install service file and enable/start
        setup_nebula_service
        # Clean up the temporary directory
    fi
    echo -e "$(show_status 'info') Cleaning up temporary files..."
    rm -rf "$tmp_dir"
    echo -e "$(show_status 'success') Nebula version $latest_version installed successfully."
    # Update installed version
    check_nebula_installed
    # Only restart/restore if NOT first installation
    if [[ $first_install == false ]]; then
        # Restart only enabled services
        restart_nebula_servers
        # Check for failures and restore / restart services to previous state
        restore_nebula_backup_if_failed
    fi
    if [[ -z "$AUTO_UPDATE" ]]; then
        banner
        top_header
        # Now that Nebula is installed, return to the menu with all options
        main_menu # Main menu
    fi
}

# Function to restore backup of nebula/nebula-cert if failures happen on upgrade
restore_nebula_backup_if_failed() {
    local backup_dir="/tmp/nebula-temp-backup"
    local has_failure=false
    # Check for failure flags
    for failure_flag in /tmp/nebula_failed_*; do
        [[ -e "$failure_flag" ]] || continue
        has_failure=true
        break
    done
    if [[ "$has_failure" = true ]]; then
        echo -e "$(show_status 'warning') ${YELLOW}One or more Nebula restarts failed. Restoring previous binaries...${RESET}"
        for binary in nebula nebula-cert; do
            if [[ -f "$backup_dir/$binary.bak" ]]; then
                sudo mv "$NEBULA_BIN_PATH/$binary" "/tmp/${binary}.old"
                sudo cp "$backup_dir/$binary.bak" "$NEBULA_BIN_PATH/$binary"
                sudo chmod +x "$NEBULA_BIN_PATH/$binary"
                echo -e "$(show_status 'success') Restored $binary from backup."
                sudo rm -rf "/tmp/${binary}.old"
            else
                echo -e "$(show_status 'error') Backup for $binary not found in $backup_dir"
            fi
        done
        # Restart only enabled services
        restart_nebula_servers
    else
        echo -e "$(show_status 'success') ${GREEN}No service failures detected. No need to restore.${RESET}"
    fi
}

# Function to restart all enabled Nebula servers
restart_nebula_servers() {
    rm -f /tmp/nebula_failed_*
    mapfile -t servers < <(
        awk '
            /^\[server\.[^]]+\]/ {
                server = substr($0, 9, length($0) - 9 - 1)
                in_server = 1
                next
            }
            /^\[.*\]/ { in_server = 0 }
            in_server && /^[[:space:]]*enabled[[:space:]]*=[[:space:]]*true[[:space:]]*$/ {
                print server
            }
        ' "$SERVER_CONF"
    )

    for server in "${servers[@]}"; do
        local SERVER_NAME_TEMP="$server"
        local NEBULA_SERVICE_TEMP NEBULA_DIR_TEMP

        # Load server config into temporary variables
        eval "$(
            awk -F= -v s="server.$SERVER_NAME_TEMP" '
                { sub(/\r$/, "") }
                /^\[server\.[^]]+\]/ {
                    in_server = ($0 == "[" s "]"); next
                }
                in_server && NF == 2 {
                    gsub(/^[ \t]+|[ \t]+$/, "", $1)
                    gsub(/^[ \t]+|[ \t]+$/, "", $2)
                    key = "NEBULA_TEMP_" toupper($1)
                    gsub("-", "_", key)
                    printf "%s=\"%s\"; export %s\n", key, $2, key
                }
            ' "$SERVER_CONF"
        )"

        NEBULA_SERVICE_TEMP="${NEBULA_TEMP_SERVICE:-$GLOBAL_SERVICE}"
        NEBULA_DIR_TEMP="${NEBULA_TEMP_DIR:-$GLOBAL_DIR}"

        local serviceName
        serviceName=$(basename "$NEBULA_SERVICE_TEMP")

        # Validate config for this server
        if ! check_nebula_config "$NEBULA_DIR_TEMP/config.yml" "error"; then
            touch "/tmp/nebula_failed_${SERVER_NAME_TEMP}"
            continue
        fi

        printf "    ${BOLD}Restarting service for %-20s...${RESET} " "$SERVER_NAME_TEMP"
        if sudo systemctl restart "$serviceName" &>/dev/null && sudo systemctl is-active --quiet "$serviceName"; then
            echo -e "${GREEN}Success${RESET}"
        else
            touch "/tmp/nebula_failed_${SERVER_NAME_TEMP}"
            echo -e "${RED}Failed${RESET}"
        fi
    done
}

# Function to auto update Nebula and restart all servers services
auto_update_nebula() {
    local latest_version
    latest_version=$(get_latest_version)
    check_nebula_installed
    if [[ "$NEBULA_VERSION" != "$latest_version" ]]; then
        echo -e "$(show_status 'info') ${YELLOW}Updating Nebula to version $latest_version...${RESET}"
        install_nebula "$latest_version"
    else
        echo -e "$(show_status 'success') ${GREEN}Nebula is already at the latest version ($latest_version)${RESET}"
        exit 0
    fi
}

# Function to install script to bin_path
ensure_installed_to_bin_path() {
    local target="${NEBULA_BIN_PATH:-/usr/local/bin}/nebula-manager"
    local current_script
    current_script="$(readlink -f "$0")"
    if [[ "$current_script" == "$target" ]]; then
        echo -e "$(show_status 'info') Script is running from ${CYAN}$target${RESET}"
        read -p "$(show_status 'question') Do you want to remove it? [y/N]: " remove_answer
        case "$remove_answer" in
            [yY][eE][sS]|[yY])
                sudo rm -f "$target" && \
                    echo -e "$(show_status 'success') ${GREEN}Removed $target${RESET}" || \
                    echo -e "$(show_status 'error') ${RED}Failed to remove $target${RESET}"
                ;;
            *)
                echo -e "$(show_status 'info') ${YELLOW}Keeping installed script.${RESET}"
                ;;
        esac
    else
        if [[ -f "$target" ]]; then
            echo -e "$(show_status 'info') ${CYAN}$target${RESET} already exists but is not this script."
        else
            echo -e "$(show_status 'info') Script is not installed at ${CYAN}$target${RESET}"
        fi
        read -p "$(show_status 'question') Do you want to install this script there? [y/N]: " install_answer
        case "$install_answer" in
            [yY][eE][sS]|[yY])
                sudo mkdir -p "$(dirname "$target")" || {
                    echo -e "$(show_status 'error') ${RED}Failed to create directory: $(dirname "$target")${RESET}"
                    return 1
                }
                sudo cp "$current_script" "$target" && sudo chmod +x "$target" && \
                    echo -e "$(show_status 'success') ${GREEN}Installed as $target${RESET}" || \
                    echo -e "$(show_status 'error') ${RED}Failed to install to $target${RESET}"
                ;;
            *)
                echo -e "$(show_status 'info') ${YELLOW}Skipped installation.${RESET}"
                ;;
        esac
        exit 0
    fi
}

# Function to set up /etc/nebula and download config.yml template
setup_nebula_config() {
    local config_file="${NEBULA_DIR}/config.yml"
    if [ ! -d "$NEBULA_DIR" ]; then
        echo -e "$(show_status 'success') ${CYAN}Creating $NEBULA_DIR directory...${RESET}"
        sudo mkdir -p "$NEBULA_DIR" || { echo -e "${RED}Failed to create $NEBULA_DIR. Exiting.${RESET}"; exit 1; }
    fi
    if [ ! -f "$config_file" ]; then
        echo -e "$(show_status 'info') ${CYAN}Downloading Nebula config.yml template...${RESET}"
        sudo wget -q "$NEBULA_TEMPLATE_URL" -O "$config_file" || { echo -e "${RED}Failed to download config.yml. Exiting.${RESET}"; exit 1; }
    else
        echo -e "$(show_status 'info') ${YELLOW}config.yml already exists in $NEBULA_DIR. Skipping template download.${RESET}"
    fi
    sudo chmod 755 "$NEBULA_DIR"
    sudo chmod 644 "$config_file"
    echo -e "$(show_status 'success') ${GREEN}Nebula configuration setup complete.${RESET}"
}

# Function to check if the Nebula service is setup
check_nebula_service() {
    local svc; svc=$(basename "$NEBULA_SERVICE")
    # system scope
    local state
    state=$(systemctl show -p LoadState --value "$svc" 2>/dev/null)
    if [[ "$state" == "loaded" ]]; then
        return 0
    fi
    # optional: user scope (if you might use --user units)
    state=$(systemctl --user show -p LoadState --value "$svc" 2>/dev/null)
    [[ "$state" == "loaded" ]] && return 0
    return 1
}

# Function to set up Nebula systemd service
setup_nebula_service() {
    local service_name=$(basename "$NEBULA_SERVICE")
    local service_template_url="https://raw.githubusercontent.com/slackhq/nebula/refs/heads/master/examples/service_scripts/nebula.service"
    local nebula_config_path="${NEBULA_DIR}/config.yml"
    # Check if the Nebula service already exists
    if check_nebula_service; then
        echo -e "$(show_status 'info') ${YELLOW}Nebula service already exists. Skipping installation.${RESET}"
        # restart_service_prompt
        return
    fi
    # Download the nebula.service file if it doesn't exist
    echo -e "$(show_status 'info') ${CYAN}Downloading Nebula service file...${RESET}"
    sudo wget -q "$service_template_url" -O "$NEBULA_SERVICE" || { echo -e "$(show_status 'error') ${RED}Failed to download nebula.service file.${RESET}"; exit 1; }
    # Modify the config path in the service file and set permissions
    sudo sed -i "s|/etc/nebula/config.yml|${nebula_config_path}|g" "$NEBULA_SERVICE"
    sudo chmod 644 "$NEBULA_SERVICE"
    # Reload systemd and enable the Nebula service
    sudo systemctl daemon-reload
    echo -e "$(show_status 'info') ${CYAN}Enabling Nebula service...(${YELLOW}$service_name${CYAN})${RESET}"
    sudo systemctl enable "$service_name" >/dev/null 2>&1 || { echo -e "$(show_status 'error') ${RED}Failed to enable $service_name${RESET}"; return; }
    echo -e "$(show_status 'warning') ${YELLOW}Please configure Nebula config file before starting service.${RESET}"
    echo -e "    ${BOLD}${CYAN}Config File:${RESET} ${NEBULA_DIR}/config.yml"
    echo -e "    To start the service go to ${ORANGE}Maintenance${RESET} > ${ORANGE}Toggle Nebula Service${RESET}"
    # Removed for now because often the config file is not setup for proper startup to happen
    # # Start the service with a 10-second timeout
    # echo -e "$(show_status 'info') ${CYAN}Starting Nebula service...${RESET}"
    # sudo systemctl start "$service_name" --no-block
    # # Wait up to 10 seconds for the service to become active
    # for _ in {1..10}; do
    #     systemctl is-active --quiet "$service_name" && {
    #         echo -e "$(show_status 'success') ${GREEN}Nebula service started successfully.${RESET}"
    #         return
    #     }
    #     sleep 1
    # done
    # # If the service didn't start after 10 seconds
    # echo -e "$(show_status 'error') ${RED}Failed to start Nebula service${RESET}"
}

# Function to restart service with a prompt before doing so
restart_service_prompt() {
    local service_name=$(basename "$NEBULA_SERVICE")
    read -p "$(show_status 'question') Do you want to restart the $service_name? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        if ! check_nebula_config "$NEBULA_DIR/config.yml"; then
            return
        fi
        echo "$(show_status 'info') Restarting $service_name service..."
        sudo systemctl restart "$service_name" --no-block
        # Wait up to 10 seconds for the service to become active
        for _ in {1..10}; do
            systemctl is-active --quiet "$service_name" && {
                echo -e "$(show_status 'success') ${GREEN}Nebula service restarted successfully${RESET}"
                return
            }
            sleep 1
        done
        # If the service didn't restart after 10 seconds
        echo -e "$(show_status 'error') ${RED}Failed to restart Nebula service${RESET}"

    else
        echo "$(show_status 'error') Nebula service restart canceled"
    fi
}

# Function to remove Nebula systemd service
remove_nebula_service() {
    local service_name=$(basename "$NEBULA_SERVICE")
    # Check if the Nebula service exists
    if check_nebula_service; then
        echo -e -n "$(show_status 'question') ${RED}Nebula service found ($service_name). Disable and remove it?${RESET} (y/n): "
        read -p "" confirm
        [[ "$confirm" != "y" ]] && { echo -e "$(show_status 'info') ${YELLOW}Service removal canceled.${RESET}"; return; }
        # Stop, disable, and remove the service
        echo -e "$(show_status 'info') ${CYAN}Stopping and removing Nebula service...${RESET}"
        for action in stop disable; do
            sudo systemctl "$action" "$service_name" >/dev/null 2>&1 || { echo -e "$(show_status 'error') ${RED}Failed to $action $service_name${RESET}"; }
        done
        sudo rm -f "$NEBULA_SERVICE" && sudo systemctl daemon-reload >/dev/null 2>&1 \
            && echo -e "$(show_status 'success') ${GREEN}Nebula service ($service_name) successfully removed${RESET}" \
            || echo -e "$(show_status 'error') ${RED}Failed to remove Nebula service file${RESET}"
    else
        echo -e "$(show_status 'info') ${YELLOW}No Nebula service found. Nothing to remove${RESET}"
    fi
}

# Function for menu header menu
show_menu_header() {
    local -a color_vars=(MAGENTA YELLOW ORANGE RED BLUE GREEN CYAN)
    local reset="${RESET:-}"
    local bold="${BOLD:-}"
    local styled_path=""
    local i=0
    local last_index=$(($# - 1))
    if [[ "${USE_COLOR:-true}" = false ]]; then
        styled_path="$*"
    else
        for segment in "$@"; do
            local color_var="${color_vars[i % ${#color_vars[@]}]}"
            local color="${!color_var}"

            if [[ $i -eq $last_index ]]; then
                styled_path+="${bold}${color}${segment}${reset}"
            else
                styled_path+="${color}${segment}${reset} ${CYAN}>${reset} "
            fi
            ((i++))
        done
    fi
    echo -e "${bold}${CYAN}=~=~=~=~=~=~=~=~=~=~=~[ ${styled_path}${CYAN} ]~=~=~=~=~=~=~=~=~=~=~=${reset}"
}

# Helper: truncate text if it exceeds given width
maxlen() {
    local text="$1" max="$2"
    [[ ${#text} -le $max ]] && echo "$text" || echo "${text:0:$((max - 3))}..."
}

# Function to manage Nebula certificates
manage_nebula_certs() {
    local certs_dir="${NEBULA_DIR:-/etc/nebula}/${NEBULA_CERT_FOLDER}"
    sudo mkdir -p "${certs_dir}"

    # Ensure the certs directory exists
    [[ -d "$certs_dir" ]] || { echo -e "$(show_status 'error') ${RED}Certificates directory $certs_dir does not exist.${RESET}"; exit 1; }

    list_certs() {
        local certs_dir="${NEBULA_DIR:-/etc/nebula}/${NEBULA_CERT_FOLDER}" rows=()
        [[ -d "$certs_dir" ]] || { echo -e "$(show_status 'error') Certificates dir not found: $certs_dir"; return 1; }

        for cert in "$certs_dir"/*.crt; do
            [[ -f "$cert" ]] || continue
            local json=$("$NEBULA_BIN_PATH/nebula-cert" print -json -path "$cert")
            local n=$(jq -r '.details.name' <<<"$json")
            local t=$(jq -r '.details.isCa' <<<"$json"); t=$([[ $t == true ]] && echo "CA" || echo "Cert")
            local i=$(jq -r '.details.ips | join(", ")' <<<"$json"); [[ -z "$i" ]] && i="N/A"
            local g=$(jq -r '.details.groups | if length==0 then "None" else join(", ") end' <<<"$json")
            local s=$(jq -r '.details.subnets | if length==0 then "None" else join(", ") end' <<<"$json")
            local nb=$(jq -r '.details.notBefore' <<<"$json")
            local na=$(jq -r '.details.notAfter' <<<"$json")
            local fp=$(jq -r '.fingerprint' <<<"$json")
            rows+=("$n|$t|$i|$g|$s|$nb|$na|$fp")
        done

        [[ ${#rows[@]} -eq 0 ]] && { echo -e "${YELLOW}No certificates found in $certs_dir.${RESET}"; return; }

        IFS=$'\n' sorted=($(printf "%s\n" "${rows[@]}" | sort -t "|" -k6))

        # Header bar
        local border_len=158
        printf "${CYAN}%${border_len}s${RESET}\n" | tr ' ' '-'
        printf "${BOLD}${YELLOW} %-14s ${CYAN}|${YELLOW} %-4s ${CYAN}|${YELLOW} %-18s ${CYAN}|${YELLOW} %-18s ${CYAN}|${YELLOW} %-20s ${CYAN}|${YELLOW} %-20s ${CYAN}|${YELLOW} %-20s ${CYAN}|${YELLOW} %-16s ${RESET}\n" \
            "Name" "Type" "IPs" "Groups" "Subnets" "Not Before" "Not After" "Fingerprint"
        printf "${CYAN}%${border_len}s${RESET}\n" | tr ' ' '-'

        local now=$(date -u +%s)
        for row in "${sorted[@]}"; do
            IFS="|" read -r n t i g s nb na fp <<< "$row"

            local epoch_nb=$(date -d "$nb" +%s 2>/dev/null || echo 0)
            local epoch_na=$(date -d "$na" +%s 2>/dev/null || echo 0)

            [[ $epoch_nb -le $now ]] && color_nb="${GREEN}" || color_nb="${WHITE}"
            [[ $epoch_na -le $now ]] && color_na="${RED}" || color_na="${GREEN}"

            printf " ${CYAN}%-14s${RESET} | ${ORANGE}%-4s${RESET} | ${GREEN}%-18s${RESET} | ${MAGENTA}%-18s${RESET} | ${YELLOW}%-20s${RESET} | ${color_nb}%-20s${RESET} | ${color_na}%-20s${RESET} | ${RED}%-16s${RESET}\n" \
                "$(maxlen "$n" 14)" "$t" "$(maxlen "$i" 18)" "$(maxlen "$g" 18)" "$(maxlen "$s" 20)" "$nb" "$na" "$(maxlen "$fp" 20)"
        done

        printf "${CYAN}%${border_len}s${RESET}\n" | tr ' ' '-'

        echo -en "${BOLD}${YELLOW}Press Enter to return or type a cert name to view more details: ${RESET}"
        read cert_detail_choice
        if [[ -n "$cert_detail_choice" ]]; then
            local cert_path="$certs_dir/$cert_detail_choice.crt"
            if [[ -f "$cert_path" ]]; then
                echo -e "${BOLD}${CYAN}Details for $cert_detail_choice:${RESET}"
                "$NEBULA_BIN_PATH/nebula-cert" print -path "$cert_path"
            else
                echo -e "${RED}Certificate '$cert_detail_choice' not found in $certs_dir.${RESET}"
            fi
        fi
    }

    # Function to remove certificate by name
    remove_cert() {
        local cert_name_remove certs
        for cert in "$certs_dir"/*.crt; do
            [[ -f "$cert" ]] && certs+="${CYAN}"$(basename "$cert" .crt)"${RESET}, "
        done
        certs=${certs%, } # Remove the trailing comma and space
        echo -e "    $certs"
        read -p "$(show_status 'question') Enter the name of the certificate to remove: " cert_name_remove
        local crt_file="$certs_dir/$cert_name_remove.crt"
        local key_file="$certs_dir/$cert_name_remove.key"
        
        if [[ -f "$crt_file" && -f "$key_file" ]]; then
            sudo rm -f "$crt_file" "$key_file" && echo -e "$(show_status 'success') ${GREEN}Removed $crt_file and $key_file.${RESET}"
        else
            echo -e "$(show_status 'error') ${RED}Certificate $cert_name_remove not found in $certs_dir${RESET}"
        fi
    }

    # list_certs_expiry [max_days]
    # Colors: >365d = GREEN, 181-365 = YELLOW, 91-180 = ORANGE, 0-90 = RED
    list_certs_expiry() {
        local certs_dir="${NEBULA_DIR:-/etc/nebula}/${NEBULA_CERT_FOLDER}"
        local max_days_filter="${1:-}" rows=()
        [[ -d "$certs_dir" ]] || { echo -e "$(show_status 'error') ${RED}Certificates dir not found: $certs_dir${RESET}"; return 1; }
        local now; now=$(date -u +%s)
        for cert in "$certs_dir"/*.crt; do
            [[ -f "$cert" ]] || continue
            local json; json=$("$NEBULA_BIN_PATH/nebula-cert" print -json -path "$cert") || continue
            local name type na epoch_na days_left color
            name=$(jq -r '.details.name' <<<"$json")
            type=$(jq -r '.details.isCa'  <<<"$json"); type=$([[ $type == true ]] && echo "CA" || echo "Cert")
            na=$(jq -r '.details.notAfter'  <<<"$json")
            epoch_na=$(date -d "$na" +%s 2>/dev/null || echo 0)
            days_left=$(( (epoch_na - now) / 86400 ))
            (( days_left < 0 )) && days_left=0
            # Optional filter
            if [[ -n "$max_days_filter" && "$max_days_filter" =~ ^[0-9]+$ ]]; then
                (( days_left <= max_days_filter )) || continue
            fi
            # Color thresholds
            if (( days_left > 365 )); then
                color="${GREEN}"
            elif (( days_left >= 181 )); then
                color="${YELLOW}"
            elif (( days_left >= 91 )); then
                color="${ORANGE}"
            else
                color="${RED}"
            fi
            # Humanize time
            local years=$(( days_left / 365 ))
            local rem=$(( days_left % 365 ))
            local months=$(( rem / 30 ))
            local days=$(( rem % 30 ))
            local human=""
            if (( years > 0 )); then
                human+="$years year$([[ $years -gt 1 ]] && echo "s")"
            fi
            if (( months > 0 )); then
                [[ -n "$human" ]] && human+=", "
                human+="$months month$([[ $months -gt 1 ]] && echo "s")"
            fi
            if (( days > 0 )); then
                if [[ -n "$human" ]]; then
                    human+=", and "
                fi
                human+="$days day$([[ $days -gt 1 ]] && echo "s")"
            fi
            [[ -z "$human" ]] && human="Expired"
            rows+=( "$(printf "%08d|%s|%s|%s|%s%s%s" "$days_left" "$name" "$type" "$na" "$color" "$human" "${RESET}")" )
        done
        [[ ${#rows[@]} -eq 0 ]] && { echo -e "${YELLOW}No matching certificates found in $certs_dir.${RESET}"; return 0; }
        IFS=$'\n' read -r -d '' -a sorted < <(printf "%s\n" "${rows[@]}" | sort -t '|' -k1,1n && printf '\0')
        # Header
        local border_len=94
        printf "${CYAN}%${border_len}s${RESET}\n" | tr ' ' '-'
        printf "${BOLD}${YELLOW} %-22s ${CYAN}|${YELLOW} %-4s ${CYAN}|${YELLOW} %-24s ${CYAN}|${YELLOW} %-30s ${RESET}\n" \
            "Name" "Type" "Not After (UTC)" "Expires In"
        printf "${CYAN}%${border_len}s${RESET}\n" | tr ' ' '-'
        for row in "${sorted[@]}"; do
            IFS='|' read -r _ name type na human <<<"$row"
            printf " ${CYAN}%-22s${RESET} | ${ORANGE}%-4s${RESET} | ${WHITE}%-24s${RESET} | %b\n" \
                "$(maxlen "$name" 22)" "$type" "$na" "$human"
        done
        printf "${CYAN}%${border_len}s${RESET}\n" | tr ' ' '-'
    }

    # Main menu for managing certificates
    dynamic_menu_title=("$MENU_PATH" "Certificate Management")
    dynamic_menu_options=("$(get_icon 'list')List Certificates" "$(get_icon 'create')Generate CA Certificate" "$(get_icon 'create')Generate Client Certificate" "$(get_icon 'inspect')View Certificate and Key Details" "$(get_icon 'hour-glass')Certificate Expiry" "$(get_icon 'revoke')Revoke Certificate" "$(get_icon 'error')Remove Certificate")
    dynamic_menu_functions=("list_certs" "generate_nebula_ca" "generate_nebula_cert" "view_cert_details" "list_certs_expiry" "revoke_cert" "remove_cert")
    dynamic_menu dynamic_menu_title dynamic_menu_options dynamic_menu_functions 1
}

# Function to view certificate and key details
view_cert_details() {
    local certs_dir="${NEBULA_DIR:-/etc/nebula}/${NEBULA_CERT_FOLDER}"
    local ca_cert_file="${NEBULA_DIR}/ca.crt"
    local cert_name cert_file key_file

    # Ensure the certs directory exists
    [[ -d "$certs_dir" ]] || { echo -e "$(show_status 'error') ${RED}Certificates directory $certs_dir does not exist.${RESET}"; return 1; }

    # Display available certificates to choose from
    local certs_list=""
    for cert in "$certs_dir"/*.crt; do
        [[ -f "$cert" ]] && certs_list+="${CYAN}$(basename "$cert" .crt)${RESET}, "
    done
    certs_list=${certs_list%, } # Remove trailing comma and space

    # Prompt user to select a certificate
    echo -e "    ${YELLOW}${BOLD}Certificates:${RESET} ${YELLOW}${certs_list}${RESET}"
    read -p "$(show_status 'question') Enter the name of the certificate to view details: " cert_name

    # Define paths for the selected cert and key files
    cert_file="$certs_dir/$cert_name.crt"
    key_file="$certs_dir/$cert_name.key"

    # Show cert file
    if [[ -f "$cert_file" ]]; then
        echo -e "\n${BG_BLUE}${BOLD}${WHITE} CERTIFICATE — Copy from BEGIN to END ${RESET}"
        echo -e "${YELLOW}File: ${BOLD}${cert_name}.crt${RESET}"
        echo -e "${YELLOW}------------------------------------------------------------${RESET}"
        cat "$cert_file"
        echo -e "${YELLOW}------------------------------------------------------------${RESET}"
    else
        echo -e "$(show_status 'error') ${RED}Missing certificate file: $cert_file${RESET}"
    fi

    # Show key file
    if [[ -f "$key_file" ]]; then
        echo -e "\n${BG_RED}${BOLD}${WHITE} PRIVATE KEY — Copy from BEGIN to END ${RESET}"
        echo -e "${YELLOW}File: ${BOLD}${cert_name}.key${RESET}"
        echo -e "${YELLOW}------------------------------------------------------------${RESET}"
        cat "$key_file"
        echo -e "${YELLOW}------------------------------------------------------------${RESET}"
    else
        echo -e "$(show_status 'error') ${RED}Missing key file: $key_file${RESET}"
    fi

    # Display CA certificate details if the CA file exists
    if [[ -f "$ca_cert_file" ]]; then
        echo -e "\n${BG_GREEN}${BOLD}${WHITE} CA CERTIFICATE — Copy from BEGIN to END ${RESET}"
        echo -e "${YELLOW}File: ca.crt${RESET}"
        echo -e "${YELLOW}------------------------------------------------------------${RESET}"
        cat "$ca_cert_file"
        echo -e "${YELLOW}------------------------------------------------------------${RESET}"
    else
        echo -e "$(show_status 'warning') ${YELLOW}CA certificate (ca.crt) not found in $NEBULA_DIR.${RESET}"
    fi

}

# Function to generate a CA using nebula-cert
generate_nebula_ca() {
    # Use $NEBULA_DIR or default to /etc/nebula if not set
    local nebula_dir="${NEBULA_DIR:-/etc/nebula}"
    local ca_key="$nebula_dir/ca.key"
    local ca_crt="$nebula_dir/ca.crt"

    # Ensure the directory exists
    [[ -d "$nebula_dir" ]] || { echo -e "$(show_status 'error') ${RED}Nebula directory $nebula_dir does not exist.${RESET}"; exit 1; }

    # Check if CA already exists
    if [[ -f "$ca_key" && -f "$ca_crt" ]]; then
        echo -e "$(show_status 'info') ${YELLOW}CA already exists:${RESET}"
        "$NEBULA_BIN_PATH/nebula-cert" print -path "$ca_crt"
        read -p "$(show_status 'question') CA already exists. Do you want to overwrite it? (y/n): " overwrite
        [[ "$overwrite" != "y" ]] && { echo -e "$(show_status 'info') ${YELLOW}CA generation canceled.${RESET}"; return; }
    fi

    # Prompt user for input and continue asking until a valid response is given
    while [[ -z "$ca_name" ]]; do 
        read -p "$(show_status 'question') Enter the CA name (required): " ca_name
        #[[ -z "$ca_name" ]] && echo -e "$(show_status 'error') ${RED}CA name is required. Please enter a valid CA name.${RESET}"
    done

    # Optional fields with ability to leave blank for defaults
    read -p "$(show_status 'question') Enter the duration (default 999999h, press enter to skip): " ca_duration
    read -p "$(show_status 'question') Enter groups (optional, comma-separated, press enter to skip): " ca_groups
    read -p "$(show_status 'question') Enter IPs (optional, comma-separated CIDR, press enter to skip): " ca_ips
    read -p "$(show_status 'question') Enter subnets (optional, comma-separated CIDR, press enter to skip): " ca_subnets
    read -p "$(show_status 'question') Use encryption for the private key? (y/n, default n): " use_encrypt
    [[ "$use_encrypt" == "y" ]] && encrypt_flag="-encrypt" || encrypt_flag=""

    # Set default values
    ca_duration="${ca_duration:-999999h}"

    # Construct the command with dynamic arguments
    cmd="$NEBULA_BIN_PATH/nebula-cert ca -name \"$ca_name\" -duration \"$ca_duration\""
    [[ -n "$ca_groups" ]] && cmd="$cmd -groups \"$ca_groups\""
    [[ -n "$ca_ips" ]] && cmd="$cmd -ips \"$ca_ips\""
    [[ -n "$ca_subnets" ]] && cmd="$cmd -subnets \"$ca_subnets\""
    cmd="$cmd $encrypt_flag -out-key ca.key -out-crt ca.crt"

    # Run the command
    rm "$nebula_dir/ca.crt" "$nebula_dir/ca.key"
    cd "$nebula_dir" || { echo -e "$(show_status 'error') ${RED}Failed to change to Nebula directory $nebula_dir. Exiting.${RESET}"; exit 1; }
    eval "$cmd" \
        && echo -e "$(show_status 'success') ${GREEN}CA generated: $nebula_dir/ca.key, $nebula_dir/ca.crt${RESET}" \
        || { echo -e "$(show_status 'error') ${RED}Failed to generate CA.${RESET}"; exit 1; }
}

# Function to generate Nebula certs using nebula-cert
generate_nebula_cert() {
    local certs_dir="${NEBULA_DIR:-/etc/nebula}/${NEBULA_CERT_FOLDER}"
    # Declare, ensuring they are reset each time
    local cert_gen_name cert_gen_ip cert_gen_groups include_subnets_choice cert_gen_subnets cert_gen_duration
    # Ensure directories exist
    [[ -d "$NEBULA_DIR" ]] || { echo "$(show_status 'error') Nebula directory does not exist. Exiting."; exit 1; }
    [[ -d "$certs_dir" ]] || sudo mkdir -p "$certs_dir" || { echo "$(show_status 'error') Failed to create $certs_dir. Exiting."; exit 1; }
    # Prompt user for cert details, requiring non-empty input for cert_name and cert_ip
    while [[ -z "$cert_gen_name" ]]; do read -p "$(show_status 'question') Enter the certificate name: " cert_gen_name; done
    # Check if certificate already exists
    if [[ -f "$certs_dir/$cert_gen_name.crt" ]]; then
        echo -e "$(show_status 'info') ${YELLOW}Certificate $cert_gen_name already exists in $certs_dir${RESET}"
        echo -e "$(show_status 'info') ${CYAN}Certificate details:${RESET}"
        "$NEBULA_BIN_PATH/nebula-cert" print -path "$certs_dir/$cert_gen_name.crt"
        # Ask user if they want to overwrite
        read -p "$(show_status 'question') Do you want to overwrite this certificate? (y/n): " overwrite_choice
        if [[ "$overwrite_choice" != "y" ]]; then
            echo -e "$(show_status 'info') ${YELLOW}Certificate generation aborted.${RESET}"
            return
        fi
    fi
    # Prompt for IP address with validation and uniqueness check
    while true; do
        read -p "$(show_status 'question') Enter the IP address (e.g., 192.168.222.16/24): " cert_gen_ip
        if [[ "$cert_gen_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/([0-9]|[1-2][0-9]|3[0-2]))?$ ]]; then
            [[ "$cert_gen_ip" =~ / ]] || cert_gen_ip="${cert_gen_ip}/24"

            local ip_taken=false
            for existing_crt in "$certs_dir"/*.crt; do
                [[ -f "$existing_crt" ]] || continue
                if "$NEBULA_BIN_PATH/nebula-cert" print -json -path "$existing_crt" | jq -e --arg ip "$cert_gen_ip" '.details.ips[]? == $ip' > /dev/null; then
                    local used_by=$(basename "$existing_crt")
                    echo -e "$(show_status 'error') ${RED}IP $cert_gen_ip is already assigned in ${CYAN}$used_by${RED}. Choose another.${RESET}"
                    ip_taken=true
                    break
                fi
            done

            [[ "$ip_taken" == false ]] && break
        else
            echo -e "$(show_status 'error') ${RED}Invalid IP address. Please enter a valid IP (e.g., 192.168.222.16/24).${RESET}"
        fi
    done
    read -p "$(show_status 'question') Enter the groups (optional, e.g., servers,desktops): " cert_gen_groups
    # Ask if the user wants to include subnets
    read -p "$(show_status 'question') Do you want to include subnets for this certificate? (y/n): " include_subnets_choice
    if [[ "$include_subnets_choice" == "y" ]]; then
        read -p "$(show_status 'question') Enter the subnets in CIDR format (comma-separated, e.g., 192.168.1.0/24,10.0.0.0/16): " cert_gen_subnets
    fi
    # Optional: set certificate duration in HOURS (press Enter to skip)
    while true; do
        read -p "$(show_status 'question') Set certificate duration in hours (press Enter to skip and inherit CA expiration): " cert_gen_duration
        [[ -z "$cert_gen_duration" ]] && break
        if [[ "$cert_gen_duration" =~ ^[0-9]+$ ]]; then
            break
        else
            echo -e "$(show_status 'error') ${RED}Please enter a whole number of hours (e.g., 720), or press Enter to skip.${RESET}"
        fi
    done
    # Construct the nebula-cert command
    local nebula_cert_cmd="$NEBULA_BIN_PATH/nebula-cert sign -name \"$cert_gen_name\" -ip \"$cert_gen_ip\""
    [[ -n "$cert_gen_duration" ]] && nebula_cert_cmd+=" -duration \"${cert_gen_duration}h\""
    [[ -n "$cert_gen_groups" ]] && nebula_cert_cmd+=" -groups \"$cert_gen_groups\""
    [[ -n "$cert_gen_subnets" ]] && nebula_cert_cmd+=" -subnets \"$cert_gen_subnets\""
    # Generate certificate and move to certs directory
    cd "$NEBULA_DIR" || { echo "$(show_status 'error') Failed to change to $NEBULA_DIR. Exiting."; exit 1; }
    eval "$nebula_cert_cmd" \
        && sudo mv "${cert_gen_name}"* "$certs_dir" \
        && echo -e "$(show_status 'success') ${GREEN}Certificate generation complete. Saved in $certs_dir/$cert_gen_name.crt and $certs_dir/$cert_gen_name.key${RESET}" \
        || { echo -e "$(show_status 'error') ${RED}Failed to generate or move certificates. Exiting.${RESET}"; exit 1; }
}

# Function to remove Nebula with confirmation
remove_nebula() {
    echo -e -n "$(show_status 'question') ${RED}Are you sure you want to remove Nebula? This action cannot be undone.${RESET} (y/n): "
    read -p "" confirmation
    if [[ "$confirmation" != "y" ]]; then
        echo -e "$(show_status 'error') ${YELLOW}Nebula removal canceled${RESET}"
        return
    fi
    echo -e "$(show_status 'info') ${CYAN}Removing Nebula...${RESET}"
    if [[ -f "$NEBULA_BIN_PATH/nebula" || -f "$NEBULA_BIN_PATH/nebula-cert" ]]; then
        sudo rm -f "$NEBULA_BIN_PATH/nebula" "$NEBULA_BIN_PATH/nebula-cert" \
        && echo -e "$(show_status 'success') ${GREEN}Nebula removed successfully.${RESET}" \
        || echo -e "$(show_status 'error') ${RED}Failed to remove Nebula binaries.${RESET}"
        remove_nebula_service
        exit 0
    else
        echo -e "$(show_status 'error') ${YELLOW}Nebula is not installed.${RESET}"
    fi
}

# Function to toggle the Nebula service
toggle_nebula_service() {
    local service_name; service_name=$(basename "$NEBULA_SERVICE")
    check_nebula_config "$NEBULA_DIR/config.yml" || return
    local cur; systemctl is-active --quiet "$service_name" && cur=active || cur=inactive
    echo -e "$(show_status 'info') ${CYAN}Current state:${RESET} ${YELLOW}${cur}${RESET}"
    local action target; if [[ $cur == active ]]; then action=stop; target=inactive; else action=start; target=active; fi
    echo -ne "$(show_status 'question') ${CYAN}Do you want to ${YELLOW}${action}${CYAN} the service? [y/N]: ${RESET}"
    read -r r
    [[ $r =~ ^[Yy]$ ]] || { echo -e "$(show_status 'info') ${YELLOW}Canceled.${RESET}"; return; }
    if [[ $action == start ]]; then
        sudo systemctl start "$service_name" --no-block
    else
        sudo systemctl stop "$service_name"
    fi
    # wait up to 10s for target state
    for _ in {1..10}; do
        systemctl is-active --quiet "$service_name" && new=active || new=inactive
        [[ $new == "$target" ]] && break
        sleep 1
    done
    show_system_info
    [[ $new == "$target" ]] || { echo -e "$(show_status 'warn') ${ORANGE}Did not reach expected state '${target}'.${RESET}"; return 1; }
}

# Function to show the spinner
start_spinner() {
    local message="$1"
    SPINNER_ACTIVE=true
    tput civis
    (
        local sp='|/-\'
        local i=0
        while $SPINNER_ACTIVE; do
            echo -ne "\r$(show_status 'success') ${YELLOW}${message} ${sp:i++%${#sp}:1} ${RESET}"
            sleep 0.1
        done
    ) &
    SPINNER_PID=$!
}

# Function to stop the spinner
stop_spinner() {
    SPINNER_ACTIVE=false
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null
        unset SPINNER_PID
    fi
    tput cnorm
    printf "\r\033[K" # clear line
}

# Function to check each node if they are online and their ping (parallel)
check_node_connectivity() {
    local certs_dir="${NEBULA_DIR:-/etc/nebula}/${NEBULA_CERT_FOLDER}"
    [[ -d "$certs_dir" ]] || { echo -e "$(show_status 'error') ${RED}Certificates directory $certs_dir does not exist.${RESET}"; return 1; }

    # Row storage so we can select later
    local -a ROW_NAMES=()
    local -a ROW_IPS=()
    local idx=1

    # Table borders/headers
    local border_len=78
    local border_line
    border_line=$(printf '%*s' "$border_len" '' | tr ' ' '-')

    # Temp for parallel results
    local tmp_ping_out; tmp_ping_out="$(mktemp)"
    local MAX_JOBS=32 jobs=0

    start_spinner "Checking node connectivity..."

    # Launch pings in parallel and collect results
    for cert in "$certs_dir"/*.crt; do
        [[ -f "$cert" ]] || continue
        local json name
        json=$("$NEBULA_BIN_PATH/nebula-cert" print -json -path "$cert") || continue
        name=$(jq -r '.details.name' <<<"$json")

        while read -r ip; do
            [[ -n "$ip" ]] || continue
            local ip_str="${ip%%/*}" this_idx this_name
            this_idx=$idx
            this_name=$name

            {
                if ping_output=$(ping -c 1 -W 1 "$ip_str" 2>/dev/null); then
                    ping_time=$(awk -F'=' '/time=/{print $4}' <<<"$ping_output" | awk '{print $1}')
                    [[ -z "$ping_time" ]] && ping_time=$(grep -oE 'time=[0-9.]+' <<<"$ping_output" | cut -d= -f2)
                    printf "%s|%s|%s|online|%s\n" "$this_idx" "$this_name" "$ip_str" "${ping_time:-0}"
                else
                    printf "%s|%s|%s|offline|timeout\n" "$this_idx" "$this_name" "$ip_str"
                fi
            } >>"$tmp_ping_out" &

            ((jobs++))
            ((jobs>=MAX_JOBS)) && { wait -n 2>/dev/null || true; ((jobs--)); }

            ROW_NAMES[idx]="$name"
            ROW_IPS[idx]="$ip_str"
            ((idx++))
        done < <(jq -r '.details.ips[]' <<<"$json")
    done

    # Wait for all pings to finish
    while ((jobs>0)); do wait -n 2>/dev/null || break; ((jobs--)); done

    stop_spinner

    # Print table
    echo -e "${BOLD}${CYAN}${border_line}${RESET}"
    printf "${BOLD}${CYAN}| ${YELLOW}%-3s${CYAN}| ${YELLOW}%-22s${CYAN}| ${YELLOW}%-19s${CYAN}| ${YELLOW}%-11s${CYAN}| ${YELLOW}%-12s${CYAN}|\n" \
        "#" "Node Name:" "IP Address:" "Status:" "Ping:"
    echo -e "${BOLD}${CYAN}${border_line}${RESET}"

    while IFS='|' read -r r_idx r_name r_ip r_state r_ping; do
        local status_display ping_display ping_color ping_int
        if [[ "$r_state" == "online" ]]; then
            ping_int=${r_ping%.*}
            if (( ping_int < 50 )); then
                ping_color=$GREEN
            elif (( ping_int < 150 )); then
                ping_color=$YELLOW
            else
                ping_color=$ORANGE
            fi
            status_display="${GREEN}$(printf '%-13s' '✔ Online')${RESET}"
            ping_display="${ping_color}$(printf '%-12s' "${r_ping} ms")${RESET}"
        else
            status_display="${RED}$(printf '%-13s' '✘ Offline')${RESET}"
            ping_display="${WHITE}$(printf '%-12s' 'timeout')${RESET}"
        fi

        printf "${CYAN}| ${ORANGE}%-3s${CYAN}| ${YELLOW}%-22s${CYAN}| ${ORANGE}%-19s${CYAN}| %b${CYAN}| %b${CYAN}|\n" \
            "$r_idx" "$r_name" "$r_ip" "$status_display" "$ping_display"
    done < <(sort -t'|' -k1,1n "$tmp_ping_out")

    echo -e "${BOLD}${CYAN}${border_line}${RESET}"
    rm -f "$tmp_ping_out"

    # Optional iperf3 runner
    read -rp "$(show_status 'question') Run an iperf3 throughput test to one of the above nodes? [y/N]: " run_test
    [[ "$run_test" =~ ^[Yy]$ ]] || return 0

    if ! command -v iperf3 >/dev/null 2>&1; then
        echo -e "$(show_status 'error') ${RED}iperf3 is not installed. Please install it and try again.${RESET}"
        return 1
    fi

    local max=$((idx-1)) sel
    if (( max < 1 )); then
        echo -e "$(show_status 'error') ${RED}No targets available for iperf3.${RESET}"
        return 1
    fi

    # Ask for index
    while :; do
        read -rp "$(show_status 'question') Enter # (1-$max) or 'q' to cancel: " sel
        [[ "$sel" == "q" || "$sel" == "Q" ]] && return 0
        [[ "$sel" =~ ^[0-9]+$ && sel -ge 1 && sel -le max ]] && break
        echo -e "$(show_status 'warn') ${YELLOW}Invalid selection.${RESET}"
    done

    local target_ip="${ROW_IPS[sel]}"
    local target_name="${ROW_NAMES[sel]}"
    local port dur streams rev
    read -rp "$(show_status 'info') Port [5201]: " port;     port=${port:-5201}
    read -rp "$(show_status 'info') Duration seconds [10]: " dur; dur=${dur:-10}
    read -rp "$(show_status 'info') Parallel streams [-P] [1]: " streams; streams=${streams:-1}
    read -rp "$(show_status 'info') Reverse test (server→client) [y/N]: " rev

    echo -e "$(show_status 'start') ${CYAN}Running iperf3 to ${MAGENTA}${target_name}${CYAN} (${ORANGE}${target_ip}${CYAN})…${RESET}"
    if [[ "$rev" =~ ^[Yy]$ ]]; then
        iperf3 -c "$target_ip" -p "$port" -t "$dur" -P "$streams" -R
    else
        iperf3 -c "$target_ip" -p "$port" -t "$dur" -P "$streams"
    fi
    local rc=$?
    if (( rc == 0 )); then
        echo -e "$(show_status 'success') ${GREEN}iperf3 completed successfully.${RESET}"
    else
        echo -e "$(show_status 'error') ${RED}iperf3 exited with code ${rc}.${RESET}"
    fi
}

# Function to revoke a certificate by renaming it and adding its fingerprint to the blocklist
revoke_cert() {
    local service_name cert_dir config_file bin_path
    service_name=$(basename "$NEBULA_SERVICE")
    cert_dir="${NEBULA_DIR}/${NEBULA_CERT_FOLDER}"
    config_file="${NEBULA_DIR}/config.yml"
    bin_path="$NEBULA_BIN_PATH/nebula-cert"

    echo -e "$(show_status 'info') ${YELLOW}Current Revoked Certificates:${RESET}"

    # Display existing revoked fingerprints with reasons (parse YAML manually)
    local in_blocklist=false i=0
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*blocklist: ]] && in_blocklist=true && continue
        [[ "$in_blocklist" = true && ! "$line" =~ ^[[:space:]]*-[[:space:]] ]] && in_blocklist=false
        if [[ "$in_blocklist" == true && "$line" =~ -[[:space:]]+([^#[:space:]]+)[[:space:]]*(#.*)?$ ]]; then
            local fp="${BASH_REMATCH[1]}"
            local reason="${BASH_REMATCH[2]}"
            [[ $reason =~ ^[[:space:]]*#[[:space:]]*(.*)$ ]] && reason="${BASH_REMATCH[1]}"
            local match="Unknown cert name"
            for cert in "$cert_dir"/*.crt.revoked; do
                [[ -f "$cert" ]] || continue
                local cert_fp=$("$bin_path" print -json -path "$cert" | jq -r '.fingerprint')
                [[ "$cert_fp" == "$fp" ]] && match=$(basename "$cert" .crt.revoked) && break
            done
            echo -e "    ${YELLOW}[$(($i+1))]${RESET} ${CYAN}$fp${RESET} - $match${reason:+ (${MAGENTA}$reason${RESET})}"
            ((i++))
        fi
    done < "$config_file"

    # If none matched/printed, show a friendly message
    if (( i == 0 )); then
        printf "%b\n" "    ${ORANGE}No revoked fingerprints found in blocklist.${RESET}"
    fi

    # Ask what to do (add/remove/back) in a loop
    local action=""
    while :; do
        echo -ne "\n$(show_status 'question') What would you like to do? [${YELLOW}a${RESET}]dd / [${YELLOW}r${RESET}]emove / [${YELLOW}b${RESET}]ack: "
        read -r action
        case "${action,,}" in
            a|add|1)    action="add";    break ;;
            r|remove|2) action="remove"; break ;;
            b|back|q|0)
                echo -e "$(show_status 'info') ${YELLOW}Returning to previous menu.${RESET}"
                return
                ;;
            *) echo -e "$(show_status 'error') ${RED}Invalid choice. Please type a/r/b.${RESET}" ;;
        esac
    done

    if [[ "$action" == "remove" ]]; then
        echo -ne "$(show_status 'question') Enter fingerprint to remove from revocation list: "
        read -r fp_to_remove
        if [[ -z "$fp_to_remove" ]]; then
            echo -e "$(show_status 'error') ${RED}No fingerprint provided.${RESET}"
            return
        fi
        # Use sed to delete the matching line (fingerprint)
        sed -i "/- $fp_to_remove/d" "$config_file"
        echo -e "$(show_status 'success') ${GREEN}Removed fingerprint ${CYAN}$fp_to_remove${GREEN} from blocklist.${RESET}"

        for cert in "$cert_dir"/*.crt.revoked; do
            [[ -f "$cert" ]] || continue
            local cert_fp=$("$bin_path" print -json -path "$cert" | jq -r '.fingerprint')
            if [[ "$cert_fp" == "$fp_to_remove" ]]; then
                local base="${cert%.crt.revoked}"
                mv "$cert" "${base}.crt"
                [[ -f "${base}.key.revoked" ]] && mv "${base}.key.revoked" "${base}.key"
                echo -e "$(show_status 'info') ${YELLOW}Restored certificate: $(basename "$base")${RESET}"
                break
            fi
        done

        read -p "$(show_status 'question') Reload Nebula service to apply changes? (y/n): " reload_choice
        [[ "$reload_choice" == "y" ]] && sudo systemctl reload "$service_name" && echo -e "$(show_status 'success') ${GREEN}Nebula service reloaded.${RESET}"
        return
    fi

    # ADD mode
    local cert_name_or_fingerprint fingerprint cert_file cert_key revoke_choice revoke_by_name=true

    while [[ "$revoke_choice" != "1" && "$revoke_choice" != "2" ]]; do
        echo -ne "$(show_status 'question') Revoke by certificate name (${YELLOW}1${RESET}) or fingerprint (${YELLOW}2${RESET})?: " 
        read -r revoke_choice
    done

    if [[ "$revoke_choice" == "1" ]]; then
        echo -e "    ${YELLOW}${BOLD}Certificates:${RESET}"
        for cert in "$cert_dir"/*.crt; do
            [[ -f "$cert" ]] && echo "      - $(basename "$cert" .crt)"
        done
        read -p "$(show_status 'question') Enter the certificate name to revoke: " cert_name_or_fingerprint
        cert_file="${cert_dir}/$cert_name_or_fingerprint.crt"
        cert_key="${cert_dir}/$cert_name_or_fingerprint.key"
        if [[ ! -f "$cert_file" || ! -f "$cert_key" ]]; then
            echo -e "$(show_status 'error') ${RED}Certificate not found: $cert_name_or_fingerprint${RESET}"
            return
        fi
        fingerprint=$("$bin_path" print -json -path "$cert_file" | jq -r '.fingerprint')
    else
        read -p "$(show_status 'question') Enter the full certificate fingerprint to revoke: " fingerprint
        revoke_by_name=false
    fi

    if grep -q "$fingerprint" "$config_file"; then
        echo -e "$(show_status 'info') ${YELLOW}Fingerprint already revoked: ${CYAN}$fingerprint${RESET}"
        return
    fi

    read -p "$(show_status 'question') Enter a reason for revocation: " reason

    if [[ "$revoke_by_name" == true ]]; then
        mv "$cert_file" "$cert_file.revoked"
        mv "$cert_key" "$cert_key.revoked"
    fi

    # Append the fingerprint + reason to the blocklist using sed (preserving comments)
    sed -i "/^ *blocklist:/a \ \ \ \ - $fingerprint # $reason" "$config_file"
    echo -e "$(show_status 'success') ${GREEN}Added fingerprint ${CYAN}$fingerprint${GREEN} to blocklist with reason: ${MAGENTA}$reason${RESET}"

    read -p "$(show_status 'question') Reload Nebula service to apply changes? (y/n): " reload_choice
    [[ "$reload_choice" == "y" ]] && sudo systemctl reload "$service_name" && echo -e "$(show_status 'success') ${GREEN}Nebula service reloaded.${RESET}"
}

# Function for top-level menu to manage Nebula firewall settings
manage_firewall() {
    local config_file="$NEBULA_DIR/config.yml"
    [[ -f "$config_file" ]] || { echo -e "$(show_status 'error') ${RED}Config file not found: $config_file${RESET}"; return 1; }
    # dynamic_menu_title=("$MENU_PATH" "Config" "Firewall")
    # dynamic_menu_options=(
    #     "$(get_icon 'left-arrow')Configure Inbound Rules ${GREEN}(Default Action: ${RED}$(yq -r ".firewall.inbound_action" "$config_file")${GREEN})${RESET}"
    #     "$(get_icon 'right-arrow')Configure Outbound Rules ${GREEN}(Default Action: ${RED}$(yq -r ".firewall.outbound_action" "$config_file")${GREEN})${RESET}"
    #     "$(get_icon 'security')Configure General Firewall Settings"
    # )
    # dynamic_menu_functions=(
    #     "configure_inbound_rules"
    #     "configure_outbound_rules"
    #     "configure_firewall_settings"
    # )
    # dynamic_menu dynamic_menu_title dynamic_menu_options dynamic_menu_functions
    while true; do
        show_menu_header "$MENU_PATH" "Config" "Firewall"
        echo -e "        ${BOLD}${YELLOW}1.${RESET} $(get_icon 'left-arrow')Configure Inbound Rules ${GREEN}(Default Action: ${RED}$(yq -r ".firewall.inbound_action" "$config_file")${GREEN})${RESET}"
        echo -e "        ${BOLD}${YELLOW}2.${RESET} $(get_icon 'right-arrow')Configure Outbound Rules ${GREEN}(Default Action: ${RED}$(yq -r ".firewall.outbound_action" "$config_file")${GREEN})${RESET}"
        echo -e "        ${BOLD}${YELLOW}3.${RESET} $(get_icon 'security')Configure General Firewall Settings"
        echo -e "        ${BOLD}${YELLOW}4.${RESET} $(get_icon 'back')${BOLD}Go Back${RESET}"
        read -p "$(show_status 'question') Choose an option [1-4]: " choice
        case "$choice" in
            1) configure_inbound_rules ;;
            2) configure_outbound_rules ;;
            3) configure_firewall_settings ;;
            4) break ;;
            *) echo -e "$(show_status 'error') ${RED}Invalid option. Please choose again.${RESET}" ;;
        esac
    done
}

# Function to configure basic firewall settings
configure_firewall_settings() {
    local config_file="$NEBULA_DIR/config.yml"
    echo -e "\n$(show_status 'info') ${YELLOW}Configuring ${CYAN}general firewall settings${RESET}. Press Enter to skip a setting."
    for key in outbound_action inbound_action; do
        local current=$(yq -r ".firewall.$key" "$config_file")
        read -rp "$(printf "${YELLOW}firewall.$key${RESET} [${CYAN}%s${RESET}]: " "$current")" input
        [[ -n "$input" ]] && yq -i -y ".firewall.$key = \"$input\"" "$config_file"
    done
    echo -e "${YELLOW}Edit conntrack timeouts (press Enter to skip):${RESET}"
    for key in tcp_timeout udp_timeout default_timeout; do
        local current=$(yq -r ".firewall.conntrack.$key" "$config_file")
        read -rp "$(printf "${YELLOW}firewall.conntrack.$key${RESET} [${CYAN}%s${RESET}]: " "$current")" input
        [[ -n "$input" ]] && yq -i -y ".firewall.conntrack.$key = \"$input\"" "$config_file"
    done
}

# Function to configure inbound firewall rules
configure_inbound_rules() {
    local config_file="$NEBULA_DIR/config.yml"
    local table_width=115
    while true; do
        echo -e "\n${CYAN}Current Inbound Rules:                                                                       ${GREEN}[Default Action: ${RED}$(yq -r ".firewall.inbound_action" "$config_file")${GREEN}]${RESET}"
        printf "${CYAN}%${table_width}s${RESET}\n" | tr ' ' '-'
        printf "${BOLD}${YELLOW} %-4s | %-8s | %-6s | %-15s | %-20s | %-20s | %-20s ${RESET}\n" "Idx" "Port" "Proto" "Host" "Group(s)" "CIDR" "Local CIDR"
        printf "${CYAN}%${table_width}s${RESET}\n" | tr ' ' '-'
        local rule_count=$(yq '.firewall.inbound | length' "$config_file")
        for ((i = 0; i < rule_count; i++)); do
            local port=$(yq -r ".firewall.inbound[$i].port // \"any\"" "$config_file")
            local proto=$(yq -r ".firewall.inbound[$i].proto // \"any\"" "$config_file")
            local host=$(yq -r ".firewall.inbound[$i].host // \"any\"" "$config_file")
            local groups=$(yq -r ".firewall.inbound[$i].groups // [] | join(\", \")" "$config_file")
            local cidr=$(yq -r ".firewall.inbound[$i].cidr // \"\"" "$config_file")
            local local_cidr=$(yq -r ".firewall.inbound[$i].local_cidr // \"\"" "$config_file")
            printf " %-4s | %-8s | %-6s | %-15s | %-20s | %-20s | %-20s \n" \
                "$i" "$port" "$proto" "$host" "$(maxlen "$groups" 20)" "$(maxlen "$cidr" 20)" "$(maxlen "$local_cidr" 20)"
        done
        printf "${CYAN}%${table_width}s${RESET}\n" | tr ' ' '-'
        read -rp "$(show_status 'question') Modify inbound rules? (add/delete/edit/skip): " action
        case "$action" in
            add)
                _edit_firewall_rule append "$config_file" inbound && echo -e "$(show_status 'success') ${GREEN}Rule added successfully.${RESET}" ;;
            delete)
                read -rp "Enter rule index to delete: " index
                if [[ "$index" =~ ^[0-9]+$ ]]; then
                    yq -i -y "del(.firewall.inbound[$index])" "$config_file" && echo -e "$(show_status 'success') ${GREEN}Rule $index deleted successfully.${RESET}"
                else
                    echo -e "$(show_status 'error') ${RED}Invalid index.${RESET}"
                fi ;;
            edit)
                read -rp "Enter rule index to edit: " index
                if [[ "$index" =~ ^[0-9]+$ ]]; then
                    _edit_firewall_rule "$index" "$config_file" inbound && echo -e "$(show_status 'success') ${GREEN}Rule $index edited successfully.${RESET}"
                else
                    echo -e "$(show_status 'error') ${RED}Invalid index.${RESET}"
                fi ;;
            skip|*)
                break ;;
        esac
    done
}

# Function to configure outbound firewall rules
configure_outbound_rules() {
    local config_file="$NEBULA_DIR/config.yml"
    local table_width=115
    while true; do
        echo -e "\n${CYAN}Current Outbound Rules:                                                                       ${GREEN}[Default Action: ${RED}$(yq -r ".firewall.inbound_action" "$config_file")${GREEN}]${RESET}"
        printf "${CYAN}%${table_width}s${RESET}\n" | tr ' ' '-'
        printf "${BOLD}${YELLOW} %-4s | %-8s | %-6s | %-15s | %-20s | %-20s | %-20s ${RESET}\n" "Idx" "Port" "Proto" "Host" "Group(s)" "CIDR" "Local CIDR"
        printf "${CYAN}%${table_width}s${RESET}\n" | tr ' ' '-'
        local rule_count=$(yq '.firewall.outbound | length' "$config_file")
        for ((i = 0; i < rule_count; i++)); do
            local port=$(yq -r ".firewall.outbound[$i].port // \"any\"" "$config_file")
            local proto=$(yq -r ".firewall.outbound[$i].proto // \"any\"" "$config_file")
            local host=$(yq -r ".firewall.outbound[$i].host // \"any\"" "$config_file")
            local groups=$(yq -r ".firewall.outbound[$i].groups // [] | join(\", \" )" "$config_file")
            local cidr=$(yq -r ".firewall.outbound[$i].cidr // \"\"" "$config_file")
            local local_cidr=$(yq -r ".firewall.outbound[$i].local_cidr // \"\"" "$config_file")
            printf " %-4s | %-8s | %-6s | %-15s | %-20s | %-20s | %-20s \n" \
                "$i" "$port" "$proto" "$host" "$(maxlen "$groups" 20)" "$(maxlen "$cidr" 20)" "$(maxlen "$local_cidr" 20)"            
        done
        printf "${CYAN}%${table_width}s${RESET}\n" | tr ' ' '-'
        read -rp "$(show_status 'question') Modify outbound rules? (add/delete/edit/skip): " action
        case "$action" in
            add)
                _edit_firewall_rule append "$config_file" outbound && echo -e "$(show_status 'success') ${GREEN}Rule added successfully.${RESET}" ;;
            delete)
                read -rp "Enter rule index to delete: " index
                if [[ "$index" =~ ^[0-9]+$ ]]; then
                    yq -i -y "del(.firewall.outbound[$index])" "$config_file" && echo -e "$(show_status 'success') ${GREEN}Rule $index deleted successfully.${RESET}"
                else
                    echo -e "$(show_status 'error') ${RED}Invalid index.${RESET}"
                fi ;;
            edit)
                read -rp "Enter rule index to edit: " index
                if [[ "$index" =~ ^[0-9]+$ ]]; then
                    _edit_firewall_rule "$index" "$config_file" outbound && echo -e "$(show_status 'success') ${GREEN}Rule $index edited successfully.${RESET}"
                else
                    echo -e "$(show_status 'error') ${RED}Invalid index.${RESET}"
                fi ;;
            skip|*)
                break ;;
        esac
    done
}

# Helper function to add or edit a firewall rule
_edit_firewall_rule() {
    local index="$1"
    local config_file="$2"
    local direction="${3:-inbound}"
    local prefix=".firewall.$direction"
    local is_new=0

    declare -A rule_fields=(
        [port]="Port (e.g. 80, 200-300, any, fragment)"
        [proto]="Protocol (any, tcp, udp, icmp)"
        [host]="Host (e.g. any or hostname)"
        [cidr]="Remote CIDR (e.g. 0.0.0.0/0 or ::/0)"
        [local_cidr]="Local CIDR (e.g. 192.168.1.0/24)"
        [groups]="Groups (comma-separated)"
    )

    if [[ "$index" == "append" ]]; then
        is_new=1
        index=$(yq "$prefix | length" "$config_file")
        yq -i -y "$prefix += [{}]" "$config_file"
    fi

    echo -e "$(show_status 'info') ${YELLOW}Configuring ${CYAN}$direction firewall${RESET}."
    echo -e "${YELLOW}Instructions:${RESET} Press Enter to skip a setting, or enter '-' to delete a field (except for port and proto)."

    for field in port proto host cidr local_cidr; do
        local current=$(yq -r "$prefix[$index].$field // \"\"" "$config_file")
        local input=""
        while true; do
            printf "${YELLOW}%s${RESET} [${CYAN}%s${RESET}]: " "${rule_fields[$field]}" "$current"
            read input

            # Enforce required fields on new rules
            if [[ "$is_new" -eq 1 && -z "$input" && ( "$field" == "port" || "$field" == "proto" ) ]]; then
                echo -e "$(show_status 'error') ${RED}${field^} cannot be empty for new rules.${RESET}"
                continue
            fi

            # Skip unchanged
            if [[ -z "$input" ]]; then
                break
            fi

            # Attempt to delete
            if [[ "$input" == "-" ]]; then
                if [[ "$field" == "port" || "$field" == "proto" ]]; then
                    echo -e "$(show_status 'error') ${RED}Cannot delete required field: $field${RESET}"
                    continue
                else
                    yq -i -y "del($prefix[$index].$field)" "$config_file"
                    break
                fi
            fi

            # Validate input
            case "$field" in
                port)
                    if [[ "$input" =~ ^(any|fragment|[0-9]+(-[0-9]+)?)$ ]]; then break; fi ;;
                proto)
                    if [[ "$input" =~ ^(any|tcp|udp|icmp)$ ]]; then break; fi ;;
                host)
                    if [[ "$input" == "any" || "$input" =~ ^[a-zA-Z0-9._-]+$ ]]; then break; fi ;;
                cidr|local_cidr)
                    if [[ "$input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+$ || "$input" == "::/0" ]]; then break; fi ;;
            esac

            echo -e "$(show_status 'error') ${RED}Invalid ${field}. Try again.${RESET}"
        done


        # Save or delete the field
        if [[ "$input" == "-" ]]; then
            yq -i -y "del($prefix[$index].$field)" "$config_file"
        elif [[ -n "$input" ]]; then
            yq -i -y "$prefix[$index].$field = \"$input\"" "$config_file"
        fi
    done

    # Handle groups field separately
    local current_groups=$(yq -r "$prefix[$index].groups // [] | join(\", \")" "$config_file")
    printf "${YELLOW}%s${RESET} [${CYAN}%s${RESET}]: " "${rule_fields[groups]}" "$current_groups"
    read input
    if [[ "$input" == "-" ]]; then
        yq -i -y "del($prefix[$index].groups)" "$config_file"
    elif [[ -n "$input" ]]; then
        yq -i -y "$prefix[$index].groups = []" "$config_file"
        IFS=',' read -ra groups <<< "$input"
        for g in "${groups[@]}"; do
            g=$(echo "$g" | xargs)
            [[ -n "$g" ]] && yq -i -y "$prefix[$index].groups += [\"$g\"]" "$config_file"
        done
    fi

    check_nebula_config "$NEBULA_DIR/config.yml" "error"
    return 0
}

# Function to edit settings in Nebula config file
edit_nebula_config() {
    local config_file="${NEBULA_DIR:-/etc/nebula}/config.yml"
    [[ -f "$config_file" ]] || { echo -e "$(show_status 'error') ${RED}Config file not found: $config_file${RESET}"; return 1; }

    echo -e "$(show_status 'info') ${YELLOW}Configuring ${CYAN}$config_file${RESET}. Press Enter to skip a setting."

    # --- PKI section ---
    for key in ca cert key disconnect_invalid; do
        local current=$(yq -r ".pki.$key" "$config_file")
        read -rp "$(printf "${YELLOW}pki.$key${RESET} [${CYAN}%s${RESET}]: " "$current")" input
        [[ -n "$input" ]] && yq -i -y ".pki.$key = \"$input\"" "$config_file"
    done

    # --- static_host_map section ---
    echo -e "${YELLOW}Editing static_host_map entries.${RESET}"
    mapfile -t shm_keys < <(yq -r '.static_host_map | keys[]?' "$config_file")
    if ((${#shm_keys[@]})); then
        echo -e "${CYAN}Current entries:${RESET}"
        for key in "${shm_keys[@]}"; do
            val=$(yq -r ".static_host_map[\"$key\"][]" "$config_file")
            echo -e "  ${WHITE}$key => $val${RESET}"
        done
        read -rp "$(printf "${YELLOW}Delete static_host_map IPs (comma-separated), or press Enter to skip:${RESET} ")" del_input
        if [[ -n "$del_input" ]]; then
            IFS=',' read -ra DEL <<< "$del_input"
            for ip in "${DEL[@]}"; do
                trimmed=$(echo "$ip" | xargs)
                yq -i -y "del(.static_host_map.\"$trimmed\")" "$config_file"
            done
            echo -e "${GREEN}Deleted specified entries.${RESET}"
        fi
    else
        echo -e "${CYAN}(No current entries)${RESET}"
    fi

    echo -e "${YELLOW}Add new static_host_map entries. Leave internal IP blank to stop.${RESET}"
    local i=1
    while true; do
        read -rp "$(printf "${YELLOW}static_host_map [$i] - internal Nebula IP:${RESET} ")" ip
        [[ -z "$ip" ]] && break
        read -rp "$(printf "${YELLOW}Public IP of $ip:${RESET} ")" pub
        read -rp "$(printf "${YELLOW}Port of $ip:${RESET} ")" port
        [[ -n "$pub" && -n "$port" ]] && yq -i -y ".static_host_map.\"$ip\" = [\"$pub:$port\"]" "$config_file"
        ((i++))
    done

    # --- lighthouse section ---
    for key in am_lighthouse interval; do
        local current=$(yq -r ".lighthouse.$key" "$config_file")
        read -rp "$(printf "${YELLOW}lighthouse.$key${RESET} [${CYAN}%s${RESET}]: " "$current")" input
        [[ -n "$input" ]] && yq -i -y ".lighthouse.$key = $input" "$config_file"
    done

    echo -e "${YELLOW}Editing lighthouse.hosts list.${RESET}"
    mapfile -t current_hosts < <(yq -r '.lighthouse.hosts[]?' "$config_file")
    if ((${#current_hosts[@]})); then
        echo -e "${CYAN}Current lighthouse.hosts:${RESET}"
        for i in "${!current_hosts[@]}"; do
            echo -e "  [${i}] ${WHITE}${current_hosts[i]}${RESET}"
        done
        read -rp "$(printf "${YELLOW}Enter indices to delete (comma-separated), or press Enter to skip:${RESET} ")" del_input
        if [[ -n "$del_input" ]]; then
            IFS=',' read -ra del_indices <<< "$del_input"
            new_hosts=()
            for i in "${!current_hosts[@]}"; do
                skip=false
                for d in "${del_indices[@]}"; do
                    [[ "$i" -eq "$d" ]] && skip=true && break
                done
                $skip || new_hosts+=("${current_hosts[i]}")
            done
            yq -i -y '.lighthouse.hosts = []' "$config_file"
            for host in "${new_hosts[@]}"; do
                yq -i -y ".lighthouse.hosts += [\"$host\"]" "$config_file"
            done
        fi
    else
        echo -e "${CYAN}(No current entries)${RESET}"
    fi

    read -rp "$(printf "${YELLOW}Add lighthouse host IPs (comma-separated), or press Enter to skip:${RESET} ")" input
    if [[ -n "$input" ]]; then
        IFS=',' read -ra HOSTS <<< "$input"
        for host in "${HOSTS[@]}"; do
            trimmed=$(echo "$host" | xargs)
            [[ -n "$trimmed" ]] && yq -i -y ".lighthouse.hosts += [\"$trimmed\"]" "$config_file"
        done
    fi

    # --- listen section ---
    for key in host port; do
        local current=$(yq -r ".listen.$key" "$config_file")
        read -rp "$(printf "${YELLOW}listen.$key${RESET} [${CYAN}%s${RESET}]: " "$current")" input
        [[ -n "$input" ]] && yq -i -y ".listen.$key = \"$input\"" "$config_file"
    done

    # --- punchy section ---
    local current=$(yq -r ".punchy.punch" "$config_file")
    read -rp "$(printf "${YELLOW}punchy.punch${RESET} [${CYAN}%s${RESET}]: " "$current")" input
    [[ -n "$input" ]] && yq -i -y ".punchy.punch = $input" "$config_file"

    # --- relay section ---
    current=$(yq -r ".relay.am_relay" "$config_file")
    read -rp "$(printf "${YELLOW}relay.am_relay${RESET} [${CYAN}%s${RESET}]: " "$current")" input
    [[ -n "$input" ]] && yq -i -y ".relay.am_relay = $input" "$config_file"

    current=$(yq -r ".relay.use_relays" "$config_file")
    read -rp "$(printf "${YELLOW}relay.use_relays${RESET} [${CYAN}%s${RESET}]: " "$current")" input
    [[ -n "$input" ]] && yq -i -y ".relay.use_relays = $input" "$config_file"

    echo -e "${YELLOW}Editing relay.relays list.${RESET}"
    mapfile -t current_relays < <(yq -r '.relay.relays[]?' "$config_file")
    if ((${#current_relays[@]})); then
        echo -e "${CYAN}Current relay.relays:${RESET}"
        for i in "${!current_relays[@]}"; do
            echo -e "  [${i}] ${WHITE}${current_relays[i]}${RESET}"
        done
        read -rp "$(printf "${YELLOW}Enter indices to delete (comma-separated), or press Enter to skip:${RESET} ")" del_input
        if [[ -n "$del_input" ]]; then
            IFS=',' read -ra del_indices <<< "$del_input"
            new_relays=()
            for i in "${!current_relays[@]}"; do
                skip=false
                for d in "${del_indices[@]}"; do
                    [[ "$i" -eq "$d" ]] && skip=true && break
                done
                $skip || new_relays+=("${current_relays[i]}")
            done
            yq -i -y '.relay.relays = []' "$config_file"
            for relay in "${new_relays[@]}"; do
                yq -i -y ".relay.relays += [\"$relay\"]" "$config_file"
            done
        fi
    fi

    read -rp "$(printf "${YELLOW}Add relay IPs (comma-separated), or press Enter to skip:${RESET} ")" input
    if [[ -n "$input" ]]; then
        IFS=',' read -ra RELAYS <<< "$input"
        for relay in "${RELAYS[@]}"; do
            trimmed=$(echo "$relay" | xargs)
            [[ -n "$trimmed" ]] && yq -i -y ".relay.relays += [\"$trimmed\"]" "$config_file"
        done
    fi

    # --- tun section ---
    local current=$(yq -r ".tun.dev" "$config_file")
    read -rp "$(printf "${YELLOW}tun.dev${RESET} [${CYAN}%s${RESET}]: " "$current")" input
    [[ -n "$input" ]] && yq -i -y ".tun.dev = \"$input\"" "$config_file"

    echo -e "$(show_status 'success') ${GREEN}Finished updating ${CYAN}$config_file${RESET}."
    
    # Check config if it is valid from errors
    check_nebula_config "$NEBULA_DIR/config.yml" "error"

}

# Function to display Configuration menu
manage_configuration() {
    dynamic_menu_title=("$MENU_PATH" "Configuration Management")
    dynamic_menu_options=("$(get_icon 'validate')Validate Config" "$(get_icon 'configuration')Edit Config" "$(get_icon 'firewall')Edit Firewall")
    dynamic_menu_functions=("check_nebula_config \"$NEBULA_DIR/config.yml\" \"error\"" "edit_nebula_config" "manage_firewall")
    dynamic_menu dynamic_menu_title dynamic_menu_options dynamic_menu_functions 1
}

# Function to dynamically build option menus
dynamic_menu() {
    local -n title_parts="$1"
    local -n labels="$2"
    local -n actions="$3"
    local depth="${4:-0}"  # Default to 0 if not passed
    local indent=" "
    for ((i = 0; i < depth; i++)); do
        indent+="   "  # 3 spaces per depth level
    done
    while true; do
        show_menu_header "${title_parts[@]}"
        for i in "${!labels[@]}"; do
            printf "${indent}${BOLD}${YELLOW}%d.${RESET} %b\n" "$((i + 1))" "${labels[$i]}"
        done
        local max_choice="${#labels[@]}"
        if (( depth > 0 )); then
            ((max_choice++))
            printf "${indent}${BOLD}${YELLOW}%d.${RESET} $(get_icon 'back')${BOLD}Go Back${RESET}\n" "$max_choice"
        fi
        read -p "${indent}$(show_status 'question') Choose an option [1-$max_choice]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#labels[@]} )); then
            eval "${actions[$((choice - 1))]}"
        elif (( depth > 0 && choice == max_choice )); then
            break
        else
            echo -e "${indent}$(show_status 'error') ${RED}Invalid option. Please choose again.${RESET}"
        fi
    done
}

# Function to display Nebula maintenance menu
nebula_maintenance() {
    dynamic_menu_title=("$MENU_PATH" "Maintenance")
    dynamic_menu_options=("$(get_icon 'start')Toggle Nebula Service" "$(get_icon 'download')Update Nebula" "$(get_icon 'schedule')Auto-Update Scheduler" "$(get_icon 'install')Install Script to System" "$(get_icon 'uninstall')${ORANGE}Remove Nebula${RESET}")
    dynamic_menu_functions=("toggle_nebula_service" "check_for_nebula_update" "auto_update_cron_menu" "ensure_installed_to_bin_path" "remove_nebula")
    dynamic_menu dynamic_menu_title dynamic_menu_options dynamic_menu_functions 1
}

# Function to show system information related to the Nebula service
show_system_info() {
    local service_name=$(basename "$NEBULA_SERVICE")
    local nebula_config="${NEBULA_DIR}/config.yml"
    # Check if Nebula service is running
    if systemctl is-active --quiet "$service_name"; then
        echo -e "$(show_status 'success') ${BOLD}${YELLOW}Service: ${RESET}$(print_service_status "$service_name")"
        # Get service uptime
        echo -e "$(show_status 'success') ${BOLD}${YELLOW}Uptime:${RESET} $(date -ud@$(($(date +%s) - $(date -d"$(systemctl show "$service_name" --property=ActiveEnterTimestamp | cut -d'=' -f2)" +%s))) +%T | awk -F: '{print $1" hrs, "$2" min, "$3" sec"}')"
        # Extract the interface name from config.yml
        local interface=$(grep '^ *dev:' "$nebula_config" | awk '{print $2}')
        local ip_addr=$(ip addr show "$interface" | grep 'inet ' | awk '{print $2}')
        # Extract the listen host and port by searching within the listen block
        local bind_host=$(awk '/listen:/,/port:/{if ($1 == "host:") print $2}' "$nebula_config")
        local bind_port=$(awk '/listen:/,/port:/{if ($1 == "port:") print $2}' "$nebula_config")        
        echo -e "$(show_status 'success') ${BOLD}${YELLOW}Network:${RESET} $ip_addr - $interface ($bind_host:$bind_port)"
        # Check if the service is configured as a Lighthouse
        echo -e -n "$(show_status 'success') ${BOLD}${YELLOW}State:${RESET} "
        if grep -q '^ *am_lighthouse: true' "$nebula_config"; then
            echo -e "Lighthouse"
        else
            echo -e "Client"
        fi
    else
        if check_nebula_installed; then
            echo -e "$(show_status 'error') ${BOLD}${YELLOW}Service: ${RESET}Not Running ($(print_service_status "$service_name"))"
        fi
    fi
}

# Function to convert text to dynamic color
hash_color_256() {
    [[ "${USE_COLOR:-true}" = false ]] && echo "" && return
    local input="$1"
    local index
    local -a colors=(196 202 208 214 220 226 190 154 118 82 46 47 51 39 27 21 57 93 129 165 201 200)
    index=$(echo -n "$input" | cksum | awk '{print $1}')
    echo "${colors[$((index % ${#colors[@]}))]}"
}

# Function to print service status with color
print_service_status() {
    local service_name="$1"
    local status
    status=$(systemctl is-active "$service_name" 2>/dev/null)
    local color
    case "$status" in
        active)        color="${GREEN}" ;;
        activating)    color="${YELLOW}" ;;
        inactive)      color="${GRAY}" ;;
        deactivating)  color="${GRAY}" ;;
        failed)        color="${RED}" ;;
        unknown)       color="${MAGENTA}" ;;
        *)             color="${MAGENTA}" ;;
    esac
    echo -e "${color}${status^}${RESET}"
}

# Function to add Nebula --auto-update-nebula to cron
cron_add() {
    echo -e "$(show_status 'info') ${CYAN}Choose how often to run the Nebula auto-update:${RESET}"
    echo -e "  ${YELLOW}1${RESET}) At boot (${CYAN}@reboot${RESET})"
    echo -e "  ${YELLOW}2${RESET}) Hourly"
    echo -e "  ${YELLOW}3${RESET}) Daily"
    echo -e "  ${YELLOW}4${RESET}) Custom crontab expression"
    read -rp "$(show_status 'question') Enter choice [1-4]: " choice
    local cron_schedule
    case "$choice" in
        1) cron_schedule="@reboot" ;;
        2) cron_schedule="0 * * * *" ;;
        3) cron_schedule="0 0 * * *" ;;
        4)
            read -rp "$(show_status 'question') Enter custom cron expression: " cron_schedule
            ;;
        *)
            echo -e "$(show_status 'error') ${RED}Invalid choice. Aborting.${RESET}"
            return 1
            ;;
    esac
    local cron_line="$cron_schedule $AUTO_UPDATE_CMD"
    local tmp
    tmp=$(mktemp)
    crontab -l 2>/dev/null > "$tmp" || touch "$tmp"
    if grep -Fq "$AUTO_UPDATE_CMD" "$tmp"; then
        echo -e "$(show_status 'warning') ${YELLOW}Cron entry already exists.${RESET}"
        rm -f "$tmp"
        return 0
    fi
    if [[ -s "$tmp" && -n $(tail -n 1 "$tmp") ]]; then
        echo "" >> "$tmp"
    fi
    {
        echo "$CRON_COMMENT"
        echo "$cron_line"
    } >> "$tmp"
    crontab "$tmp"
    rm -f "$tmp"
    echo -e "$(show_status 'success') ${GREEN}Cron entry added with schedule: ${CYAN}$cron_schedule${RESET}"
}

# Function to remove Nebula --auto-update-nebula to cron
cron_remove() {
    local tmp
    tmp=$(mktemp)
    crontab -l 2>/dev/null > "$tmp" || touch "$tmp"
    if grep -qF "$CRON_COMMENT" "$tmp"; then
        sed -i "/$(printf '%q' "$CRON_COMMENT")/,+1d" "$tmp"
        crontab "$tmp"
        echo -e "$(show_status 'success') ${GREEN}Cron entry removed.${RESET}"
    else
        echo -e "$(show_status 'warning') ${YELLOW}No matching cron entry found.${RESET}"
    fi
    rm -f "$tmp"
}

# Function to check cron for Nebula --auto-update-nebua
cron_status() {
    if crontab -l 2>/dev/null | grep -qF "$CRON_COMMENT"; then
        echo -e "$(show_status 'success') ${GREEN}Cron entry for auto-update is present.${RESET}"
    else
        echo -e "$(show_status 'warning') ${YELLOW}Cron entry for auto-update is NOT present.${RESET}"
    fi
}

# Function to display the menu for cron auto-update-nebula
auto_update_cron_menu() {
    show_menu_header "$MENU_PATH" "Maintenance" "Auto-Update Scheduler"
    echo -e "${ORANGE}Automatically checks for new Nebula releases and updates the installed version if needed.${RESET}"
    echo -e "${BOLD}Cron Job:${RESET} ${YELLOW}$SCRIPT_PATH --auto-update-nebula${RESET}"
    local status_msg
    if crontab -l 2>/dev/null | grep -qF "$CRON_COMMENT"; then
        status_msg="${GREEN}✔ Present${RESET}"
        cron_present=true
    else
        status_msg="${RED}✘ Not Present${RESET}"
        cron_present=false
    fi
    echo -e "${BOLD}Cron Status:${RESET} $status_msg"
    local menu_index=1
    if [[ "$cron_present" = false ]]; then
        echo -e "        ${BOLD}${YELLOW}${menu_index}.${RESET} $(get_icon 's_success')Add Auto-Update Cron Job"
        local option_add=$menu_index
        ((menu_index++))
    fi
    if [[ "$cron_present" = true ]]; then
        echo -e "        ${BOLD}${YELLOW}${menu_index}.${RESET} $(get_icon 's_error')Remove Auto-Update Cron Job"
        local option_remove=$menu_index
        ((menu_index++))
    fi
    echo -e "        ${YELLOW}${BOLD}${menu_index}.${RESET} i Show Cron Status"
    local option_status=$menu_index
    ((menu_index++))
    echo -e "        ${YELLOW}${BOLD}${menu_index}.${RESET} $(get_icon 'back')${BOLD}Go Back${RESET}"
    local option_back=$menu_index
    read -rp "$(show_status 'question') Choose an option [1-$menu_index]: " choice
    case "$choice" in
        $option_add) cron_add ;;
        $option_remove) cron_remove ;;
        $option_status) cron_status ;;
        $option_back) return ;;
        *) echo -e "$(show_status 'error') ${RED}Invalid option.${RESET}" ;;
    esac
    auto_update_cron_menu
}


# Function to display the banner
banner(){
    echo -e "${BG_BLACK}${GREEN}  ░█▀█░█▀▀░█▀▄░█░█░█░░░█▀█░░░█▄█░█▀█░█▀█░█▀█░█▀▀░█▀▀░█▀▄  
  ░█░█░█▀▀░█▀▄░█░█░█░░░█▀█░░░█░█░█▀█░█░█░█▀█░█░█░█▀▀░█▀▄  
  ░▀░▀░▀▀▀░▀▀░░▀▀▀░▀▀▀░▀░▀░░░▀░▀░▀░▀░▀░▀░▀░▀░▀▀▀░▀▀▀░▀░▀  
${BG_ORANGE}  ${BOLD}${BLACK}By Jordan Hillis [jordan@hillis.email]    ${BOLD}⎦˚◡˚⎣ ${WHITE}v$VERSION  ${RESET}"
}

# Function to show top header after banner
top_header() {
    echo -e "$(show_status 'success') ${BOLD}${YELLOW}Server:${RESET} \e[38;5;$(hash_color_256 "$SERVER_NAME")m$SERVER_NAME${RESET}"
    if check_nebula_installed; then
        LATEST_VERSION=$(get_latest_version)
        echo -e "$(show_status 'success') ${BOLD}${YELLOW}Nebula:${RESET} v$NEBULA_VERSION$([ "$NEBULA_VERSION" != "$LATEST_VERSION" ] && echo -e "${GREEN} ➜ ${RED}Update Available:${RESET} v$LATEST_VERSION${RESET}" || echo -e " ${GREEN}(Up to date)${RESET}")"
        if [[ "$NEBULA_VERSION" != "$LATEST_VERSION" && "$IGNORE_NEBULA_UPDATE" != "true" ]]; then
            check_for_nebula_update
        fi
        show_system_info
    else
        echo -e "$(show_status 'error') Nebula not installed..."
    fi
}

# Function for server selection
select_nebula_server() {
    # Ensure config file exists or fetch it
    if [[ ! -f "$SERVER_CONF" ]]; then
        echo -e "$(show_status 'warning') ${YELLOW}Config file not found: $SERVER_CONF${RESET}"
        echo -e "$(show_status 'info') ${CYAN}Downloading from: $SERVER_CONF_URL${RESET}"
        mkdir -p "$(dirname "$SERVER_CONF")" || {
            echo -e "$(show_status 'error') ${RED}Failed to create directory: $(dirname "$SERVER_CONF")${RESET}"
            exit 1
        }
        if curl -fsSL "$SERVER_CONF_URL" -o "$SERVER_CONF"; then
            echo -e "$(show_status 'success') ${GREEN}Downloaded example config to: $SERVER_CONF${RESET}"
        else
            echo -e "$(show_status 'error') ${RED}Failed to download config from $SERVER_CONF_URL${RESET}"
            exit 1
        fi
        echo -e "$(show_status 'info') Please edit the config file before continuing."
        exit 1
    fi

    # Find available servers
    mapfile -t servers < <(
    awk '
        { sub(/\r$/, "") }                         # strip CR
        /^[[:space:]]*#/ { next }                  # skip full-line comments
        { sub(/[[:space:]]*#.*$/, "") }            # strip inline comments
        /^[[:space:]]*$/ { next }                  # skip empty

        # [server.NAME]
        /^\[server\.[^]]+\][[:space:]]*$/ {
            line = $0
            sub(/^\[server\./, "", line)           # remove "[server."
            sub(/\][[:space:]]*$/, "", line)       # remove trailing "]"
            server = line
            dir = ""
            next
        }
        /^[[:space:]]*dir[[:space:]]*=/ {
            dir_line = $0
            sub(/^[[:space:]]*dir[[:space:]]*=/, "", dir_line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", dir_line)
            dir = dir_line
            next
        }
        /^[[:space:]]*enabled[[:space:]]*=[[:space:]]*true[[:space:]]*$/ {
            print server "\t" dir
        }
    ' "$SERVER_CONF"
    )

    if (( ${#servers[@]} == 0 )); then
        echo -e "$(show_status 'error') ${RED}No enabled servers found in config (${ORANGE}$SERVER_CONF${RED})${RESET}"
        exit 1
    fi

    for s in "${servers[@]}"; do
        [[ "$s" == nebula-example* ]] && {
            echo -e "$(show_status 'error') ${RED}Placeholder server [$s] found. Please edit ${CYAN}$SERVER_CONF${RESET}"
            exit 1
        }
    done

    if (( ${#servers[@]} == 1 )); then
        IFS=$'\t' read -r server_name server_dir <<< "${servers[0]}"
        SELECTED_SERVER="$server_name"
    else
        echo -e "${BOLD}${CYAN}Available Nebula Servers:${RESET}"
        name_width=$(( $(printf "%s\n" "${servers[@]}" | awk -F'\t' '{print length($1)}' | sort -nr | head -n1) + 6 ))
        for i in "${!servers[@]}"; do
            IFS=$'\t' read -r name dir <<< "${servers[i]}"
            cfg="$dir/config.yml"
            iface=""
            ip_net="[${GRAY}N/A${RESET}]"
            [[ -r "$cfg" ]] && iface=$(awk -F: '/^[[:space:]]*dev[[:space:]]*:/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}' "$cfg" 2>/dev/null)
            # Decide Active/Inactive using a single ip query each (quiet on errors)
            if [[ -n "$iface" ]]; then
                link_out="$(ip -o link show "$iface" 2>/dev/null)"
                addr_out="$(ip -o -4 addr show dev "$iface" 2>/dev/null)"
                if [[ -n "$link_out" && ( "$link_out" == *UP* || -n "$addr_out" ) ]]; then
                    local ip_addr=$(ip addr show "$iface" | grep 'inet ' | awk '{print $2}')
                    status="[${GREEN}Active${RESET}]"
                    ip_net="[${YELLOW}$ip_addr${RESET}]      "
                else
                    status="[${GRAY}Inactive${RESET}]"
                fi
            else
                status="[${GRAY}Inactive${RESET}]"
            fi
            color_code=$(hash_color_256 "$name")
            # Pad the name to name_width, keeping statuses aligned
            printf " ${BOLD}${YELLOW}%d.${RESET} \e[38;5;%sm%-*s\e[0m %-*b %b\n" \
                "$((i+1))" "$color_code" "$name_width" "$name" \
                20 "$status" "$ip_net"
        done
        while true; do
            read -p "$(show_status 'question') Choose a server [1-${#servers[@]}]: " choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#servers[@]} )); then
                IFS=$'\t' read -r server_name server_dir <<< "${servers[$((choice-1))]}"
                SELECTED_SERVER="$server_name"
                break
            else
                echo -e "$(show_status 'error') Invalid selection."
            fi
        done
    fi

    SERVER_NAME="$SELECTED_SERVER"
    load_server_config "$SERVER_NAME"
    clear
}

# Function to load global variables from conf file
load_global_config() {
    if [[ ! -f "$SERVER_CONF" ]]; then
        return
    fi
    eval "$(
        awk -F= '
            { sub(/\r$/, "") }                 # strip CR
            /^[ \t]*#/ { next }                # skip full-line comments
            { sub(/[ \t]*#.*$/, "") }          # strip inline comments
            /^[ \t]*$/ { next }                # skip empty lines
            /^\[global\]/ {
                in_global = 1
                next
            }
            /^\[.*\]/ {
                in_global = 0
                next
            }
            in_global && NF == 2 {
                gsub(/^[ \t]+|[ \t]+$/, "", $1)
                gsub(/^[ \t]+|[ \t]+$/, "", $2)
                key = "GLOBAL_" toupper($1)
                gsub("-", "_", key)
                printf "export %s=\"%s\"\n", key, $2
            }
        ' "$SERVER_CONF"
    )"
    # Apply fallback values
    : "${NEBULA_CERT_FOLDER:=${GLOBAL_CERT_FOLDER:-certs}}"
    : "${NEBULA_BIN_PATH:=${GLOBAL_BIN_PATH:-/usr/local/bin}}"
    : "${USE_COLOR:=${GLOBAL_USE_COLOR:-true}}"
    : "${USE_ICONS:=${GLOBAL_USE_ICONS:-true}}"
    : "${DISABLE_VERSION_CHECK:=${GLOBAL_DISABLE_VERSION_CHECK:-false}}"
    : "${IGNORE_DEPENDENCY_CHECK:=${GLOBAL_IGNORE_DEPENDENCY_CHECK:-false}}"
    : "${IGNORE_NEBULA_UPDATE:=${GLOBAL_IGNORE_NEBULA_UPDATE:-false}}"
    # If color is disabled, unset all
    if [[ "$USE_COLOR" == "false" ]]; then
        for var in RESET BOLD BLACK GRAY RED GREEN YELLOW BLUE MAGENTA CYAN WHITE ORANGE \
                   BG_BLACK BG_RED BG_GREEN BG_YELLOW BG_BLUE BG_MAGENTA BG_CYAN BG_WHITE BG_ORANGE; do
            declare -g "$var="
        done
    fi
}

# Function to load server variables from conf file
load_server_config() {
    local server="$1"
    eval "$(
        awk -F= -v s="server.$server" '
            { sub(/\r$/, "") }                 # strip CR
            /^[ \t]*#/ { next }                # skip full-line comments
            { sub(/[ \t]*#.*$/, "") }          # strip inline comments
            /^[ \t]*$/ { next }                # skip empty lines
            /^\[server\.[^]]+\]/ {
                in_server = 0
                section = substr($0, 2, length($0) - 2)
                if (section == s) in_server = 1
                next
            }
            in_server && NF == 2 {
                gsub(/^[ \t]+|[ \t]+$/, "", $1)
                gsub(/^[ \t]+|[ \t]+$/, "", $2)
                key = "NEBULA_" toupper($1)
                gsub("-", "_", key)
                printf "export %s=\"%s\"\n", key, $2
            }
        ' "$SERVER_CONF"
    )"
}

check_script_update() {
  if [[ "$DISABLE_VERSION_CHECK" == true ]]; then
    return
  fi

  local now last_check_age latest_version
  now=$(date +%s)

  if [[ -f "$VERSION_CACHE_FILE" ]]; then
    local last_check
    last_check=$(stat -c %Y "$VERSION_CACHE_FILE")
    last_check_age=$(( now - last_check ))
    if (( last_check_age < VERSION_CACHE_TTL_SECONDS )); then
      latest_version=$(cat "$VERSION_CACHE_FILE")
    #   echo -e "$(show_status 'info') ${CYAN}Using cached version: $latest_version (checked $((last_check_age / 60)) min ago)${RESET}"
    fi
  fi

  if [[ -z "$latest_version" ]]; then
    latest_version=$(curl -fsSL "$VERSION_URL") || {
      echo -e "$(show_status 'error') ${RED}Could not fetch latest version info.${RESET}"
      return
    }
    echo "$latest_version" > "$VERSION_CACHE_FILE"
  fi

  if [[ "$latest_version" != "$VERSION" ]]; then
    echo -e "$(show_status 'warning') $(get_icon 'package')${YELLOW}Update available for ${BOLD}${ORANGE}Nebula Manager${RESET}${YELLOW}: v$latest_version (you have ${RED}v$VERSION${YELLOW})${RESET}"
    echo -e "$(show_status 'info') $(get_icon 'link')${BLUE}Release notes: $RELEASE_PAGE/releases${RESET}"
    read -rp "$(show_status 'question') Do you want to update to the latest version? [y/N]: " answer
    case "$answer" in
      [Yy]*)
        tmp_script="/tmp/nebula-manager-update.sh"
        tmp_checksum="${tmp_script}.sha256"

        curl -fsSL "$SCRIPT_URL" -o "$tmp_script" || {
          echo -e "$(show_status 'error') ${RED}Download failed.${RESET}"
          return
        }

        curl -fsSL "${SCRIPT_URL}.sha256" -o "$tmp_checksum" || {
          echo -e "$(show_status 'error') ${RED}Failed to fetch checksum.${RESET}"
          return
        }

        expected=$(awk '{print $1}' "$tmp_checksum")
        actual=$(sha256sum "$tmp_script" | awk '{print $1}')
        if [[ "$expected" == "$actual" ]]; then
          mv "$tmp_script" "$0" && chmod +x "$0"
          echo -e "$(show_status 'success') ${GREEN}Updated to version v$latest_version. Please rerun the script.${RESET}"
          rm -f "$tmp_checksum"
          exit 0
        else
          rm -f "$tmp_script" "$tmp_checksum"
          echo -e "$(show_status 'error') ${RED}Checksum mismatch. Update aborted.${RESET}"
          echo -e "$(show_status 'info') ${CYAN}Expected: $expected${RESET}"
          echo -e "$(show_status 'info') ${CYAN}Actual:   $actual${RESET}"
        fi
        ;;
      *)
        echo -e "$(show_status 'info') ${CYAN}Continuing with current version v$VERSION${RESET}"
        ;;
    esac
  fi
}

# Dynamically build menu based on Nebula installation status
main_menu() {
    if check_nebula_installed; then
        # Make sure Nebula service is installed
        if ! check_nebula_service; then
            setup_nebula_service
        fi
        # Make sure config.yml exists
        if [ ! -f "${NEBULA_DIR}/config.yml" ]; then
            setup_nebula_config
        fi
        menu_options=("$(get_icon 'certificate')Certificates" "$(get_icon 'configuration')Configuration" "$(get_icon 'connectivity')Connectivity" "$(get_icon 'maintenance')Maintenance" "$(get_icon 'exit')${BOLD}Exit${RESET}")
        menu_option_functions=("manage_nebula_certs" "manage_configuration" "check_node_connectivity" "nebula_maintenance" "exit")
    else
        menu_options=("$(get_icon 'install')Install Nebula" "$(get_icon 'exit')${BOLD}Exit${RESET}")
        menu_option_functions=("install_nebula" "exit")
    fi
    menu_title=("$MENU_PATH")
    dynamic_menu menu_title menu_options menu_option_functions 0
}

# Params for --config and --auto-update-nebula
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            echo "Nebula Manager v${VERSION}"
            exit 0
            ;;    
        --config=*)
            SERVER_CONF="${1#*=}"
            shift
            ;;
        --auto-update-nebula)
            AUTO_UPDATE_REQUESTED=1
            shift
            ;;            
    esac
done

# Make sure the script is ran as root
[[ $EUID -ne 0 ]] && echo -e "$(show_status 'error') ${RED}Please run this script as root.${RESET}"

# Auto update Nebula
if (( AUTO_UPDATE_REQUESTED )); then
    load_global_config
    AUTO_UPDATE=true
    banner
    if [ -z "$NEBULA_BIN_PATH" ]; then
        echo -e "$(show_status 'error') ${RED}Failed to Nebula Manager config: ${ORANGE}$SERVER_CONF.${RESET}"
        exit 1
    fi    
    check_nebula_installed
    auto_update_nebula
    exit 0
fi

# Clear failed config tests or service restart failures logged from previous session
rm -f /tmp/nebula_failed_*

# Clear the screen
clear
# Load globals first
load_global_config
# Check for dependencie issues
check_dependencies
# Show the banner
banner
# Check for an update to Nebula Manager
check_script_update
# Ask to select Nebula server or auto load if only 1 configured
select_nebula_server
# Show banner again
banner
# Show top header
top_header
# Show main menu
main_menu
