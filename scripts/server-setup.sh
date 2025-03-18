#!/usr/bin/env bash

# Set strict error handling
set -euo pipefail

# Configuration
LOG_FILE="/var/log/server-setup.log"
DOCKER_COMPOSE_VERSION="v2.3.3"
SSH_KEY_TYPE="ed25519"
SSH_KEY_PATH="$HOME/.ssh/id_ED25519"

# Get script directory and name with fallback
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    SCRIPT_NAME="$(basename "$0")"
fi

# Check if running through a pipe
if [ -t 1 ]; then
    # Terminal output - use colors and formatting
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
else
    # Piped output - no colors or emojis
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
    EMOJI_INFO="[INFO]"
    EMOJI_SUCCESS="[SUCCESS]"
    EMOJI_ERROR="[ERROR]"
    EMOJI_WARNING="[WARNING]"
    EMOJI_START="[START]"
    EMOJI_DOCKER="[DOCKER]"
    EMOJI_CADDY="[CADDY]"
    EMOJI_SSH="[SSH]"
    EMOJI_SYSTEM="[SYSTEM]"
    EMOJI_DONE="[DONE]"
fi

# Trap signals
trap 'cleanup' EXIT
trap 'handle_error ${LINENO}' ERR

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
    
    # Print to console and log file
    printf "%s [%s %s] %s\n" "$timestamp" "$emoji" "$level" "$message" | tee -a "$LOG_FILE"
}

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    log "ERROR" "Error occurred in line ${line_number} with exit code ${exit_code}"
    cleanup
    exit $exit_code
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        log "INFO" "Cleaning up setup script..."
        rm -f "$0"
        log "SUCCESS" "Setup script removed successfully!"
    fi
}

# Check dependencies
check_dependencies() {
    log "INFO" "Checking system dependencies..."
    
    # Check for required commands
    local required_commands=("curl" "gpg" "apt-get" "systemctl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "Required command '$cmd' is not installed"
            exit 1
        fi
    done
    
    log "SUCCESS" "All required dependencies are installed"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log "ERROR" "Please run as root"
        exit 1
    fi
}

# Check if running on Ubuntu
check_ubuntu() {
    log "INFO" "Checking system requirements..."
    
    # Check if running on a Debian-based system
    if [ ! -f /etc/debian_version ]; then
        log "ERROR" "This script is designed for Debian-based systems only"
        exit 1
    fi
    
    # Check if running on Ubuntu
    if ! grep -q "ID=ubuntu" /etc/os-release; then
        log "ERROR" "This script is designed for Ubuntu only"
        exit 1
    fi
    
    # Get Ubuntu version
    UBUNTU_VERSION=$(grep "VERSION_ID" /etc/os-release | cut -d'"' -f2)
    UBUNTU_CODENAME=$(grep "UBUNTU_CODENAME" /etc/os-release | cut -d'=' -f2)
    
    log "INFO" "Detected Ubuntu version: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
    
    # Check if running on a supported architecture
    ARCH=$(dpkg --print-architecture)
    case $ARCH in
        amd64|arm64)
            log "INFO" "Detected supported architecture: $ARCH"
            ;;
        *)
            log "ERROR" "Unsupported architecture: $ARCH. This script supports amd64 and arm64 only."
            exit 1
            ;;
    esac
    
    # Check system requirements
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 2048 ]; then
        log "WARNING" "System has less than 2GB RAM. Some operations might be slow or fail."
    fi
    
    local free_space=$(df -m / | awk 'NR==2 {print $4}')
    if [ "$free_space" -lt 10240 ]; then
        log "WARNING" "Less than 10GB free space available. Some operations might fail."
    fi
    
    log "SUCCESS" "System requirements check passed"
}

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
    printf "Enter your email for SSH key generation: "
    read -r email
    if [ -z "$email" ]; then
        log "ERROR" "Email cannot be empty"
        get_email
    fi
}

# Show help/usage
show_help() {
    printf "Usage: %s [OPTIONS]\n\n" "$SCRIPT_NAME"
    printf "Options:\n"
    printf "  -h, --help     Show this help message\n"
    printf "  -v, --version  Show version information\n\n"
    printf "This script sets up a server with Docker, Docker Compose, Caddy, and SSH key generation.\n"
    exit 0
}

# Show version
show_version() {
    printf "Server Setup Script v1.0.0\n"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -v|--version)
            show_version
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            show_help
            ;;
    esac
    shift
done

# Main installation function
install_docker() {
    log "INFO" "Installing Docker..."
    
    # Update package list
    log "INFO" "Updating package list..."
    apt-get update
    check_status "Package list update"

    # Install prerequisites
    log "INFO" "Installing Docker prerequisites..."
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    check_status "Docker prerequisites installation"

    # Add Docker GPG key
    log "INFO" "Adding Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    check_status "Docker GPG key addition"

    # Add Docker repository
    log "INFO" "Adding Docker repository..."
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
    log "INFO" "Installing Docker Compose..."
    
    mkdir -p /usr/local/lib/docker/cli-plugins/
    curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
    check_status "Docker Compose download"
    
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    check_status "Docker Compose permissions"
}

# Install Caddy
install_caddy() {
    log "INFO" "Installing Caddy..."
    
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
    log "INFO" "Generating SSH key..."
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    get_email
    ssh-keygen -t "$SSH_KEY_TYPE" -C "$email" -f "$SSH_KEY_PATH" -N ""
    check_status "SSH key generation"
    
    # Set correct permissions
    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "$SSH_KEY_PATH.pub"
    
    log "INFO" "Your SSH public key:"
    cat "$SSH_KEY_PATH.pub"
}

# Main execution
main() {
    log "INFO" "Starting server setup..."
    
    # Create log file
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # Run checks
    check_root
    check_ubuntu
    check_dependencies
    
    # Install components
    install_docker
    install_docker_compose
    install_caddy
    generate_ssh_key
    
    log "SUCCESS" "Server setup completed successfully!"
    log "INFO" "Log file available at: $LOG_FILE"
}

# Execute main function
main 