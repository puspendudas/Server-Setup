#!/bin/bash

# Set strict error handling
set -euo pipefail

# Configuration
LOG_FILE="/var/log/server-setup.log"
DOCKER_COMPOSE_VERSION="v2.3.3"
SSH_KEY_TYPE="ed25519"
SSH_KEY_PATH="$HOME/.ssh/id_ED25519"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Emojis for different log levels
EMOJI_INFO="📝"
EMOJI_SUCCESS="✅"
EMOJI_ERROR="❌"
EMOJI_WARNING="⚠️"
EMOJI_START="🚀"
EMOJI_DOCKER="🐳"
EMOJI_CADDY="🌐"
EMOJI_SSH="🔑"
EMOJI_SYSTEM="⚙️"
EMOJI_DONE="✨"

# Logging function
log() {
    local level=$1
    shift
    local message=$*
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Select emoji based on level
    case $level in
        "INFO") emoji=$EMOJI_INFO ;;
        "SUCCESS") emoji=$EMOJI_SUCCESS ;;
        "ERROR") emoji=$EMOJI_ERROR ;;
        "WARNING") emoji=$EMOJI_WARNING ;;
        *) emoji="" ;;
    esac
    
    # Select color based on level
    case $level in
        "SUCCESS") color=$GREEN ;;
        "ERROR") color=$RED ;;
        "WARNING") color=$YELLOW ;;
        *) color=$NC ;;
    esac
    
    echo -e "${color}${timestamp} [${emoji} ${level}] ${message}${NC}" | tee -a "$LOG_FILE"
}

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    log "ERROR" "Error occurred in line ${line_number} with exit code ${exit_code}"
    exit $exit_code
}

# Trap errors
trap 'handle_error ${LINENO}' ERR

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log "ERROR" "Please run as root"
    exit 1
fi

# Check if running on Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    log "ERROR" "This script is designed for Ubuntu only"
    exit 1
fi

# Function to check if a command was successful
check_status() {
    if [ $? -eq 0 ]; then
        log "SUCCESS" "$1"
    else
        log "ERROR" "$1 failed"
        exit 1
    fi
}

# Function to prompt for email
get_email() {
    read -p "${EMOJI_SSH} Enter your email for SSH key generation: " email
    if [ -z "$email" ]; then
        log "ERROR" "Email cannot be empty"
        get_email
    fi
}

# Main installation function
install_docker() {
    log "INFO" "${EMOJI_DOCKER} Installing Docker..."
    
    # Update package list
    log "INFO" "${EMOJI_SYSTEM} Updating package list..."
    apt-get update
    check_status "Package list update"

    # Install prerequisites
    log "INFO" "${EMOJI_SYSTEM} Installing Docker prerequisites..."
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    check_status "Docker prerequisites installation"

    # Add Docker GPG key
    log "INFO" "${EMOJI_SSH} Adding Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    check_status "Docker GPG key addition"

    # Add Docker repository
    log "INFO" "${EMOJI_SYSTEM} Adding Docker repository..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    check_status "Docker repository addition"

    # Update package list again
    apt-get update
    check_status "Package list update"

    # Install Docker
    apt-get install -y docker-ce
    check_status "Docker installation"

    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker
    check_status "Docker service configuration"
}

# Install Docker Compose
install_docker_compose() {
    log "INFO" "${EMOJI_DOCKER} Installing Docker Compose..."
    
    mkdir -p /usr/local/lib/docker/cli-plugins/
    curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
    check_status "Docker Compose download"
    
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    check_status "Docker Compose permissions"
}

# Install Caddy
install_caddy() {
    log "INFO" "${EMOJI_CADDY} Installing Caddy..."
    
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
    check_status "Caddy prerequisites"
    
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    check_status "Caddy GPG key"
    
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    check_status "Caddy repository"
    
    apt-get update
    apt-get install -y caddy
    check_status "Caddy installation"
    
    # Start and enable Caddy service
    systemctl start caddy
    systemctl enable caddy
    check_status "Caddy service configuration"
}

# Generate SSH key
generate_ssh_key() {
    log "INFO" "${EMOJI_SSH} Generating SSH key..."
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    get_email
    ssh-keygen -t "$SSH_KEY_TYPE" -C "$email" -f "$SSH_KEY_PATH" -N ""
    check_status "SSH key generation"
    
    # Set correct permissions
    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "$SSH_KEY_PATH.pub"
    
    log "INFO" "${EMOJI_SSH} Your SSH public key:"
    cat "$SSH_KEY_PATH.pub"
}

# Main execution
main() {
    log "INFO" "${EMOJI_START} Starting server setup..."
    
    # Create log file
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # Install components
    install_docker
    install_docker_compose
    install_caddy
    generate_ssh_key
    
    log "SUCCESS" "${EMOJI_DONE} Server setup completed successfully!"
    log "INFO" "${EMOJI_SYSTEM} Log file available at: $LOG_FILE"
}

# Execute main function
main
