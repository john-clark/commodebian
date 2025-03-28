#!/bin/bash
# filepath: commodebian/functions/tcpser.sh
# tcpser-related functions

# Make sure this was called from the main script
if [[ -z "$COMMODORE" ]]; then
    echo "This script is not meant to be run directly."
    return 1
fi

# Function to start tcpser
function start_tcpser {

    [ ! -f "$TCPSER_BIN" ] && { display_message "tcpser binary not found." "dialog" "error"; return 1; }
    systemctl is-active tcpser.service > /dev/null 2>&1 && { display_message "Status: tcpser service is already running." "dialog"; return 1; }
    display_message "Starting tcpser service..." "dialog" "info"
    sudo systemctl start tcpser.service && display_message "tcpser started successfully." "dialog" "success" || display_message "Failed to start tcpser." "dialog" "error"
}

# Function to stop tcpser
function stop_tcpser {

    [ ! -f "$TCPSER_BIN" ] && { display_message "tcpser binary not found." "dialog" "error"; return 1; }
    systemctl is-active tcpser.service > /dev/null 2>&1 || { display_message "tcpser service is not running." "dialog" "error"; return 1; }
    display_message "Stopping tcpser service..." "dialog" "info"
    sudo systemctl stop tcpser.service && display_message "tcpser stopped successfully." "dialog" "success" || display_message "Failed to stop tcpser." "dialog" "error"
}

# Function to install tcpser (combines all steps)
function install_tcpser {

    # Check if tcpser is already installed
    [ -f "$TCPSER_BIN" ] && {
        # If the binary already exists, prompt the user if they want to reinstall
        display_message "tcpser binary already exists. Do you want to reinstall it?" "dialog" "yesno"
        if [ $? -eq 1 ]; then 
            display_message "tcpser binary already exists. Installation aborted by user." "dialog" "error"
            return 1; 
        fi

        # If the user chooses to reinstall, remove the existing binary
        display_message "Removing existing tcpser binary..." "dialog" "info"
        run_with_sudo rm -f "$TCPSER_BIN" || { display_message "Failed to remove existing tcpser binary." "dialog" "error"; return 1; }
    
        # If the binary doesn't exist, proceed with installation
        display_message "Existing tcpser binary removed. Proceeding with installation..." "dialog" "info"
    }
    
    # Check for required dependencies
    for cmd in wget tar make gcc systemctl; do
        command -v "$cmd" &> /dev/null || { display_message "$cmd is required but not installed." "dialog" "error"; return 1; }
    done
    download_tcpser && extract_tcpser && compile_tcpser && install_tcpser_binary && setup_tcpser_service && { display_message "tcpser installation complete! Use 'systemctl start tcpser.service' to start." "dialog"; rm -f "/tmp/tcpser-${LATEST_RELEASE}.tar.gz"; }
}

# Function to remove tcpser
function remove_tcpser {
    # Check if tcpser is installed
    [ ! -f "$TCPSER_BIN" ] && { display_message "tcpser binary not found." "dialog" "error"; return 1; }

    display_message "Removing tcpser..." "dialog" "info"
    run_with_sudo systemctl stop tcpser.service 2>/dev/null
    run_with_sudo systemctl disable tcpser.service 2>/dev/null
    run_with_sudo rm -f "/etc/systemd/system/tcpser.service" "$TCPSER_BIN" "$INSTALL_LOCATION/src/tcpser" -r
    run_with_sudo systemctl daemon-reload
    [ $? -eq 0 ] && display_message "tcpser removed successfully." "dialog" "success" || display_message "Failed to remove tcpser." "dialog" "error"
}

# Function to edit tcpser config
function edit_tcpser_config {

    # Check if the config file exists
    if ! [ -f "$TCPSER_CONF" ]; then
        display_message "TCPSER configuration file not found." "dialog" "error"
        return 1
    fi

    # Open the config file in a text editor
    dialog --colors --editbox "$TCPSER_CONF" 20 80
}

# Function to download tcpser
function download_tcpser {

    TMP_DIR="/tmp"
    REPO_URL="https://github.com/go4retro/tcpser"
    LATEST_RELEASE=$(wget -qO- "https://api.github.com/repos/go4retro/tcpser/releases/latest" | grep -oP '"tag_name": "\K[^"]+')
    ARCHIVE_URL="${REPO_URL}/archive/refs/tags/${LATEST_RELEASE}.tar.gz"
    ARCHIVE_FILE="${TMP_DIR}/tcpser-${LATEST_RELEASE}.tar.gz"

    display_message "Downloading tcpser ${LATEST_RELEASE} to ${TMP_DIR}..." "dialog" "info"
    wget -O "$ARCHIVE_FILE" "$ARCHIVE_URL" || { display_message "Failed to download tcpser from ${ARCHIVE_URL}" "dialog" "error"; return 1; }
    display_message "tcpser downloaded successfully to ${ARCHIVE_FILE}." "dialog" "success"
}

# Function to extract tcpser
function extract_tcpser {

    TMP_DIR="/tmp"
    SRC_DIR="$INSTALL_LOCATION/src/tcpser"
    LATEST_RELEASE=$(wget -qO- "https://api.github.com/repos/go4retro/tcpser/releases/latest" | grep -oP '"tag_name": "\K[^"]+')
    ARCHIVE_FILE="${TMP_DIR}/tcpser-${LATEST_RELEASE}.tar.gz"

    [ ! -f "$ARCHIVE_FILE" ] && { display_message "tcpser archive not found. Please download it first." "dialog" "error"; return 1; }
    display_message "Extracting tcpser to ${SRC_DIR}..." "dialog" "info"
    run_with_sudo mkdir -p "$SRC_DIR" || { display_message "Failed to create directory ${SRC_DIR}" "dialog" "error"; return 1; }
    run_with_sudo tar -xzf "$ARCHIVE_FILE" -C "$SRC_DIR" --strip-components=1 || { display_message "Failed to extract tcpser" "dialog" "error"; return 1; }
    display_message "tcpser extracted successfully to ${SRC_DIR}." "dialog" "success"
}

# Function to compile tcpser
function compile_tcpser {

    SRC_DIR="$INSTALL_LOCATION/src/tcpser"

    [ ! -d "$SRC_DIR" ] && { display_message "Source directory ${SRC_DIR} not found. Please extract tcpser first." "dialog" "error"; return 1; }
    # Check if make and gcc are available
    for cmd in make gcc; do
        command -v "$cmd" &> /dev/null || { display_message "$cmd is required but not installed. Please install it." "dialog" "error"; return 1; }
    done
    # Change to the source directory and compile
    display_message "Compiling tcpser in ${SRC_DIR}..." "dialog" "info"
    cd "$SRC_DIR" || { display_message "Cannot change to ${SRC_DIR}" "dialog" "error"; return 1; }
    run_with_sudo make || { display_message "Compilation failed. Check dependencies (e.g., build-essential)." "dialog" "error"; return 1; }
    display_message "tcpser compiled successfully." "dialog" "success"
}

# Function to install tcpser binary
function install_tcpser_binary {

    SRC_DIR="$INSTALL_LOCATION/src/tcpser"
    BIN_DIR="$INSTALL_LOCATION/bin"
    
    # Check if the source directory exists
    [ ! -d "$SRC_DIR" ] && { display_message "Source directory ${SRC_DIR} not found. Please compile tcpser first." "dialog" "error"; return 1; }

    # Check if the tcpser binary exists after compilation
    [ ! -f "$SRC_DIR/tcpser" ] && { display_message "tcpser binary not found in ${SRC_DIR}. Please compile it first." "dialog" "error"; return 1; }
    display_message "Installing tcpser binary to ${BIN_DIR}..." "dialog" "info"
    
    run_with_sudo install -m 755 "$SRC_DIR/tcpser" "$BIN_DIR/tcpser" || { display_message "Failed to install tcpser binary" "dialog" "error"; return 1; }
    display_message "tcpser binary installed successfully to ${BIN_DIR}." "dialog" "success"
}

# Function to setup tcpser systemd service
function setup_tcpser_service {

    SERVICE_DIR="/etc/systemd/system"
    SERVICE_FILE="$SERVICE_DIR/tcpser.service"
    display_message "Creating tcpser systemd service..." "dialog" "info"

    # Check if the tcpser binary exists
    [ ! -f "$BIN_DIR/tcpser" ] && { display_message "tcpser binary not found. Please install it first." "dialog" "error"; return 1; }
    # Check if the service file already exists
    [ ! -d "$SERVICE_DIR" ] && { display_message "Systemd service directory not found." "dialog" "error"; return 1; }
    
    # Create the service file
    local service_lines=(
        "[Unit]"
        "Description=tcpser - TCP to Serial Bridge for Retro Computing"
        "After=network.target"
        ""
        "[Service]"
        "ExecStart=$INSTALL_LOCATION/bin/tcpser -v 25232 -p 6400 -s 2400 -tSs -l 7"
        "ExecStop=/usr/bin/pkill -f tcpser"
        "Restart=always"
        "User=nobody"
        "Group=nogroup"
        ""
        "[Install]"
        "WantedBy=multi-user.target"
    )
    # Write the service file using run_with_sudo to ensure proper permissions
    run_with_sudo write_file "$SERVICE_FILE" service_lines[@]
    [ $? -ne 0 ] && { display_message "Failed to create service file" "dialog" "error"; return 1; }

    # Reload systemd and enable the service
    run_with_sudo systemctl daemon-reload || { display_message "Failed to reload systemd daemon" "dialog" "error"; return 1; }
    run_with_sudo systemctl enable tcpser.service || { display_message "Failed to enable tcpser service" "dialog" "error"; return 1; }
    display_message "tcpser service setup successfully." "dialog" "success"
}

# Function to view tcpser status
function view_tcpser_status {

    # Check if the tcpser binary exists
    [ ! -f "$TCPSER_BIN" ] && { display_message "tcpser binary not found." "dialog" "error"; return 1; }
    STATUS=$(systemctl is-active tcpser.service)
    [ "$STATUS" = "active" ] && display_message "tcpser is running." "dialog" "info" || display_message "tcpser is not running." "dialog" "error"
}

# Function to view tcpser help
function view_tcpser_help {

    # Check if the tcpser binary exists
    [ ! -f "$TCPSER_BIN" ] && { display_message "tcpser binary not found." "dialog" "error"; return 1; }
    # Display the help information for tcpser
    $TCPSER_BIN -h | dialog --colors --textbox - 20 80
}

# function to check if tcpser is installed
function check_tcpser {

    # Check if tcpser is installed
    if ! command -v tcpser &> /dev/null; then
        display_message "tcpser is not installed. Would you like to install it?" $display_output "yesno"
        if [ $? -eq 0 ]; then
            run_with_sudo apt install -y tcpser
            if [ $? -ne 0 ]; then
                display_message "Failed to install tcpser." $display_output "error"
                return 1
            fi
        else
            display_message "tcpser is not installed. Please install it manually." $display_output "error"
            return 1
        fi
    fi
}

# function to check if tcpser is running
function check_tcpser_running {

    # Check if tcpser is running
    if ! pgrep -x "tcpser" > /dev/null; then
        display_message "tcpser is not running. Would you like to start it?" $display_output "yesno"
        if [ $? -eq 0 ]; then
            run_with_sudo systemctl start tcpser
            if [ $? -ne 0 ]; then
                display_message "Failed to start tcpser." $display_output "error"
                return 1
            fi
        else
            display_message "tcpser is not running. Please start it manually." $display_output "error"
            return 1
        fi
    fi
}

# function to check if tcpser is configured
function check_tcpser_config {

    # Check if tcpser is configured
    if ! grep -q "tcpser" "$COMMODEBIAN_CONF"; then
        display_message "tcpser is not configured. Would you like to configure it?" $display_output "yesno"
        if [ $? -eq 0 ]; then
            run_with_sudo change_config "TCP_PORT" "6502"
            if [ $? -ne 0 ]; then
                display_message "Failed to configure tcpser." $display_output "error"
                return 1
            fi
        else
            display_message "tcpser is not configured. Please configure it manually." $display_output "error"
            return 1
        fi
    fi
}

