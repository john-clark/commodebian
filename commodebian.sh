#!/bin/bash
#
# Commodebian - A menu system for Commodore Vice Emulator 
# copyright (c) 2025 - John Clark
# https://github.com/john-clark/commodebian/
VERSION=0.8

# Requirements:
# This script requires the following:
# - A Debian-based Linux distribution (e.g., Debian, Ubuntu, Raspberry Pi OS)
# - Internet access to download required packages and files
# - The script will check for the required dependencies and install them if they are missing
#
# - The script should be run in a terminal that supports dialog (for the menu interface)
# - The script can be run with sudo privileges for installation and setup tasks run with --help for more info
# - If allowed the script will:
#   - automatically check for updates and notify the user if a new version is available
#   - automatically install itself to /usr/local/bin/commodebian.sh
#   - create a directory in /usr/local/lib/commodebian/ for the functions and other libraries
#   - create a configuration file in /usr/local/etc/commodebian.conf
#   - create a log file in /usr/local/var/log/commodebian.log (not yet implemented)
# - Once fully installed the script will be run automatically from the user's profile
#   - If running on a console it will automatically run the vice emulator if it is installed and selected
#   - If running in a terminal it will display a menu to configure the emulator and other options

# Set the default values for the script
INSTALL_LOCATION="/usr/local" # Location to install Commodebian
ONLINE_URL="https://raw.githubusercontent.com/john-clark/commodebian/main/commodebian.sh" # URL to download the latest version of the script
TCPSER_URL="https://github.com/go4retro/tcpser" # URL to download tcpser

# Packages to install for vice
PACKAGES="pv build-essential autoconf automake libtool libsdl2-dev libsdl2-image-dev libcurl4-openssl-dev "
PACKAGES+="libglew-dev libpng-dev zlib1g-dev flex byacc xa65 dos2unix"


## DO NOT EDIT BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING ##

# Global variables
COMMODORE=true # set variable for function scripts to load
USER_NAME=$(whoami) # Replace 'your_username' with your actual username
ROOT=$( [ "$(id -u)" -eq 0 ] && echo "true" || echo "false" ) # Check if the script is being run as root
display_output="console" # Set the default display output
COMMODEBIAN_CONF="${INSTALL_LOCATION}/etc/commodebian.conf" # Configuration file location
LOG_FILE="/tmp/log/commodebian.log" # Log file location (not yet implemented)
TCPSER_BIN="${INSTALL_LOCATION}/bin/tcpser" # tcpser binary location
PROFILE_FILE="/home/${USER_NAME}/.profile" # Profile file to add autostart lines

# Determine script directory safely
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")"
else
    SCRIPT_DIR="$(dirname "$(realpath "$0" 2>/dev/null || echo "$0")")"
fi
[ -z "$SCRIPT_DIR" ] || [ ! -d "$SCRIPT_DIR" ] && {
    echo "Error: Could not determine valid script directory" >&2
    exit 1  # Initial exit before safe_exit is defined
}

# Ensure log directory exists
[ ! -d "$(dirname "$LOG_FILE")" ] && mkdir -p "$(dirname "$LOG_FILE")"
[ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
[ ! -s "$LOG_FILE" ] && echo "Log file initialized." > "$LOG_FILE" || echo "Log file exists. Continuing..." >> "$LOG_FILE"

# Autostart configuration
declare -ra PROFILE_AUTOSTART_LINES=(
    "# Commodebian Autostart"
    "if [ -f \"$COMMODEBIAN_CONF\" ]; then clear && $INSTALL_LOCATION/bin/commodebian.sh boot || $INSTALL_LOCATION/bin/commodebian.sh menu; fi"
)

# Function files to load
functions_to_load=(
    "utils.sh"
    "config.sh"
    "menu.sh"
    "system.sh"
    "tcpser.sh"
    "vice.sh"
)

## Essential functions ##

# Function to log messages
log_message() {
    # Ensure the log file exists and is writable
    local message="$1"
    local level="${2:-info}" # Default level is "info"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# Safe exit function that doesn't close the terminal and provides cleanup
safe_exit() {
    # store function calling safe_exit as variable

    local exit_code="${1:-0}"          # Default exit code is 0 (success) if not provided
    local message="${2:-"Exiting..."}" # Default message if none provided
    local display_type="${3:-"$display_output"}" # Use global display_output if not specified

    # Perform cleanup tasks (add more as needed)
    if type cleanup &>/dev/null; then
        cleanup  # Call a cleanup function if it exists
    fi

    # Display exit message
    if [[ "$display_type" == "console" ]]; then
        echo "$message"
    elif [[ "$display_type" == "dialog" ]]; then
        dialog --msgbox "$message" 6 40
    fi

    # Log the exit message
    log_message "$message"
    log_message "Exiting with code $exit_code"

    # If sourced, return instead of exit to prevent closing the shell
    if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
        return "$exit_code"
    else
        # If run as a script, exit with the specified code
        exit "$exit_code"
    fi
}

# Error handling function
handle_error() {
    local line_number=$1
    echo "Error occurred in line ${line_number}" >&2
    echo "Error occurred in line ${line_number}" >> "$LOG_FILE"
    safe_exit 1
}

# Set error trap
trap 'handle_error ${LINENO}' ERR

# Log the start of the script
log_message "Starting Commodebian script version $VERSION"
log_message "Script directory: $SCRIPT_DIR"
log_message "Running as user: $USER_NAME"
log_message "Running as root: $ROOT"
log_message "Display output set to: $display_output"
log_message "Installation location: $INSTALL_LOCATION"
log_message "Configuration file: $COMMODEBIAN_CONF"
log_message "TCPSer binary location: $TCPSER_BIN"
log_message "Profile file: $PROFILE_FILE"
log_message "Checking for required directories and files..."
# Check if the installation location exists
if [ ! -d "$INSTALL_LOCATION" ]; then
    log_message "Installation location $INSTALL_LOCATION does not exist. Creating..."
    mkdir -p "$INSTALL_LOCATION"
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to create installation location $INSTALL_LOCATION" "error"
        safe_exit 1
    fi
else
    log_message "Installation location $INSTALL_LOCATION exists."
fi
# Check if the configuration file exists
if [ ! -f "$COMMODEBIAN_CONF" ]; then
    log_message "Configuration file $COMMODEBIAN_CONF does not exist. Creating..."
    touch "$COMMODEBIAN_CONF"
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to create configuration file $COMMODEBIAN_CONF" "error"
        safe_exit 1
    fi
else
    log_message "Configuration file $COMMODEBIAN_CONF exists."
fi

# Check if the script is being run from the /usr/local/bin directory
if [[ "$SCRIPT_DIR" != "/usr/local/bin" ]]; then
    # If not, use the local script directory for loading functions
    LOAD_FUNCTIONS_DIR="$SCRIPT_DIR/functions"
else 
    # If the script is being run from /usr/local/bin, use the installed location for loading functions
    LOAD_FUNCTIONS_DIR="$INSTALL_LOCATION/lib/functions"
fi

# check if files exist int their locations
for func_file in "${functions_to_load[@]}"; do
    # Construct the full path to the function file
    func_path="$LOAD_FUNCTIONS_DIR/$func_file"
    
    # Check if the file exists
    if [ ! -f "$func_path" ]; then
        echo "Error: Required function file '$func_path' not found in directory '$LOAD_FUNCTIONS_DIR'."
        safe_exit 1
    fi
    
    # Source the function file to load the functions
    if ! source "$func_path"; then
        echo "Error: Failed to source '$func_path'. Please check the file for errors."
        safe_exit 1
    fi
done

# Check if the functions were loaded successfully
missing_functions=()
for func in check_ssh boot_emu show_main_menu run_with_sudo display_message; do
    if ! type "$func" &> /dev/null; then
        missing_functions+=("$func")
    fi
done
if [ ${#missing_functions[@]} -ne 0 ]; then
    echo "Error: Failed to load the following required functions: ${missing_functions[*]}"
    safe_exit 1
fi

# Load the terminal display settings
set_terminal_display

## Main script starts here ##

# Check for modifier keywords
case "$1" in
    boot)
        # this is to run the emulator at boot
        check_ssh
        boot_emu
        safe_exit 0
        ;;
    menu)
        # this is to configure the emulator to run at boot
        show_main_menu
        safe_exit 0
        ;;
    install)
        # this is to install the requirements for the script
        run_with_sudo install_commodebian
        safe_exit 0
        ;;
    setup)
        # this is to setup the requirements for the vice emulator
        display_message "Setting up Commodebian..." $display_output "info"
        run_with_sudo setup_commodebian
        safe_exit 0
        ;;
    update)
        # this is to update the script
        run_with_sudo self_update
        if [ $? -eq 0 ]; then
            show_main_menu
        else
            safe_exit 1
        fi
        safe_exit 0
        ;;
    --help)
        # Display help message
        echo "Commodebian - A menu system for the Commodore Vice Emulator"
        echo ""
        echo "Usage: $0 [boot|menu|install|update|--help|--version]"
        echo ""
        echo "Options:"
        echo "  boot       - Run the boot sequence"
        echo "  menu       - Show the configuration menu"
        echo "  install    - Install requirements for the script"
        echo "  setup      - Setup the requirements for the vice emulator"
        echo "  update     - Update the script"
        echo "  --help     - Show this help message"
        echo "  --version  - Show the version of the script"
        echo ""
        echo "  Running without any options will display the main menu if installed correctly."
        safe_exit 0
        ;;
    --version)
        # Display version
        echo "You are running Commodebian version $VERSION"
        show_script_online_version
        safe_exit 0
        ;;
    "")
        # No option provided, continue with the script
        ;;
    *)
        # Invalid option, show help
        echo "Invalid option: $1"
        echo "Use --help to see the available options."
        safe_exit 1
        ;;
esac

### script was run with no options ###
function main_loop {
    
    # Ensure prerequisites are met
    check_script_prerequisites || {
        display_message "Prerequisites not met. Exiting..." $display_output "error"
        safe_exit 1
    }

    # if installed change messages do dialog
    set_message_display

    # show welcome message
    show_welcome

    # Check installation
    check_script_installation || {
        display_message "Commodebian not setup. Please run the script with sudo and the install option." $display_output "error"
        safe_exit 1
    }

    # Check configuration
    check_config || show_not_setup

    # Warn if running as root
    [ "$ROOT" = "true" ] &&
        display_message "You are running as root. It is recommended to run this script as a normal user." $display_output "warning"

    # Show main menu
    show_main_menu

    # Show exit message
    show_exit
}

# Run the main loop
main_loop