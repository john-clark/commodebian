#!/bin/bash
#
# Commodebian - A menu system for Commodore Vice Emulator 
# copyright (c) 2025 - John Clark
# https://github.com/john-clark/commodebian/
VERSION=0.5
USER_NAME="emu" # Replace 'your_username' with your actual username
ONLINE_URL="https://raw.githubusercontent.com/john-clark/commodebian/main/commodebian.sh" # URL to download the latest version of the script
INSTALL_LOCATION="/usr/local" # Location to install Commodebian
COMMODEBIAN_CONF="$INSTALL_LOCATION/etc/commodebian.conf" # Configuration file
PACKAGES="pv build-essential autoconf automake libtool libsdl2-dev libsdl2-image-dev libcurl4-openssl-dev libglew-dev libpng-dev zlib1g-dev flex byacc xa65 dos2unix" # Packages to install
TCPSER_URL="https://github.com/go4retro/tcpser" # URL to download tcpser
TCPSER_BIN="$INSTALL_LOCATION/bin/tcpser" # tcpser binary location
PROFILE_FILE="/home/$USER_NAME/.profile" # Profile file to add autostart lines
PROFILE_AUTOSTART_LINES=(
    "# Commodebian Autostart"
    "if [ -f \"$COMMODEBIAN_CONF\" ]; then clear && $INSTALL_LOCATION/bin/commodebian.sh boot || $INSTALL_LOCATION/bin/commodebian.sh menu; fi"
)
# Check if the script is being run as root
ROOT=$( [ "$(id -u)" -eq 0 ] && echo "true" || echo "false" )

display_output="console" # Default display output

function wait_for_keypress {
    read -n 1 -s -r -p "Press any key to continue..."
}

# Function to display messages in console or dialog
function display_message {
    local message="$1"             # Message to display
    local display="${2:-console}"  #"console" or "dialog"
    local type="${3:-info}"        # Default type is "info" (can be "info", "error", "success", or "yesno")

    case "$display" in
        console)
        # Display a console message
            case "$type" in
                info) echo -e "$message"                           # Default text for info
                      wait_for_keypress ;;
                error) echo -e "\033[31mError: $message\033[0m" ;; # Red text for errors
                success) echo -e "\033[32m$message\033[0m" ;;      # Green text for success
                yesno) echo -n "$message"                          # Prompt for yes/no
                    read -p " (y/n): " response
                    case "$response" in
                        [yY]) return 0 ;;
                        *) return 1 ;;
                    esac ;;          
                *) echo "$message" ;;                              # Default text for info
            esac ;;
        dialog)
        # Display a dialog message
        # automatically detirme the message box size based on the message length
            local height=$(( $(echo "$message" | wc -l) + 5 ))
            local width=$(( ${#message} + 10 ))
            # for each \n add an extra line to the height
            height=$(( $height + $(echo "$message" | grep -o "\n" | wc -l) ))
            case "$type" in
                info)    dialog --infobox "$message" $height $width                        # Default text for info
                         wait_for_keypress ;;
                error)   dialog --colors --msgbox "\Z1Error: $message\Zn" $height $width ;; # Red text for errors
                success) dialog --colors --msgbox "\Z2$message\Zn" $height $width ;;        # Green text for success
                yesno)   dialog --yesno "$message" $height $width                           # Prompt for yes/no
                         return $? ;;
                *)       dialog --msgbox "$message" $height $width ;;                       # Default text for info
            esac ;;
        # todo: add support for other display types
        *) echo "Invalid display type." ;;
    esac
}

# Function to display the status of the last command
function dialog_status {
    [ $1 -eq 0 ] && display_message "successful." "dialog" "success" || display_message "$2 failed." "dialog" "error"
}

# function to move file to backup
function backup_file {
    local file="$1"
    # Check if file is provided
    if [ -z "$file" ]; then
        display_message "No file specified." $display_output "error"
        return 1
    fi

    # Check if file exists
    if [ -f "$file" ]; then
        # Check if the file is in use
        if lsof "$file" &>/dev/null; then
            display_message "File $file is currently in use. Cannot create a backup." $display_output "error"
            return 1
        fi

        local backup_index=1
        local backup_file="$file.bak.$(printf "%02d" $backup_index)"
        # Find the next available backup file name
        while [ -f "$backup_file" ]; do
            backup_index=$((backup_index + 1))
            backup_file="$file.bak.$(printf "%02d" $backup_index)"
        done
        # Move the file to the next available backup name
        mv "$file" "$backup_file"
        if [ $? -ne 0 ]; then
            display_message "Failed to move $file to $backup_file." $display_output "error"
            return 1
        fi
        display_message "File moved to $backup_file successfully." $display_output "success"
    else
        display_message "File $file does not exist." $display_output "error"
        return 1
    fi
}

# Function to write a file
function write_file {
    local file="$1"
    shift
    local lines=("$@")
    local temp_file=$(mktemp)

    # Write the lines to a temp file
    for line in "${lines[@]}"; do
        echo "$line" >> "$temp_file"
    done

    # Check if the file was written successfully
    if [ $? -ne 0 ]; then
        display_message "Failed to write temporary file for $file at $temp_file." $display_output "error"
        return 1
    fi

    # Check if the target file exists and is writable
    if [ -f "$file" ]; then
        if [ -w "$file" ]; then
            backup_file "$file"
            if [ $? -ne 0 ]; then
                display_message "Failed to backup $file." $display_output "error"
                return 1
            fi
        else
            display_message "File $file is not writable." $display_output "error"
            return 1
        fi
    fi

    # Move the temp file to the target location
    if [ -f "$temp_file" ] && [ -w "$temp_file" ]; then
        mv "$temp_file" "$file"
        if [ $? -ne 0 ]; then
            display_message "Failed to write to $file." $display_output "error"
            return 1
        fi
    else
        display_message "Temporary file $temp_file does not exist or is not writable." $display_output "error"
        return 1
    fi
}

# Function to check if sudo is available and the user has permission
function check_sudo {
    # Check if sudo is installed
    if ! command -v sudo &> /dev/null; then
        display_message "'sudo' is not installed. Please install it and try again." $display_output "error"
        return 1
    fi
    # Check if the user has sudo privileges
    if ! sudo -n true 2>/dev/null; then
        display_message "You do not have permission to use 'sudo' or a password is required." $display_output "error"
        return 1
    fi
    return 0
}

# Function to run a command with sudo
function run_with_sudo {
    # Check if sudo is available
    check_sudo || return 1
    # Run the command with sudo
    sudo "$@"
}

# function to install prerequisites
function install_prerequisites {
    if [ $ROOT = "true" ]; then
        apt update -qq && apt install -y dialog wget sudo
        if [ $? -ne 0 ]; then
            display_message "Failed to install prerequisites." "console" "error"
            exit 1
        fi
    else
        display_message "Please enter the root password to install the prerequisites." "console"
        read -s root_password
        echo
        su -c "bash $0 install" <<EOF
$root_password
EOF
        if [ $? -ne 0 ]; then
            display_message "Failed to install prerequisites." "console" "error"
            exit 1
        fi
    fi
}

# Function to check if prerequisites are installed
function check_script_prerequisites {
    # Hard dependencies for the script either have them or exit
    local missing=()
    for cmd in dialog wget sudo; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    # Check if any prerequisites are missing
    if [ ${#missing[@]} -ne 0 ]; then
        display_message "The following prerequisites are missing: ${missing[*]}" "console" "error"
        display_message "In the future you can run \"commodebian install\" as root to install them or install manually." "console"
        display_message "Would you like to do this now" "console" "yesno"
        if [ $? -eq 0 ]; then
            install_prerequisites
        else
            display_message "Please install the missing prerequisites and run the script again." "console" "error"
            exit 1
        fi
    fi
}

# If prerequisites are not installed, use console for messages
function set_message_display {
    if check_script_prerequisites; then
        display_output="dialog"
    fi
}

# Function to change file permissions (#fix this to either use echo or dialog)
function change_file_permissions {
    local file="$1"
    local permissions="$2"

    if [ -z "$file" ] || [ -z "$permissions" ]; then
        display_message "File or permissions not specified." $display_output "error"
        return 1
    fi

    echo "Changing permissions of $file to $permissions"
    run_with_sudo chmod "$permissions" "$file" || {
        display_message "Failed to change permissions for $file" $display_output "error"
        return 1
    }

    display_message "Permissions changed successfully for $file" $display_output "success"
    return 0
}

# Function to check if running in ssh
function check_ssh {
    if [ "$SSH_CONNECTION" ]; then
        # Running in a remote session
        #display_message "Detected: Remote SSH session. Please run this script from the console or terminal." $display_output "info"
        return 1
    fi
}

# Function to check if running in a console or terminal
function set_terminal_display {
    if check_ssh; then
        # Running in a console
        BACKTITLE="Commodebian $VERSION"
    else
        # Running in a terminal
        BACKTITLE="Commodebian $VERSION (TERMINAL MODE)"
    fi
}
set_terminal_display

#function to check the online version
function check_online_version {
    #wget the latest version and check version number
    wget -qO- $ONLINE_URL | grep -m1 -o 'VERSION=[0-9]\+\.[0-9]\+' | cut -d= -f2
}

#function to show the latest online version
function show_dialog_online_version {
    LATEST_VERSION=$(check_online_version)
    dialog --title "Commodebian Version" --msgbox "The latest version of Commodebian is $LATEST_VERSION" 6 50
}

#function to show the current online version on the console
function show_script_online_version {
    LATEST_VERSION=$(check_online_version)
    echo "The latest version of Commodebian is $LATEST_VERSION"
}

# Function to check Commodebian version
function check_script_version {
    #wget the latest version and check version number
    LATEST_VERSION=$(wget -qO- $ONLINE_URL | grep -m1 -o 'VERSION=[0-9]\+\.[0-9]\+' | cut -d= -f2)
    #LATEST_VERSION=$(curl -s $ONLINE_URL | grep 'version=' | awk -F'=' '{print $2}')
    if ! [ "$VERSION" = "$LATEST_VERSION" ]; then
        display_message "Commodebian is outdated. Would you like to update?" $display_output "yesno"
        if [ $? -eq 0 ]; then
            self_update
        fi
    fi
}

# Function to check if the script is being run from $INSTALL_LOCATION/bin
function check_script_location {
    if ! [ "$(realpath "$0")" = "$INSTALL_LOCATION/bin/commodebian.sh" ]; then
        display_message "This script should be run from $INSTALL_LOCATION/bin/commodebian.sh" $display_output "error"
        # wait for keypress
        read -n 1 -s -r -p "Press any key to continue..."
        exit 1
    fi
}

# Function to check if Commodebian is installed
function check_script_installation {
    # check prerequisites
    check_script_prerequisites || install_prerequisites
    
    # test if commodebian.sh is in the install location
    if ! [ -f "$INSTALL_LOCATION/bin/commodebian.sh" ]; then
        display_message "Commodebian is not installed. Would you like to install it?" $display_output "yesno"
        if [ $? -eq 0 ]; then
            run_with_sudo install_commodebian
        else
            display_message "Commodebian is not installed." $display_output "error"
            return 1
        fi
    fi
    #test if commodebian.sh is in the path
    if ! command -v commodebian.sh &> /dev/null; then
        display_message "Commodebian is not in path. Would you like to include /usr/local/bin in your profie?" $display_output "yesno"
        if [ $? -eq 0 ]; then
            display_message "Adding /usr/local/bin to profile..." $display_output
            echo "export PATH=$PATH:/usr/local/bin" >> $PROFILE_FILE
            source $PROFILE_FILE
        else
            display_message "Commodebian is not in path. Please add /usr/local/bin to your profile." $display_output "error"
            return 1
        fi
    fi

    #test to see if script was run as /usr/local/bin/commodebian.sh
    if ! [ "$(realpath "$0")" = "$INSTALL_LOCATION/bin/commodebian.sh" ]; then
        display_message "Commodebian is installed but not running from correct path.\n\nContinue?" $display_output "yesno"
        # if yes then continue if no exit
        if [ $? -eq 0 ]; then
            return 0
        else
            return 1
        fi
    fi

    #check version - since check prerequisites is run first, we can assume dialog is installed
    check_script_version
}

# Centralized function to check configuration file
function check_config {
    # Check if the config file exists
    if [ ! -f "$COMMODEBIAN_CONF" ]; then
        display_message "Configuration file not found at $COMMODEBIAN_CONF." $display_output "error"
        display_message "Would you like to create it?" $display_output "yesno"
        if [ $? -eq 0 ]; then
            run_with_sudo create_config
        else
            display_message "Commodebian is not setup." $display_output "error"
            return 1
        fi
    fi
    # Check if the file is readable
    if [ ! -r "$COMMODEBIAN_CONF" ]; then
        display_message "Configuration file at $COMMODEBIAN_CONF is not readable." display_message $display_output "error"
        display_message "Would you like to change the permissions?" $display_output "yesno"
        if [ $? -eq 0 ]; then
            run_with_sudo change_file_permissions "$COMMODEBIAN_CONF" "666"
        else
            return 1
        fi
    fi

    # Validate the file's syntax without executing it
    while ! bash -n "$COMMODEBIAN_CONF"; do
        display_message "Configuration file at $COMMODEBIAN_CONF contains syntax errors." $display_output "error"
        display_message "Would you like to edit the file?" $display_output "yesno"
        if [ $? -eq 0 ]; then
            # if $display_output is dialog then use dialog to edit the file otherwise use nano
            if [ $display_output = "dialog" ]; then
                dialog --editbox "$COMMODEBIAN_CONF" 0 0 2> "$TEMP_FILE"
                if [ $? -eq 0 ]; then
                    mv "$TEMP_FILE" "$COMMODEBIAN_CONF"
                else
                    display_message "Failed to edit configuration file." $display_output "error"
                    return 1
                fi
            else
                nano "$COMMODEBIAN_CONF"
                #validate the file again
                bash -n "$COMMODEBIAN_CONF"
                if [ $? -eq 0 ]; then
                    display_message "Configuration file updated successfully." $display_output "success"
                else
                    display_message "Configuration file contains syntax errors." $display_output "error"
                    return 1
                fi
            fi
        fi
    done
}

# function to Load the configuration file
function load_config {
    # Check if the config file exists and is valid
    check_config || return 1

    # Load the configuration file
    source "$COMMODEBIAN_CONF"
    if [ $? -ne 0 ]; then
        display_message "Could not load configuration file." $display_output "error"
        return 1
    fi
}

# Function to change configuration variable
function change_config {
    # Check if the config file exists and is valid
    check_config || return 1

    # Ensure the variable name is provided
    if [ -z "$1" ]; then
        display_message "No variable specified." $display_output "error"
        return 1
    fi

    # Ensure the value is provided
    if [ -z "$2" ]; then
        display_message "No value specified." $display_output "error"
        return 1
    fi

    # Define variables
    local key="$1"
    local value="$2"
    local escaped_key=$(printf '%s' "$key" | sed 's/[\/&]/\\&/g')  # Simplified escaping
    local escaped_value=$(printf '%s' "$value" | sed 's/[\/&]/\\&/g')  # Escape value for sed

    # Check directory permissions
    local config_dir=$(dirname "$COMMODEBIAN_CONF")
    if [ ! -w "$config_dir" ]; then
        display_message "Directory $config_dir is not writable.\nRun with sudo or fix permissions." $display_output "error"
        return 1
    fi

    # Check file permissions explicitly
    if [ ! -w "$COMMODEBIAN_CONF" ]; then
        display_message "Config file $COMMODEBIAN_CONF is not writable.\nCheck permissions." $display_output "error"
        return 1
    fi

    # Check if the variable exists and update it
    if grep -q "^$escaped_key=" "$COMMODEBIAN_CONF"; then
        sed -i "s|^$escaped_key=.*|$escaped_key=\"$escaped_value\"|" "$COMMODEBIAN_CONF"
        if [ $? -ne 0 ]; then
            display_message "Failed to update $key in $COMMODEBIAN_CONF." $display_output "error"
            return 1
        fi
    else
        # Add the variable if it doesn’t exist
        echo "$escaped_key=\"$escaped_value\"" >> "$COMMODEBIAN_CONF"
        if [ $? -ne 0 ]; then
            display_message "Failed to append $key to $COMMODEBIAN_CONF." $display_output "error"
            return 1
        fi
    fi

    # Verify the change (more flexible match)
    if grep -q "^$escaped_key=\"[^\"]*\"$" "$COMMODEBIAN_CONF"; then
        display_message "Configuration updated successfully.\n$key set to \"$value\"." $display_output "success"
        return 0
    else
        display_message "Could not verify update for $key.\nFile contents:\n$(cat "$COMMODEBIAN_CONF")" $display_output "error"
        return 1
    fi
}

# Function to install autostart
function install_autostart {
    # Check if the user is root
    if [ "$ROOT" = "true" ]; then
        display_message "Probably not a good idea to install a root profile." $display_output "error"
        return 1
    fi
    # Ensure the .profile file exists
    if ! [ -f "$PROFILE_FILE" ]; then
        touch "$PROFILE_FILE"
        if ! [ $? -eq 0 ]; then
            display_message "Could not create $PROFILE_FILE." $display_output "error"
            return 1
        fi
    fi

    # Add the lines to .profile if they don't already exist
    for line in "${PROFILE_AUTOSTART_LINES[@]}"; do
        if ! grep -Fxq "$line" "$PROFILE_FILE"; then
            echo "$line" >> "$PROFILE_FILE"
        fi
    done

    # Ensure all lines are written correctly
    for line in "${PROFILE_AUTOSTART_LINES[@]}"; do
        if ! grep -Fxq "$line" "$PROFILE_FILE"; then
            display_message "Failed to write line: $line" $display_output "error"
            return 1
        fi
    done
    display_message "Autostart setup completed successfully!" $display_output "success"
}

# Function to remove autostart
function remove_autostart {
    # Escape special characters in the lines for sed
    for line in "${PROFILE_AUTOSTART_LINES[@]}"; do
        escaped_line=$(printf '%s\n' "$line" | sed 's/[]\/$*.^[]/\\&/g')
        sed -i "/$escaped_line/d" "$PROFILE_FILE"
    done

    display_message "Autostart removed successfully!" $display_output "success"
}

# Function to edit the user profile
function edit_profile {
    check_script_prerequisites
    PROFILE_FILE="$HOME/.profile"
    TEMP_FILE=$(mktemp)
    # Check if the .profile file exists
    if ! [ -f "$PROFILE_FILE" ]; then
        display_message "$PROFILE_FILE does not exist." "dialog" "error"
        return 1
    fi

    # Display the current contents of the .profile file in an editor
    dialog --title "Edit User Profile" --editbox "$PROFILE_FILE" 20 60 2> "$TEMP_FILE"
    RESPONSE=$?

    # Check if the user pressed Cancel or entered an empty input
    if [ $RESPONSE -eq 0 ]; then
        # If user modified and pressed OK, update the file
        cp "$TEMP_FILE" "$PROFILE_FILE"
        dialog --msgbox "User profile updated successfully!" 6 50
    else
        # If the user pressed Cancel, notify them
        dialog --msgbox "No changes were made." 6 50
    fi
}

# Function to enable user autologin
function enable_user_autologin {
    # Define paths and service
    GETTY_SERVICE="getty@tty1.service"
    OVERRIDE_DIR="/etc/systemd/system/$GETTY_SERVICE.d"
    OVERRIDE_FILE="$OVERRIDE_DIR/autologin.conf"

    # Create override directory if it doesn’t exist
    if [ ! -d "$OVERRIDE_DIR" ]; then
        mkdir -p "$OVERRIDE_DIR"
        if [ $? -ne 0 ]; then
            display_message "Failed to create directory $OVERRIDE_DIR." $display_output "error"
            exit 1
        fi
    fi

    # Define the autologin override configuration lines
    local autologin_lines=(
        "[Service]"
        "ExecStart="
        "ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM"
    )

    # Write the autologin override configuration using the write_file function
    write_file "$OVERRIDE_FILE" autologin_lines
    if [ $? -ne 0 ]; then
        display_message "Failed to write autologin configuration to $OVERRIDE_FILE." $display_output "error"
        exit 1
    fi

    # Reload systemd to apply changes
    systemctl daemon-reload
    if [ $? -ne 0 ]; then
        display_message "Failed to reload systemd configuration." $display_output "error"
        exit 1
    fi

    # Enable the service (optional, usually enabled by default)
    systemctl enable "$GETTY_SERVICE" 2>/dev/null

    # Inform the user
    display_message "Autologin configured for user '$USER' on TTY1." $display_output "success"
}

#function to disable user autologin
function disable_user_autologin {
    OVERRIDE_DIR="/etc/systemd/system/$GETTY_SERVICE.d"
    OVERRIDE_FILE="$OVERRIDE_DIR/autologin.conf"
    # Remove the autologin override configuration
    if [ -f "$OVERRIDE_FILE" ]; then
        rm "$OVERRIDE_FILE"
        if [ $? -ne 0 ]; then
            display_message "Failed to remove autologin configuration from $OVERRIDE_FILE." $display_output "error"
            exit 1
        fi
    fi
    # Reload systemd to apply changes
    systemctl daemon-reload
    if [ $? -ne 0 ]; then
        display_message "Failed to reload systemd configuration." $display_output "error"
        exit 1
    fi
    # Inform the user
    display_message "Autologin disabled for user '$USER' on TTY1." $display_output "success"
}

# Function to create config file
function create_config {
    # check to see if commodebian is already installed
    check_script_installation

    # Check if the directory exists
    if ! [ -d "$(dirname $COMMODEBIAN_CONF)" ]; then
        display_message "Configuration directory does not exist." $display_output "error"
        return 1
    fi

    # Check if the config file already exists
    if [ -f $COMMODEBIAN_CONF ]; then
        display_message "Config file already exists." $display_output "error"
        # check if the file is readable
        if ! [ -r "$COMMODEBIAN_CONF" ]; then
            display_message "Configuration file is not readable." $display_output "error"
            return 1
        fi
        # check if the file is writable
        if ! [ -w "$COMMODEBIAN_CONF" ]; then
            display_message "Configuration file is not writable." $display_output "error"
            return 1
        fi
        # check if the file is valid
        if ! bash -n "$COMMODEBIAN_CONF"; then
            display_message "Configuration file contains syntax errors." $display_output "error"
            return 1
        fi
        # check if the file is empty
        if [ ! -s "$COMMODEBIAN_CONF" ]; then
            display_message "Configuration file is empty." $display_output "error"
            return 1
        fi

        display_message "Loading configuration file..." $display_output "info"
        # load the config file
        source $COMMODEBIAN_CONF
        # check if file loaded correctly
        if [ $? -ne 0 ]; then
            display_message "Could not load config file." $display_output "error"
            return 1
        fi

        # check if version is set
        if ! [ -z "$VERSION" ]; then
            # found version don't need to recreate
            return 0
        else
            # version not found display error
            display_message "Could not load version from config file." $display_output "error"
            return 1
        fi
    fi

    # Check if the file can be created
    if ! run_with_sudo touch "$COMMODEBIAN_CONF"; then
        display_message "Could not create config file." $display_output "error"
        return 1
    fi

    # Write the default values to the config file
    echo "Creating configuration file at $COMMODEBIAN_CONF..."
    # Define the configuration lines
    local config_lines=(
        "#!/bin/bash"
        "#Commodebian Configuration File"
        "#This file is automatically generated by the Commodebian script."
        "#Do not edit this file directly. Use the Commodebian script to modify it."
        "VERSION=0.4"
        "#DEFAULT EMULATOR"
        "EMU=$INSTALL_LOCATION/bin/x64"
        "#DEFAULT OPTIONS"
        "OPTS=-sdl2"
        "#DEFAULT ROM"
        "ROM=$INSTALL_LOCATION/share/vice/C64/kernal.rom"
        "#DEFAULT DISK"
        "DISK=$INSTALL_LOCATION/share/vice/C64/blank.d64"
        "#DEFAULT TAPE"
        "TAPE=$INSTALL_LOCATION/share/vice/C64/blank.t64"
        "#DEFAULT CARTRIDGE"
        "CRT=$INSTALL_LOCATION/share/vice/C64/blank.crt"
    )
    # Use the write_file function to write the configuration
    run_with_sudo write_file "$COMMODEBIAN_CONF" config_lines[@]
    [ $? -eq 0 ] && chmod 666 "$COMMODEBIAN_CONF" && display_message "Configuration file created successfully." $display_output "success" || { display_message "Could not create config file." $display_output "error"; return 1; }

    # Set the file permissions
    run_with_sudo chmod 666 $COMMODEBIAN_CONF
    if [ $? -ne 0 ]; then
        display_message "Failed to set permissions for $COMMODEBIAN_CONF." $display_output "error"
        return 1
    fi
}

# Function to check if Commodebian config is installed
function check_config {
    # Check if the script is being run from the correct location
    check_script_installation

    # Check if the configuration file exists
    if ! [ -f "$COMMODEBIAN_CONF" ]; then
        display_message "Configuration file not found. Running setup..." $display_output "info"
        create_config
        if [ $? -ne 0 ]; then
            display_message "Failed to create configuration file. Please check permissions." $display_output "error"
            return 1
        fi
    fi
    # Check if the configuration file is readable
    if ! [ -r "$COMMODEBIAN_CONF" ]; then
        display_message "Configuration file is not readable. Please check permissions." $display_output "error"
        return 1
    fi
    # Check if the configuration file is writable
    if ! [ -w "$COMMODEBIAN_CONF" ]; then
        run_with_sudo chmod 666 "$COMMODEBIAN_CONF"
        if [ $? -ne 0 ]; then
            display_message "Failed to set permissions for $COMMODEBIAN_CONF." $display_output "error"
            return 1
        fi
        display_message "Permissions set for $COMMODEBIAN_CONF." $display_output "success"
    fi
}

# Function to show the welcome message
function show_welcome {
    dialog --clear --backtitle "$BACKTITLE" --title "Welcome" --msgbox "\n   Welcome to the Commodore Debian script." 7 50
}

# Function to display the exit message
function show_exit {
    dialog --clear --backtitle "$BACKTITLE" --title "Goodbye" --msgbox "\nThank you for using the Commodore Debian script." 7 60
}

# Function to display the about menu
function show_about_menu {
    MESSAGE="\n                     Commodebian\n\n"
    MESSAGE+="The menu system for the Commodore Vice Emulator.\n\n"
    MESSAGE+="  Author: 5k7m4n\n  Email: 5k7m4n@gmail.com\n\n"
    MESSAGE+="This script is released under the GNU Public License.\n\n"
    MESSAGE+="For more information, visit the GitHub repository:\n"
    MESSAGE+="  https://github.com/john-clark/commodebian\n\n\n"
    MESSAGE+="Hit ENTER to return to the main menu."
    dialog --clear --backtitle "$BACKTITLE" \
    --title "About" \
    --msgbox "$MESSAGE" 20 60
}

# Function to reboot the system
function reboot_function {
    tput civis
    clear
    # check if installed
    if check_script_installation; then
        run_with_sudo shutdown -r now
        exit 0
    else
        display_message "\nERROR can't shutdown not installed correctly.\n\nPlease run this script as root or with sudo." $display_output "error"
        tput cvvis
        exit 1
    fi
}

# Function to shutdown the system
function shutdown_function {
    tput civis
    clear
    if check_script_installation; then
        run_with_sudo shutdown -h now
        exit 0
    else
        display_message "\nERROR can't shutdown not installed correctly.\n\nPlease run this script as root or with sudo." $display_output "error"
        tput cvvis
        exit 1
    fi
}

# Function to boot the emulator
function boot_emu {
    display_message "Running emulator..." $display_output "info"
    # check if running in terminal
    if ! check_ssh; then
        display_message "This option is only available from the console." "console" "error"
        return 1
    fi
    # check to see if script is being run from $INSTALL_LOCATION/bin
    if ! [ -f $INSTALL_LOCATION/bin/commodebian.sh ]; then
        setup_commodebian
    fi

    # Check if the configuration file exists
    if ! [ -f "$COMMODEBIAN_CONF" ]; then
        setup_commodebian
    else
        display_message "Configuration file found. Loading configuration..." "console" "info"
        source $COMMODEBIAN_CONF
        # Check if the configuration file loaded correctly
        if [ $? -ne 0 ]; then
            display_message "Could not load configuration file." "console" "error"
            exit 1
        fi
        # Check if the version is set
        if [ -z "$VERSION" ]; then
            display_message "Could not load version from config file. Running the setup." "console" "error"
            setup_commodebian
        fi
        # Check if the emulator is set
        if [ -z "$EMU" ]; then
            display_message "Emulator not set in config. Running the setup." "console" "info"
            setup_commodebian
        else
            # Check if the emulator exists
            if ! [ -f $EMU ]; then
                display_message "Emulator not found. Running the setup." "console" "info"
                setup_commodebian
            else
                # Check if kernel Rom is set
                if [ -z "$ROM" ]; then
                    OPTS="$OPTS -kernal $ROM"
                fi
                # if disk image is configured set the variable
                if ! [ -z "$DISK" ]; then
                    OPTS="$OPTS -diskimage $DISK"
                fi
                # if tape image is configured set the variable
                if ! [ -z "$TAPE" ]; then
                    OPTS="$OPTS -tapeimage $TAPE"
                fi
                # if cartridge is configured set the variable
                if ! [ -z "$CRT" ]; then
                    OPTS="$OPTS -cart $CRT"
                fi
                # Run the emulator with the specified options and ROM
                display_message "Running emulator: $EMU" "console" "info"
                display_message "    with options: $OPTS" "console" "info"
                $EMU $OPTS > /dev/null 2>&1
                # Check if the emulator ran successfully   
                if [ $? -eq 0 ]; then
                    display_message "Emulator running successfully." "console" "success"
                else
                    display_message "Could not run emulator." "console" "error"
                    exit 1
                fi
            fi
        fi
    fi
}

# Function to display the config menu
function show_not_setup {
    # check if prerequisites are installed
    check_script_prerequisites
    # check if commodebian is installed
    check_script_installation

    if ! [ -f $COMMODEBIAN_CONF ]; then
        SETUP_MESSAGE="\nWelcome to Commodebian!\n\nThe menu system for the Commodore Vice Emulator.\n\n"
        SETUP_MESSAGE+="This script will guide you through the setup and installation process, making it easy "
        SETUP_MESSAGE+="to configure and use.\n\nWould you like to proceed with the setup now?"

        dialog --title "Setup Commodebian" --backtitle "$BACKTITLE" --yesno "$SETUP_MESSAGE" 13 60
        RESPONSE=$?

        if [ $RESPONSE -eq 1 ]; then 
            display_message "\nSetup canceled." "dialog" "info"
            return 1
        fi
        if [ $RESPONSE -eq 0 ]; then
            display_message "\nSetup starting..." "dialog" "info"
            create_config
            show_installed_menu
        fi
    else
        display_message "Commodebian is already installed." "dialog" "error"
    fi
}

# Function to perform self-update
function self_update {
    display_message "Updating Commodebian..." $display_output "info"
    # check if running as root
    [ "$ROOT" != "true" ] && { display_message "This option must be run as root or with sudo." $display_output "error"; return 1; }
    #check if prerequisites are installed
    check_script_prerequisites
    #check if commodebian is installed
    check_script_installation
    SCRIPT_URL=$ONLINE_URL
    SCRIPT_PATH="$(realpath "$0")"
    TMP_SCRIPT="/tmp/updated_script.sh"
    TEMP_FILE=$(mktemp)

    cleanup() { rm -f "$TEMP_FILE" "$TMP_SCRIPT"; }
    trap cleanup EXIT

    # Check if script is already installed
    if [ "$SCRIPT_PATH" != "$INSTALL_LOCATION/bin/commodebian.sh" ]; then
        display_message "\nThis seems to be a first run.\nInstalling to $INSTALL_LOCATION/bin/commodebain.sh now." $display_output "info"
        cp "$SCRIPT_PATH" "$INSTALL_LOCATION/bin/commodebain.sh" 2>/dev/null
        if ! [ $? -eq 0 ]; then
            display_message "Could not copy script to $INSTALL_LOCATION/bin/commodebain.sh" $display_output "error"
            return 1
        fi
        SCRIPT_PATH=$INSTALL_LOCATION
        chmod +x "$SCRIPT_PATH"
        create_config
    fi

    # Get current script version
    CURRENT_VERSION=$(grep -m1 -o 'VERSION=[0-9]\+\.[0-9]\+' "$SCRIPT_PATH" | cut -d= -f2)
    if [[ -z "$CURRENT_VERSION" || ! "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
        display_message "Unable to determine the current version. Please check the script format." $display_output "error"
        exit 1
    fi
    CURRENT_VERSION="${CURRENT_VERSION:-0.0}"

    # Get file size for progress
    FILE_SIZE=$(curl -sI "$SCRIPT_URL" | grep -i Content-Length | awk '{print $2}' | tr -d '\r')
    [ -z "$FILE_SIZE" ] && FILE_SIZE=100000  # Fallback if size unavailable

    # Download with progress gauge
    (
        wget "$SCRIPT_URL" -O "$TMP_SCRIPT" --progress=dot 2> "$TEMP_FILE" &
        WGET_PID=$!

        while kill -0 $WGET_PID 2>/dev/null; do
            if [ -f "$TEMP_FILE" ]; then
                BYTES=$(tail -n 1 "$TEMP_FILE" | grep -o '[0-9]\+K' | tr -d 'K')
                if [ -n "$BYTES" ]; then
                    PERCENT=$(( ($BYTES * 1000 * 100) / $FILE_SIZE ))
                    [ $PERCENT -gt 100 ] && PERCENT=100
                    echo "$PERCENT"
                else
                    echo "0"
                fi
            fi
            sleep 0.5
        done
    ) | dialog --title "Updating Script" --gauge "Downloading latest version..." 8 50 0

    DOWNLOAD_STATUS=$?
    if [ $DOWNLOAD_STATUS -ne 0 ]; then
        display_message "Failed to download the script" $display_output "error"
        return 1
    fi

    # Verify downloaded file is a valid bash script
    if ! head -n 1 "$TMP_SCRIPT" | grep -q '^#!/bin/bash'; then
        display_message "Downloaded file is not a valid script" $display_output "error"
        return 1
    fi

    # Extract new version
    REMOTE_VERSION=$(grep -m1 -o 'VERSION=[0-9]\+\.[0-9]\+' "$TMP_SCRIPT" | cut -d= -f2)
    REMOTE_VERSION="${REMOTE_VERSION:-unknown}"

    # Simple version comparison (could be enhanced)
    if [ "$REMOTE_VERSION" != "unknown" ] && [ "$CURRENT_VERSION" = "$REMOTE_VERSION" ]; then
        display_message "Script is already up to date (version $CURRENT_VERSION)" $display_output "info"
        return 0
    fi

    # Define backup script path
    BACKUP_SCRIPT="${SCRIPT_PATH}.bak"

    # Backup current script
    if ! cp "$SCRIPT_PATH" "$BACKUP_SCRIPT" 2>/dev/null; then
        display_message "Could not create backup" $display_output "error"
        return 1
    fi

    # Replace script
    dialog --infobox "Installing update..." 3 50
    if cp "$TMP_SCRIPT" "$SCRIPT_PATH" && chmod +x "$SCRIPT_PATH"; then
        display_message "Update to version ${REMOTE_VERSION} successful!\n\nBackup saved as: $BACKUP_SCRIPT\n\nRestarting..." $display_output "success"
        exec "$SCRIPT_PATH" "$@"
    else
        cp "$BACKUP_SCRIPT" "$SCRIPT_PATH" 2>/dev/null
        display_message "Update failed, restored original script" $display_output "error"
        return 1
    fi
}

# Function to edit dependencies
function edit_dependencies {
    # Display the current packages in an input box
    new_packages=$(dialog --inputbox "Current Packages (edit the list):" 15 50 "$PACKAGES" 3>&1 1>&2 2>&3)

    # Check if the user pressed Cancel or entered an empty input
    if [ $? -eq 0 ]; then
        # If user modified and pressed OK, update PACKAGES
        PACKAGES="$new_packages"
        display_message "Packages updated successfully!" "dialog" "success"
    else
        # If the user pressed Cancel, notify them
        display_message "No changes were made." "dialog" "info"
    fi
}

# Function to install dependencies
function install_dependencies {
    TEMP_FILE=$(mktemp)
    LOG_FILE="/tmp/install_dependencies.log"
    # Cleanup function
    cleanup() { rm -f "$TEMP_FILE" "$LOG_FILE"; }
    trap cleanup EXIT

    # Start package installation
    DEBIAN_FRONTEND=noninteractive apt-get install -y $PACKAGES --show-progress > "$LOG_FILE" 2>&1 &
    APT_PID=$!

    # Function to parse the progress
    parse_progress() {
        local progress_line
        progress_line=$(tail -n 1 "$LOG_FILE" | grep -o 'Progress: [0-9]\+%' | awk '{print $2}' | tr -d '%')
        if [[ -n "$progress_line" ]]; then
            echo "$progress_line"
        else
            echo "0"
        fi
    }

    # Monitor progress and update the dialog
    while kill -0 $APT_PID 2>/dev/null; do
        PROGRESS=$(parse_progress)
        if [[ -z "$PROGRESS" ]]; then
            PROGRESS="0"
        fi
        echo "$PROGRESS $PROGRESS" | dialog --title "Software Install" --gauge "Installing dependencies..." 8 60 0
        sleep 0.5
    done

    # Wait for apt-get to finish
    wait $APT_PID
    APT_STATUS=$?

    # Handle status and feedback
    if [ $APT_STATUS -eq 0 ]; then
        dialog --title "Installation Successful" --msgbox "Dependencies installed successfully." 6 50
    else
        if dialog --defaultno --title "Install failed" --yesno "An error occured while installing dependencies.\n\nWould you like to review the log file now?" 7 60; then
            if command -v less &> /dev/null; then
                less "$LOG_FILE"
            else
                cat "$LOG_FILE"
            fi
        fi
    fi
}

# Function to download Vice
function download_vice {
    URL="https://sourceforge.net/projects/vice-emu/files/releases/vice-3.9.tar.gz/download"
    FILE="/tmp/vice-3.9.tar.gz"  # Ensure it's saved to /tmp

    # Check if the file already exists
    if [ -f "$FILE" ]; then
        display_message "Vice archive already exists at $FILE. Skipping download." "dialog" "info"
    else
        display_message "Downloading Vice..." "dialog" "info"
        # Download the file to /tmp
        wget -q --show-progress -O "$FILE" "$URL"
        
        # Check if the download was successful
        if [ $? -eq 0 ]; then
            display_message "Vice downloaded successfully to $FILE." "dialog" "success"
        else
            display_message "Failed to download Vice." "dialog" "error"
        fi
    fi
}

# Function to extract Vice
function extract_vice {
    EXTRACT_DIR="$INSTALL_LOCATION/src/vice-3.9"  # Define the destination directory
    FILE="/tmp/vice-3.9.tar.gz"  # Ensure this is the correct path to the downloaded file

    if [ ! -f "$FILE" ]; then
        display_message "$FILE does not exist. Please download the Vice archive first." "dialog" "error"
        return 1
    fi

    # Check if the extraction directory exists
    if [ -d "$EXTRACT_DIR" ]; then
        dialog --title "Overwrite Directory" --yesno --defaultno "The directory $EXTRACT_DIR already exists. Do you want to overwrite it?" 7 60
        RESPONSE=$?

        if [ $RESPONSE -eq 1 ]; then  # If "No" is selected (EXIT_STATUS is 1)
            display_message "Extraction canceled." "dialog" "info"
            return 1
        fi
    else
        # Create the directory if it does not exist
    mkdir -p "$EXTRACT_DIR"
    fi

    # Extract the file to $INSTALL_LOCATION/src/vice-3.9
    display_message "Extracting Vice to $EXTRACT_DIR..." "dialog" "info"
    tar -xzf "$FILE" -C "$EXTRACT_DIR" > /dev/null 2>&1

    # Check if the extraction was successful
    if [ $? -eq 0 ]; then
        display_message "Vice extracted successfully to $EXTRACT_DIR." "dialog" "success"
    else
        display_message "Failed to extract Vice." "dialog" "error"
    fi
}

# Function to build Vice
function build_vice {
    if ! cd vice-3.9/; then
        display_message "Could not change to vice-3.9 directory" "dialog" "error"
        return 1
    fi
    display_message "Running autogen.sh..." "dialog" "info"
    ./autogen.sh > /dev/null 2>&1
    dialog_status $? "Ran autogen.sh"

    display_message "Configuring Vice...\Zn" "dialog" "info"
    CFLAGS="-Wno-array-bounds" CXXFLAGS="-Wno-array-bounds" ./configure --disable-pdf-docs --enable-sdl2ui --disable-gtk3ui > /dev/null 2>&1
    dialog_status $? "Configured Vice"

    {
        echo 10; sleep 1
        echo 30; sleep 1
        echo 50; sleep 1
        echo 70; sleep 1
        echo 100
    } | dialog --gauge "Building Vice..." 6 50 0

    make -j$(nproc) -s | pv -p -e > build.log
    dialog_status $? "Built Vice"
}

# Function to install Vice
function install_vice {
    display_message "Installing Vice..." "dialog" "info"
    make install > /dev/null 2>&1
    dialog_status $? "Installed Vice"
}

# Function to configure system
function configure_system {
    # check if prerequisites are installed
    check_script_prerequisites
    # check if commodebian is installed
    check_script_installation
    # check if commodebian is setup
    check_commodebian_setup
    # check if commodebian is up to date
    check_script_version

    # show install menu
    show_install_menu
    display_message "System configured successfully." "dialog" "success"
}

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
    [ "$ROOT" != "true" ] && { display_message "Root access required." "dialog" "error"; return 1; }
    [ -f "$TCPSER_BIN" ] && { display_message "tcpser binary already exists." "dialog" "error"; return 1; }
    for cmd in wget tar make gcc systemctl; do
        command -v "$cmd" &> /dev/null || { display_message "$cmd is required but not installed." "dialog" "error"; return 1; }
    done
    download_tcpser && extract_tcpser && compile_tcpser && install_tcpser_binary && setup_tcpser_service && { display_message "tcpser installation complete! Use 'systemctl start tcpser.service' to start." "dialog"; rm -f "/tmp/tcpser-${LATEST_RELEASE}.tar.gz"; }
}

# Function to remove tcpser
function remove_tcpser {
    [ "$ROOT" != "true" ] && { display_message "Root access required." "dialog" "error"; return 1; }
    [ ! -f "$TCPSER_BIN" ] && { display_message "tcpser binary not found." "dialog" "error"; return 1; }
    display_message "Removing tcpser..." "dialog" "info"
    sudo systemctl stop tcpser.service 2>/dev/null
    sudo systemctl disable tcpser.service 2>/dev/null
    sudo rm -f "/etc/systemd/system/tcpser.service" "$TCPSER_BIN" "$INSTALL_LOCATION/src/tcpser" -r
    sudo systemctl daemon-reload
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
    sudo mkdir -p "$SRC_DIR" || { display_message "Failed to create directory ${SRC_DIR}" "dialog" "error"; return 1; }
    sudo tar -xzf "$ARCHIVE_FILE" -C "$SRC_DIR" --strip-components=1 || { display_message "Failed to extract tcpser" "dialog" "error"; return 1; }
    display_message "tcpser extracted successfully to ${SRC_DIR}." "dialog" "success"
}

# Function to compile tcpser
function compile_tcpser {
    SRC_DIR="$INSTALL_LOCATION/src/tcpser"
    [ ! -d "$SRC_DIR" ] && { display_message "Source directory ${SRC_DIR} not found. Please extract tcpser first." "dialog" "error"; return 1; }
    display_message "Compiling tcpser in ${SRC_DIR}..." "dialog" "info"
    cd "$SRC_DIR" || { display_message "Cannot change to ${SRC_DIR}" "dialog" "error"; return 1; }
    sudo make || { display_message "Compilation failed. Check dependencies (e.g., build-essential)." "dialog" "error"; return 1; }
    display_message "tcpser compiled successfully." "dialog" "success"
}

# Function to install tcpser binary
function install_tcpser_binary {
    SRC_DIR="$INSTALL_LOCATION/src/tcpser"
    BIN_DIR="$INSTALL_LOCATION/bin"
    [ ! -f "$SRC_DIR/tcpser" ] && { display_message "tcpser binary not found in ${SRC_DIR}. Please compile it first." "dialog" "error"; return 1; }
    display_message "Installing tcpser binary to ${BIN_DIR}..." "dialog" "info"
    sudo install -m 755 "$SRC_DIR/tcpser" "$BIN_DIR/tcpser" || { display_message "Failed to install tcpser binary" "dialog" "error"; return 1; }
    display_message "tcpser binary installed successfully to ${BIN_DIR}." "dialog" "success"
}

# Function to setup tcpser systemd service
function setup_tcpser_service {
    SERVICE_DIR="/etc/systemd/system"
    SERVICE_FILE="$SERVICE_DIR/tcpser.service"
    display_message "Creating tcpser systemd service..." "dialog" "info"
    [ ! -f "$BIN_DIR/tcpser" ] && { display_message "tcpser binary not found. Please install it first." "dialog" "error"; return 1; }
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
    run_with_sudo write_file "$SERVICE_FILE" service_lines[@]
    [ $? -ne 0 ] && { display_message "Failed to create service file" "dialog" "error"; return 1; }

    # Reload systemd and enable the service
    run_with_sudo systemctl daemon-reload || { display_message "Failed to reload systemd daemon" "dialog" "error"; return 1; }
    run_with_sudo systemctl enable tcpser.service || { display_message "Failed to enable tcpser service" "dialog" "error"; return 1; }
    display_message "tcpser service setup successfully." "dialog" "success"
}

# Function to view tcpser status
function view_tcpser_status {
    [ ! -f "$TCPSER_BIN" ] && { display_message "tcpser binary not found." "dialog" "error"; return 1; }
    STATUS=$(systemctl is-active tcpser.service)
    [ "$STATUS" = "active" ] && display_message "tcpser is running." "dialog" "info" || display_message "tcpser is not running." "dialog" "error"
}

# Function to view tcpser help
function view_tcpser_help {
    [ ! -f "$TCPSER_BIN" ] && { display_message "tcpser binary not found." "dialog" "error"; return 1; }
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

# Function to install Commodebian (ensures dialog, wget, and commodebian.sh are installed)
function install_commodebian {
    display_message "Setting up Commodebian..." $display_output "info"

    # Ensure the script is run with root privileges
    if [ "$ROOT" != "true" ]; then
        display_message "Commodebian must be run as root or with sudo." $display_output "error"
        exit 1
    fi

    # Install or update the script in the target location
    if [ ! -f "$INSTALL_LOCATION/bin/commodebian.sh" ]; then
        display_message "Commodebian is not installed. Installing..." $display_output "info"
        cp "$0" "$INSTALL_LOCATION/bin/commodebian.sh" || {
            display_message "Failed to copy script to $INSTALL_LOCATION/bin. Check your permissions."  $display_output "error"
            exit 1
        }
        chmod +x "$INSTALL_LOCATION/bin/commodebian.sh"
        display_message "Commodebian installed successfully." $display_output "success"
    else
        # todo: check if the script is up to date
        #       do a better check than diff
        #       if not, prompt to update
        if ! diff "$0" "$INSTALL_LOCATION/bin/commodebian.sh" > /dev/null; then
            display_message "Commodebian is outdated. Updating..." $display_output "info"

            backup_file "$INSTALL_LOCATION/bin/commodebian.sh" || {
                display_message "Failed to backup the existing script." $display_output "error"
                exit 1
            }
            cp "$0" "$INSTALL_LOCATION/bin/commodebian.sh" || {
                display_message "Failed to copy the updated script." $display_output "error"
                exit 1
            }
            chmod +x "$INSTALL_LOCATION/bin/commodebian.sh"
            display_message "Commodebian updated successfully." $display_output "success"
        else
            display_message "Commodebian is already up to date." $display_output "info"
        fi
    fi

    # validate user exists
    if ! id "$USER_NAME" &> /dev/null; then
        # Prompt to create the user
        display_message "User '$USER_NAME' does not exist. Create $USER_NAME now?" $display_output "yesno"
        if [ $? -eq 0 ]; then
            useradd -m "$USER_NAME" || {
                display_message "Failed to create user '$USER_NAME'." $display_output "error"
                exit 1
            }
            display_message "User '$USER_NAME' created successfully." $display_output "success"
        else
            display_message "User '$USER_NAME' does must be created to continue." $display_output "error"
            exit 1
        fi
    fi

    # prompt if user would like to enable autologin
    display_message "Would you like to enable autologin for user '$USER_NAME'?" $display_output "yesno"
    if [ $? -eq 0 ]; then
        enable_user_autologin
        if [ $? -ne 0 ]; then
            display_message "Failed to enable autologin." $display_output "error"
        fi
    fi

    # prompt if user would like to enable autostart
    display_message "Would you like to have Commodebian autostart?" $display_output "yesno"
    if [ $? -eq 0 ]; then
        install_autostart
        if [ $? -ne 0 ]; then
            display_message "Failed to enable autostart." $display_output "error"
        fi
    fi
    
    apt update -qq > /dev/null
    # if update fails exit
    if [ $? -ne 0 ]; then 
        display_message "Failed to update package lists. Check your network connection." $display_output "error"
        exit 1
    fi

    # check if sudo is installed
    if ! command -v sudo &> /dev/null; then
        display_message "sudo is not installed. Installing..." $display_output "info"
        apt install -y sudo -qq < /dev/null > /dev/null || {
            display_message "Failed to install sudo. Check your package manager or network connection." $display_output "error"
            exit 1
        }
        # Add user to sudo group
        display_message "Adding user '$USER_NAME' to sudo group..." $display_output "info"
        usermod -aG sudo $USER_NAME || {
            display_message "Failed to add user to sudo group." $display_output "error"
            exit 1
        }
        # Modify sudoers file to allow NOPASSWD for sudo group
        display_message "Configuring sudoers file to allow passwordless sudo for sudo group..." $display_output "info"
        echo "%sudo   ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/sudo_nopasswd
        # Set proper permissions on the sudoers file
        chmod 440 /etc/sudoers.d/sudo_nopasswd

        # Prompt for reboot
        read -p "Installation complete. The system needs to reboot for changes to take effect. Do you want to reboot now? (y/n): " REBOOT
        if [[ "$REBOOT" == "y" || "$REBOOT" == "Y" ]]; then
            display_message "Rebooting system..." $display_output "info"
            reboot
        else
            display_message "Please reboot the system manually for changes to take effect." $display_output "info"
        fi
    else
        display_message "sudo is already installed." $display_output "info"
    fi

    # Install required packages if missing
    for pkg in dialog wget unzip; do
        if ! command -v "$pkg" &> /dev/null; then
            display_message "$pkg is not installed. Installing..." $display_output "info"
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" -qq < /dev/null > /dev/null || {
                echdisplay_messageo "Failed to install $pkg. Check your package manager or network connection." $display_output "error"
                exit 1
            }
        else
            display_message "$pkg is already installed." $display_output "info"
        fi
    done

    display_message "Commodebian setup complete." $display_output "success"
}

# Function to setup Commodebian
function setup_commodebian {
    # check if prerequisites are installed
    check_script_prerequisites
    install_commodebian
    create_config
}

# Function to check if Commodebian is setup
function check_commodebian_setup {
    # check if installed first (also checks prerequisites)
    check_script_installation

    # check config file
    check_config

    # check if user autologin is enabled
    check_user_autologin
    # check if autostart is enabled
    check_autostart
    
    # check tcpser is configured
    check_tcpser
    # check if tcpser is running
    check_tcpser_running

    # check if emulator is installed
    check_emulator
    # check if emulator is configured
    check_emulator_config
    # check if emulator is running
    check_emulator_running
}

# Function to edit options
function edit_emulator_options {
    check_config
    # Load the config file
    dialog --colors --editbox "$COMMODEBIAN_CONF" 20 80

    # Check if the user pressed Cancel or entered an empty input
    if [ $? -eq 0 ]; then
        # If user modified and pressed OK, update OPTS
        OPTS="$new_options"
        dialog --msgbox "Options updated successfully!" 6 50
    else
        # If the user pressed Cancel, notify them
        dialog --msgbox "No changes were made." 6 50
    fi
}

# Function to display the about menu
function show_change_emulator_menu {
    
    # Check if the config file exists
    if ! [ -f $COMMODEBIAN_CONF ]; then
        display_message "Could not find config file." "dialog" "error"
        return 1
    fi
    # Load the config file
    source $COMMODEBIAN_CONF
    # check if file loaded correctly
    if [ $? -ne 0 ]; then
        display_message "Could not load config file." "dialog" "error"
        return 1
    fi

    HEIGHT=34
    WIDTH=90
    CHOICE_HEIGHT=35
    TITLE="CHOOSE EMULATOR TO RUN AT BOOT"
    MENU="Use arrow keys to move through options"

    OPTIONS=(
        1  "  COMMODORE 64"
        2  "  COMMODORE 64 DTV"
        3  "  COMMODORE 64 SC"
        4  "  COMMODORE 64 WITH CMD SUPER CPU"
        5  "  COMMODORE 128"
        6  "  COMMODORE 128 (80col)"
        7  "  COMMODORE CBM-II"
        8  "  COMMODORE CBM-5"
        9  "  COMMODORE VIC 20"
        10 "  COMMODORE PLUS/4"
        11 "  COMMODORE PET"
    )

    # Remove an option if check_ssh returns true
    if check_ssh; then
        OPTIONS=("${OPTIONS[@]/b  \"  START COMMODORE EMULATOR\"/}")
    fi

    while :
        do
            CHOICE=$(dialog --clear \
                        --backtitle "$BACKTITLE" \
                        --title "$TITLE" \
                        --menu "$MENU" \
                        $HEIGHT $WIDTH $CHOICE_HEIGHT \
                        "${OPTIONS[@]}" \
                        2>&1 >/dev/tty || true)
        clear
        case $CHOICE in
            1) change_config "EMU" "$INSTALL_LOCATION/bin/x64" ;;
            2) change_config "EMU" "$INSTALL_LOCATION/bin/x64dtv" ;;
            3) change_config "EMU" "$INSTALL_LOCATION/bin/x64sc" ;;
            4) change_config "EMU" "$INSTALL_LOCATION/bin/x64sc" ;;
            5) change_config "EMU" "$INSTALL_LOCATION/bin/x128" ;;
            6) change_config "EMU" "$INSTALL_LOCATION/bin/x128"; change_config "OPTS" "-sdl2 -80col" ;;
            7) change_config "EMU" "$INSTALL_LOCATION/bin/xcbm2" ;;
            8) change_config "EMU" "$INSTALL_LOCATION/bin/xcbm5x0" ;;
            9) change_config "EMU" "$INSTALL_LOCATION/bin/xvic" ;;
            10) change_config "EMU" "$INSTALL_LOCATION/bin/xplus4" ;;
            11) change_config "EMU" "$INSTALL_LOCATION/bin/xpet" ;;
            *) clear; show_main_menu; exit 0 ;;
        esac
    done
}

# Function to display the change disk menu
function show_change_disk_menu {
    check_config
    # Load the config file
    source $COMMODEBIAN_CONF

    HEIGHT=34
    WIDTH=90
    CHOICE_HEIGHT=35
    TITLE="CHOOSE DISK TO RUN AT BOOT"
    MENU="Use arrow keys to move through options"

    # Find all disk files in the d64 directory
    DISK_DIR="$INSTALL_LOCATION/share/vice/C64/d64/"
    OPTIONS=(1 "NONE")
    if [ -d "$DISK_DIR" ]; then
        DISK_FILES=$(find "$DISK_DIR" -type f -name "*.d64" | sort)
        INDEX=2
        for DISK in $DISK_FILES; do
            DISK_NAME=$(basename "$DISK")
            OPTIONS+=("$INDEX" "  $DISK_NAME")
            ((INDEX++))
        done
    else
        display_message "Disk directory not found." "dialog" "error"
        return 1
    fi

    while :
        do
            CHOICE=$(dialog --clear \
                        --backtitle "$BACKTITLE" \
                        --title "$TITLE" \
                        --menu "$MENU" \
                        $HEIGHT $WIDTH $CHOICE_HEIGHT \
                        "${OPTIONS[@]}" \
                        2>&1 >/dev/tty || true)
        clear
        case $CHOICE in
            1) change_config "DISK" "" ;;
            *)
                if [ -z "$CHOICE" ]; then
                    clear
                    show_main_menu
                    exit 0
                fi
                SELECTED_DISK=$(echo "$DISK_FILES" | sed -n "$((CHOICE - 1))p")
                change_config "DISK" "$SELECTED_DISK"
                ;;
        esac
    done
}

# Function to display the change cartridge menu
function show_change_cartridge_menu {
    check_config
    # Load the config file
    source $COMMODEBIAN_CONF

    HEIGHT=34
    WIDTH=90
    CHOICE_HEIGHT=35
    TITLE="CHOOSE CARTRIDGE TO RUN AT BOOT"
    MENU="Use arrow keys to move through options"

    # Find all cartridge files in the install location
    CART_DIR="$INSTALL_LOCATION/share/vice/C64/carts/"
    OPTIONS=(1 "NONE")
    if [ -d "$CART_DIR" ]; then
        CART_FILES=$(find "$CART_DIR" -type f -name "*.crt" | sort)
        INDEX=2
        for CART in $CART_FILES; do
            CART_NAME=$(basename "$CART")
            OPTIONS+=("$INDEX" "  $CART_NAME")
            ((INDEX++))
        done
    else
        display_message "Cartridge directory not found." "dialog" "error"
        return 1
    fi

    while :
        do
            CHOICE=$(dialog --clear \
                        --backtitle "$BACKTITLE" \
                        --title "$TITLE" \
                        --menu "$MENU" \
                        $HEIGHT $WIDTH $CHOICE_HEIGHT \
                        "${OPTIONS[@]}" \
                        2>&1 >/dev/tty || true)
        clear
        case $CHOICE in
            1) change_config "CRT" "" ;;
            *)
                if [ -z "$CHOICE" ]; then
                    clear
                    show_main_menu
                    exit 0
                fi
                SELECTED_CART=$(echo "$CART_FILES" | sed -n "$((CHOICE - 1))p")
                change_config "CRT" "$SELECTED_CART"
                ;;
        esac
    done
}

# Function to display the tcpser menu
function show_tcpser_menu {
    HEIGHT=34
    WIDTH=90
    CHOICE_HEIGHT=35
    TITLE="TCPSER MENU"
    MENU="Use arrow keys to move through options"

    if $ROOT; then
        OPTIONS=(
            i  "  INSTALL TCPSER"
            r  "  REMOVE TCPSER"
            "" ""
            1  "  START TCPSER"
            2  "  STOP TCPSER"
            "" ""
            3 "  EDIT TCPSER CONFIG"
            4 "  VIEW TCPSER LOG"
            5 "  VIEW TCPSER STATUS"
            6 "  VIEW TCPSER HELP"
            
        )
    else
        OPTIONS=(
            1  "  START TCPSER"
            2  "  STOP TCPSER"
            "" ""
            4 "  VIEW TCPSER LOG"
            5 "  VIEW TCPSER STATUS"
            6 "  VIEW TCPSER HELP"

        )
    fi

    while :
        do
            CHOICE=$(dialog --clear \
                        --backtitle "$BACKTITLE" \
                        --title "$TITLE" \
                        --menu "$MENU" \
                        $HEIGHT $WIDTH $CHOICE_HEIGHT \
                        "${OPTIONS[@]}" \
                        2>&1 >/dev/tty || true)
        clear
        case $CHOICE in
            1)  start_tcpser ;;
            2)  stop_tcpser ;;
            i)  install_tcpser ;;
            r)  remove_tcpser ;;
            3)  edit_tcpser_config ;;
            4)  view_tcpser_log ;;
            5)  view_tcpser_status ;;
            6)  view_tcpser_help ;;
            *)  clear; show_main_menu; exit 0 ;;
        esac
    done
}

# Function to display the install menu
function show_install_menu {
    # check if prerequisites are installed
    check_script_prerequisites

    HEIGHT=20
    WIDTH=50
    CHOICE_HEIGHT=14
    TITLE="Commodebian Installer Menu"
    MENU="Use arrow keys to move through options"
    
    if [ "$ROOT" = "true" ]; then
        OPTIONS=(
            1  "  Check for Updates  "
            2  "  Install dependencies  "
            3  "  Edit dependencies  "
            "" ""
            4  "  Download Vice  "
            5  "  Extract Vice  "
            6  "  Build Vice  "
            7  "  Install Vice  "
            "" ""
            i  "  Install autostart  "
            u  "  Remove autostart  "
        )
    else
        OPTIONS=(
            ""  "  This will setup the user profile"
            ""  "  to start the emulator on boot.   " 
            ""  ""
            i   "  Install autostart  "
            u   "  Remove autostart  "
            ""  ""
            "e" "  Edit user profile  "
            ""  ""
            ""  "  Run with sudo for more options  "
        )
    fi
    while :
        do
            CHOICE=$(dialog --clear \
                        --backtitle "$BACKTITLE" \
                        --title "$TITLE" \
                        --menu "$MENU" \
                        $HEIGHT $WIDTH $CHOICE_HEIGHT \
                        "${OPTIONS[@]}" \
                        2>&1 >/dev/tty)
        clear
        case $CHOICE in
            1) self_update ;;
            2) install_dependencies ;;
            3) edit_dependencies ;;
            4) download_vice ;;
            5) extract_vice ;;
            6) build_vice ;;
            7) install_vice ;;
            e) edit_profile ;;
            i) install_autostart ;;
            u) remove_autostart ;;
            *) show_main_menu ;;
        esac
    done
}

# Function to display the main menu
function show_main_menu {
    # check if prerequisites are installed
    check_script_prerequisites
    # check if commodebian is installed
    check_script_installation
    # check if commodebian is setup
    check_commodebian_setup
    # check if commodebian is up to date
    check_script_version    
    # load config
    load_config

    wait_for_keypress
    
    HEIGHT=30
    WIDTH=60
    CHOICE_HEIGHT=35
    TITLE="Commodebian Main Menu"
    MENU="Use arrow keys to move through options"

    if check_ssh; then
        OPTIONS=(
                a  "  ABOUT COMMODEBIAN"
                b  "  START COMMODORE EMULATOR"
        )
    else
        OPTIONS=(
                a  "  ABOUT COMMODEBIAN"
        )
    fi

    STATIC_OPTIONS=(
        ""  ""
        ""  "- Emulator options -" 
        ""  ""
        1   " CHOOSE EMULATOR TO RUN AT BOOT"
        2   " CHOOSE DISK"
        3   " CHOOSE CARTRIDGE "
        4   " EDIT EMULATOR OPTIONS"
        ""  ""
        ""  "- OTHER OPTIONS -"
        ""  ""
        i   "  INSTALLATION MENU"
        m   "  TCPSER Menu"
        ""  ""
        ""  "- SYSTEM OPTIONS -"
        ""  ""
        r   "  REBOOT"
        s   "  SHUTDOWN"
        ""  ""
        x   "  Exit to command Line"
    )

    OPTIONS=("${OPTIONS[@]}" "${STATIC_OPTIONS[@]}")

    # Remove an option if check_ssh returns true
    if check_ssh; then
        OPTIONS=("${OPTIONS[@]/b  \"  START COMMODORE EMULATOR\"/}")
    fi

    while :
        do
            CHOICE=$(dialog --clear \
                        --backtitle "$BACKTITLE" \
                        --title "$TITLE" \
                        --no-cancel \
                        --menu "$MENU" \
                        $HEIGHT $WIDTH $CHOICE_HEIGHT \
                        "${OPTIONS[@]}" \
                        2>&1 >/dev/tty || true)
        clear
        case $CHOICE in
            a) show_about_menu ;;
            b) boot_emu ;;
            1) show_change_emulator_menu ;;
            2) show_change_disk_menu ;;
            3) show_change_cartridge_menu ;;
            4) edit_emulator_options ;;
            i) show_install_menu ;;
            m) show_tcpser_menu ;;
            r) reboot_function ;;
            s) shutdown_function ;;
            x) clear; exit 0 ;;
        esac
    done
}

### Main script starts here ###

# Check for modifier keywords
case "$1" in
    boot)
        # this is to run the emulator at boot
        check_ssh
        boot_emu
        exit 0
        ;;
    menu)
        # this is to configure the emulator to run at boot
        show_main_menu
        exit 0
        ;;
    install)
        # this is to install the requirements for the script
        run_with_sudo install_commodebian
        exit 0
        ;;
    setup)
        # this is to setup the requirements for the vice emulator
        display_message "Setting up Commodebian..." $display_output "info"
        run_with_sudo setup_commodebian
        exit 0
        ;;
    update)
        # this is to update the script
        run_with_sudo self_update
        if [ $? -eq 0 ]; then
            show_main_menu
        else
            exit 1
        fi
        exit 0
        ;;
    --help)
        # Display help message
        echo "Commodebian - A menu system for the Commodore Vice Emulator"
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
        exit 0
        ;;
    --version)
        # Display version
        echo "You are running Commodebian version $VERSION"
        show_script_online_version
        exit 0
        ;;
    "")
        # No option provided, continue with the script
        ;;
    *)
        # Invalid option, show help
        echo "Invalid option: $1"
        echo "Use --help to see the available options."
        exit 1
        ;;
esac

### script was run with no options ###

# make sure commodebian is installed correctly
check_script_prerequisites

# if installed change messages do dialog
set_message_display

# show welcome message
show_welcome

# check if commodebian is installed
check_script_installation
if ! [ $? -eq 0 ]; then
    # script not installed
    display_message "Commodebian not setup. Please run the script with the sudo and the install option." $display_output "error"
else
    # script installed
    # check if commodebian has a config file
    if ! [ -f $COMMODEBIAN_CONF ]; then
        show_not_setup
    fi
    if [ "$ROOT" = "true" ]; then
        show_install_menu
    else
        show_main_menu
    fi
fi

# show exit message
show_exit