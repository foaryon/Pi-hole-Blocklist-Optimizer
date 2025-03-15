#!/bin/bash
# pihole_download.sh
# Pi-hole Blocklist Downloader and Optimizer Runner
# This script ensures all dependencies are installed and runs the downloader

# Version
VERSION="1.2.0"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check if colors are supported
if [ -t 1 ]; then
    # Terminal supports colors
    ncolors=$(tput colors)
    if [ -n "$ncolors" ] && [ $ncolors -ge 8 ]; then
        USE_COLORS=true
    else
        USE_COLORS=false
    fi
else
    # Not a terminal, no colors
    USE_COLORS=false
    GREEN=""
    YELLOW=""
    RED=""
    BLUE=""
    CYAN=""
    BOLD=""
    NC=""
fi

# Default options
VERBOSE=false
QUIET=false

# Print banner
print_banner() {
    if $QUIET; then
        return
    fi
    
    echo
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}              🛡️  PI-HOLE BLOCKLIST DOWNLOADER v${VERSION}  🛡️${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# Print functions for different message types
log_info() {
    if ! $QUIET; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if ! $QUIET; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

log_warn() {
    if ! $QUIET; then
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if $VERBOSE && ! $QUIET; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        key="$1"
        
        case $key in
            -v|--verbose)
                VERBOSE=true
                SCRIPT_ARGS="${SCRIPT_ARGS} --verbose"
                shift
                ;;
            -q|--quiet)
                QUIET=true
                SCRIPT_ARGS="${SCRIPT_ARGS} --quiet"
                shift
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            --version)
                echo "Pi-hole Blocklist Downloader v${VERSION}"
                exit 0
                ;;
            *)
                # Pass other arguments to the Python script
                SCRIPT_ARGS="${SCRIPT_ARGS} $1"
                shift
                ;;
        esac
    done
}

# Print help message
print_help() {
    echo "Usage: $(basename "$0") [options]"
    echo
    echo "Options:"
    echo "  -v, --verbose     Enable verbose output"
    echo "  -q, --quiet       Suppress all output except errors"
    echo "  -h, --help        Display this help message and exit"
    echo "  --version         Display version information and exit"
    echo
    echo "All other options are passed to the Python script."
    echo "For detailed Python script options, run: $(basename "$0") --help"
}

# Function to check if we can use sudo
can_use_sudo() {
    if command -v sudo &> /dev/null; then
        # Check if user can use sudo without password
        if sudo -n true 2>/dev/null; then
            return 0
        # Check if user can use sudo with password
        elif sudo -v 2>/dev/null; then
            log_warn "Sudo access required for installing dependencies"
            return 0
        fi
    fi
    return 1
}

# Get system information
detect_system() {
    log_debug "Detecting system information..."
    
    # Detect OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_ID=$ID
        OS_VERSION=$VERSION_ID
        OS_FAMILY=$ID_LIKE
    elif type lsb_release >/dev/null 2>&1; then
        OS_NAME=$(lsb_release -sd)
        OS_ID=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        OS_VERSION=$(lsb_release -sr)
        OS_FAMILY="unknown"
    else
        OS_NAME=$(uname -s)
        OS_ID=$(uname -s | tr '[:upper:]' '[:lower:]')
        OS_VERSION=$(uname -r)
        OS_FAMILY="unknown"
    fi
    
    # Get Python version
    if command -v python3 &>/dev/null; then
        PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
        PYTHON_PATH=$(which python3)
    elif command -v python &>/dev/null; then
        # Check if python is Python 3
        if python --version 2>&1 | grep -q "Python 3"; then
            PYTHON_VERSION=$(python --version 2>&1 | cut -d' ' -f2)
            PYTHON_PATH=$(which python)
        else
            PYTHON_VERSION="Not found"
            PYTHON_PATH="Not found"
        fi
    else
        PYTHON_VERSION="Not found"
        PYTHON_PATH="Not found"
    fi
    
    # Get system architecture
    ARCH=$(uname -m)
    
    # Check for package managers
    if command -v apt-get &>/dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
    elif command -v yum &>/dev/null; then
        PKG_MANAGER="yum"
    elif command -v pacman &>/dev/null; then
        PKG_MANAGER="pacman"
    elif command -v zypper &>/dev/null; then
        PKG_MANAGER="zypper"
    elif command -v apk &>/dev/null; then
        PKG_MANAGER="apk"
    else
        PKG_MANAGER="unknown"
    fi
    
    # Detect memory
    if [ -f /proc/meminfo ]; then
        MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        MEM_TOTAL_MB=$((MEM_TOTAL / 1024))
    else
        MEM_TOTAL_MB="unknown"
    fi
    
    log_debug "OS: $OS_NAME ($OS_ID $OS_VERSION)"
    log_debug "OS family: $OS_FAMILY"
    log_debug "Python: $PYTHON_VERSION at $PYTHON_PATH"
    log_debug "Architecture: $ARCH"
    log_debug "Package manager: $PKG_MANAGER"
    log_debug "Memory: $MEM_TOTAL_MB MB"
}

# Function to install system dependencies
install_system_deps() {
    log_info "Checking system dependencies..."
    
    # Process based on detected package manager and OS
    case $PKG_MANAGER in
        apt)
            if can_use_sudo; then
                log_info "Installing required system packages..."
                sudo apt-get update -qq
                sudo apt-get install -y python3-pip python3-venv python3-dev build-essential
                
                # Check if python3-venv is properly installed
                if ! dpkg -l | grep -q python3-venv; then
                    log_warn "Installing python3-venv package..."
                    sudo apt-get install -y python3-venv
                    
                    # Try specific version if generic package fails
                    if [ $? -ne 0 ]; then
                        PYTHON_MAJOR_MINOR=$(echo $PYTHON_VERSION | cut -d. -f1,2)
                        log_warn "Trying to install specific python3-venv version..."
                        sudo apt-get install -y python${PYTHON_MAJOR_MINOR}-venv
                    fi
                fi
            else
                log_warn "Please run the following command to install required packages:"
                echo "sudo apt-get update && sudo apt-get install -y python3-pip python3-venv python3-dev build-essential"
                read -p "Press Enter to continue after installing dependencies, or Ctrl+C to exit..."
            fi
            ;;
        dnf|yum)
            if can_use_sudo; then
                log_info "Installing required system packages..."
                sudo $PKG_MANAGER install -y python3-pip python3-devel gcc
            else
                log_warn "Please run the following command to install required packages:"
                echo "sudo $PKG_MANAGER install -y python3-pip python3-devel gcc"
                read -p "Press Enter to continue after installing dependencies, or Ctrl+C to exit..."
            fi
            ;;
        pacman)
            if can_use_sudo; then
                log_info "Installing required system packages..."
                sudo pacman -Sy --noconfirm python python-pip
            else
                log_warn "Please run the following command to install required packages:"
                echo "sudo pacman -Sy --noconfirm python python-pip"
                read -p "Press Enter to continue after installing dependencies, or Ctrl+C to exit..."
            fi
            ;;
        zypper)
            if can_use_sudo; then
                log_info "Installing required system packages..."
                sudo zypper install -y python3-pip python3-devel gcc
            else
                log_warn "Please run the following command to install required packages:"
                echo "sudo zypper install -y python3-pip python3-devel gcc"
                read -p "Press Enter to continue after installing dependencies, or Ctrl+C to exit..."
            fi
            ;;
        apk)
            if can_use_sudo; then
                log_info "Installing required system packages..."
                sudo apk add python3 py3-pip python3-dev gcc musl-dev
            else
                log_warn "Please run the following command to install required packages:"
                echo "sudo apk add python3 py3-pip python3-dev gcc musl-dev"
                read -p "Press Enter to continue after installing dependencies, or Ctrl+C to exit..."
            fi
            ;;
        *)
            log_warn "Unsupported package manager. Please ensure Python 3, pip, and venv are installed."
            log_info "Required packages: python3, python3-pip, python3-venv or virtualenv, and build tools"
            read -p "Press Enter to continue or Ctrl+C to exit..."
            ;;
    esac
}

# Function to check if virtual environment is valid
check_venv() {
    # Check if the virtualenv has the basic expected structure
    if [ -d "venv" ]; then
        if [ -d "venv/bin" ] && [ -f "venv/bin/python" ] && [ -f "venv/bin/pip" ]; then
            return 0
        elif [ -d "venv/Scripts" ] && [ -f "venv/Scripts/python.exe" ] && [ -f "venv/Scripts/pip.exe" ]; then
            # Windows-style paths when running in WSL or similar
            return 0
        else
            log_warn "Virtual environment exists but appears to be incomplete"
            return 1
        fi
    fi
    return 1
}

# Create virtual environment, handling errors
create_venv() {
    # If venv exists but is corrupt, remove it
    if [ -d "venv" ] && ! check_venv; then
        log_warn "Detected corrupted virtual environment, removing it..."
        rm -rf venv
    fi

    # Create a fresh venv if needed
    if [ ! -d "venv" ]; then
        log_info "Creating Python virtual environment..."
        python3 -m venv venv
        
        # If venv creation failed, try to install dependencies
        if [ $? -ne 0 ]; then
            log_warn "Virtual environment creation failed, installing dependencies..."
            install_system_deps
            
            # Try again
            log_info "Trying to create virtual environment again..."
            python3 -m venv venv
            
            if [ $? -ne 0 ]; then
                # If it still fails, try using virtualenv instead
                log_warn "Trying alternative method with virtualenv..."
                if ! command -v pip3 &> /dev/null; then
                    if can_use_sudo; then
                        sudo apt-get install -y python3-pip || sudo dnf install -y python3-pip || sudo pacman -Sy --noconfirm python-pip || sudo zypper install -y python3-pip || sudo apk add py3-pip
                    else
                        log_error "Please install pip3 manually and try again."
                        exit 1
                    fi
                fi
                
                pip3 install --user virtualenv
                python3 -m virtualenv venv
                
                if [ $? -ne 0 ]; then
                    log_error "Failed to create virtual environment. Please check your Python installation."
                    log_warn "The script will continue without a virtual environment."
                    # Create a flag file to indicate we're not using venv
                    touch .no_venv
                fi
            fi
        fi
    fi
}

# Install dependencies in the virtual environment
install_deps() {
    log_info "Installing required packages..."
    
    if [ -f ".no_venv" ]; then
        # Install globally or with --user if no venv
        pip3 install --user requests tqdm || python3 -m pip install --user requests tqdm
        if [ $? -ne 0 ]; then
            log_error "Failed to install dependencies. Please install them manually:"
            echo "pip3 install --user requests tqdm"
            log_warn "Continuing with limited functionality..."
        fi
    else
        # Check for pip in virtual environment
        if [ -f "venv/bin/pip" ]; then
            venv/bin/pip install requests tqdm
        elif [ -f "venv/Scripts/pip" ]; then
            venv/Scripts/pip install requests tqdm
        else
            log_error "Failed to find pip in the virtual environment."
            log_warn "Trying to install globally or with --user..."
            pip3 install --user requests tqdm || python3 -m pip install --user requests tqdm
            if [ $? -ne 0 ]; then
                log_error "Failed to install dependencies. Please install them manually:"
                echo "pip3 install --user requests tqdm"
                log_warn "Continuing with limited functionality..."
            else
                # Mark as not using venv for dependencies
                touch .no_venv
            fi
        fi
    fi
}

# Create configuration file if it doesn't exist
create_config() {
    if [ ! -f "blocklists.conf" ]; then
        log_info "Configuration file not found, creating from the example file..."
        if [ -f "blocklists.conf.example" ]; then
            cp blocklists.conf.example blocklists.conf
            log_success "Created configuration file from example template."
        elif [ -f "pihole-blocklist-config.txt" ]; then
            cp pihole-blocklist-config.txt blocklists.conf
            log_success "Created configuration file from template."
        else
            log_warn "No configuration template found, creating a basic one..."
            cat > blocklists.conf << EOF
# Pi-hole Blocklist Configuration
# Format: url|name|category
# Categories: advertising, tracking, malicious, suspicious, nsfw, comprehensive
# Lines starting with # are comments and will be ignored

# Sample comprehensive blocklists
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts|stevenblack_unified|comprehensive
https://big.oisd.nl|oisd_big|comprehensive

# Sample advertising blocklists
https://adaway.org/hosts.txt|adaway|advertising
https://v.firebog.net/hosts/AdguardDNS.txt|adguard_dns|advertising
EOF
            log_success "Created basic configuration file with sample entries."
            log_info "Edit blocklists.conf to add more blocklists if needed."
        fi
    fi
}

# Run the Python script
run_script() {
    log_info "Running Pi-hole Blocklist Downloader..."
    
    # Clear previous error flag
    rm -f .run_error
    
    if [ -f ".no_venv" ]; then
        if ! $QUIET; then
            log_warn "Running without virtual environment..."
        fi
        python3 pihole_downloader.py $SCRIPT_ARGS
    else
        if [ -f "venv/bin/python" ]; then
            venv/bin/python pihole_downloader.py $SCRIPT_ARGS
        elif [ -f "venv/Scripts/python" ]; then
            venv/Scripts/python pihole_downloader.py $SCRIPT_ARGS
        else
            log_error "Python not found in virtual environment. Trying system Python..."
            python3 pihole_downloader.py $SCRIPT_ARGS
        fi
    fi
    
    # Check if the script executed successfully
    if [ $? -eq 0 ]; then
        if ! $QUIET; then
            log_success "Pi-hole Blocklist Downloader completed successfully!"
            log_info "The optimized blocklists are ready for use with Pi-hole."
            
            # Show the production directory
            if [ -d "pihole_blocklists_prod" ]; then
                count=$(find pihole_blocklists_prod -name "*.txt" | wc -l)
                log_info "📋 ${count} production blocklists are available in:"
                echo -e "  📁 ${BOLD}$(pwd)/pihole_blocklists_prod/${NC}"
                
                # Show the production list index if it exists
                if [ -f "pihole_blocklists_prod/_production_lists.txt" ]; then
                    echo
                    log_info "📊 Production list details:"
                    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
                    cat pihole_blocklists_prod/_production_lists.txt
                    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
                fi
                
                echo
                log_info "You can copy them to your Pi-hole's custom list directory."
            fi
        fi
    else
        log_error "Pi-hole Blocklist Downloader encountered errors."
        log_error "Please check the logs for more information."
        touch .run_error
    fi
}

# Check and display Python version
check_python() {
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required but not installed."
        install_system_deps
        
        # Check again after installation attempt
        if ! command -v python3 &> /dev/null; then
            log_error "Python 3 installation failed. Please install manually and try again."
            exit 1
        fi
    fi
    
    # Check Python version
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
    
    if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 6 ]); then
        log_error "Python 3.6 or higher is required. You have Python $PYTHON_VERSION."
        if can_use_sudo; then
            log_info "Attempting to install newer Python version..."
            install_system_deps
        else
            log_error "Please upgrade Python and try again."
            exit 1
        fi
    else
        log_debug "Using Python $PYTHON_VERSION"
    fi
}

# Main function
main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Print banner
    print_banner
    
    # Detect system information
    detect_system
    
    # Check Python
    check_python
    
    # Create/check virtual environment
    create_venv
    
    # Activate virtual environment if it exists and is valid
    if [ -d "venv" ] && [ ! -f ".no_venv" ]; then
        log_info "Checking virtual environment..."
        if check_venv; then
            log_info "Activating virtual environment..."
            # shellcheck disable=SC1091
            source venv/bin/activate
            if [ $? -ne 0 ]; then
                log_warn "Failed to activate virtual environment, continuing without it..."
                touch .no_venv
            fi
        else
            log_warn "Virtual environment appears corrupted, continuing without it..."
            touch .no_venv
        fi
    fi
    
    # Install dependencies
    install_deps
    
    # Check/create configuration file
    create_config
    
    # Run the Python script
    run_script
    
    # Deactivate virtual environment if it was activated
    if [ -d "venv" ] && [ ! -f ".no_venv" ]; then
        if type deactivate >/dev/null 2>&1; then
            deactivate
        fi
    fi
    
    # Return error status if script failed
    if [ -f ".run_error" ]; then
        rm -f .run_error
        exit 1
    fi
    
    exit 0
}

main "$@"