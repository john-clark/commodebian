#!/bin/bash
# filepath: commodebian/functions/system.sh
# Configuration-related functions

# Make sure this was called from the main script
if [[ -z "$COMMODORE" ]]; then
    echo "This script is not meant to be run directly."
    return 1
fi

# Function to boot the emulator
function boot_emu {

    display_message "Running emulator..." $display_output "info"
    # check if running in terminal
    if ! check_ssh; then
        display_message "This option is only available from the console." $display_output "error"
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
            safe_exit 1
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
                    safe_exit 1
                fi
            fi
        fi
    fi
}

# Function to install prerequisites
function install_script_prerequisites {

    run_with_sudo apt update -qq && run_with_sudo apt install -y dialog wget sudo
    # were there any errors?
    if [ $? -ne 0 ]; then
        display_message "Failed to install prerequisites." "console" "error"
        return 1
    fi

    # Verify installation of prerequisites directly to not get stuck in a loop
    for cmd in dialog wget sudo; do
        if ! command -v "$cmd" &> /dev/null; then
            display_message "Failed to install prerequisite: $cmd. Please check your package manager or network connection." "console" "error"
            return 1
        fi
    done

    # If the function reaches this point, it means prerequisites were installed successfully
    display_message "Prerequisites installed successfully." "console" "success"
    return 0
}

# Function to check if prerequisites are installed
function check_script_prerequisites {

    # Hard dependencies for the script either have them or exit
    local missing=()

    # Check for each required command
    for cmd in dialog wget sudo; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    # Check if any prerequisites are missing
    if [ ${#missing[@]} -ne 0 ]; then
        display_message "The following prerequisites are missing: ${missing[*]}\n\nWould you like to install them now?" "console" "yesno"
        if [ $? -eq 0 ]; then
            # If user chooses to install missing prerequisites
            display_message "Installing missing prerequisites: ${missing[*]}..." "console" "info"
            # Call the function to install prerequisites
            install_script_prerequisites
            # exit loop if failure
            if [ $? -ne 0 ]; then
                display_message "Failed to install the missing prerequisites: ${missing[*]}. Please check your network connection or package manager." "console" "error"
                return 1
            fi
        else
            # If user chooses not to install, exit with error
            display_message "Please install the missing prerequisites and run the script again." "console" "error"
            safe_exit 1
        fi
    fi
}

# Function to check Commodebian version
function check_script_version {

    #wget the latest version and check version number
    LATEST_VERSION=$(wget -qO- $ONLINE_URL | grep -m1 -o 'VERSION=[0-9]\+\.[0-9]\+' | cut -d= -f2)
    #LATEST_VERSION=$(curl -s $ONLINE_URL | grep 'version=' | awk -F'=' '{print $2}')
    if ! [ "$VERSION" = "$LATEST_VERSION" ]; then
        # show current version and other version
        display_message "Commodebian is outdated. \n\nThis version: $VERSION\nLatest version: $LATEST_VERSION\n\nWould you like to update? " $display_output "yesno"
        if [ $? -eq 0 ]; then
            run_with_sudo self_update
        fi
    fi
}

# Function to check if the script is being run from $INSTALL_LOCATION/bin
function check_script_location {

    if ! [ "$(realpath "$0")" = "$INSTALL_LOCATION/bin/commodebian.sh" ]; then
        display_message "This script should be run from $INSTALL_LOCATION/bin/commodebian.sh" $display_output "error"
        # wait for keypress
        read -n 1 -s -r -p "Press any key to continue..."
        safe_exit 1
    fi
}

# Function to check if Commodebian is installed
function check_script_installation {

    # check prerequisites if install fails return 1
    if ! check_script_prerequisites; then
        display_message "Failed to check prerequisites. Please ensure you have the required packages installed." $display_output "error"
        return 1
    fi

    declare -A required_paths=(
        # Define required folders and files
        ["$INSTALL_LOCATION/bin"]="commodebian.sh"
        ["$INSTALL_LOCATION/lib/commodebian"]="config.sh menu.sh system.sh tcpser.sh utils.sh vice.sh messages.sh"
    )

    for folder in "${!required_paths[@]}"; do
        if ! [ -d "$folder" ]; then
            display_message "Missing folder: $folder. Would you like to reinstall Commodebian?" $display_output "yesno"
            if [ $? -eq 0 ]; then
                run_with_sudo "$SCRIPT_DIR/commodebian.sh" install
            else
                display_message "Missing folder: $folder. Installation is incomplete." $display_output "error"
                return 1
            fi
        fi

        for file in ${required_paths[$folder]}; do
            if ! [ -f "$folder/$file" ]; then
                display_message "Missing file: $file in $folder. Would you like to reinstall Commodebian?" $display_output "yesno"
                if [ $? -eq 0 ]; then
                    run_with_sudo "$SCRIPT_DIR/commodebian.sh" install
                else
                    display_message "Missing file: $file. Installation is incomplete." $display_output "error"
                    return 1
                fi
            fi
        done
    done    

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
}

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

# Function to perform self-update
function self_update {

    display_message "Updating Commodebian..." $display_output "info"

    # check if running as root
    [ "$ROOT" != "true" ] && { display_message "This option must be run as root or with sudo." $display_output "error"; return 1; }
    
    #check if prerequisites are installed
    check_script_prerequisites
    
    #check if commodebian is installed
    check_script_installation
    if [ $? -ne 0 ]; then
        display_message "Commodebian is not installed correctly. Cannot perform update." $display_output "error"
        return 1
    fi
    
    # Define URLs and paths for the script and resources
    SCRIPT_URL="$ONLINE_URL/commodebian.sh"
    RESOURCES_URL="$ONLINE_URL/resources.tar.gz"
    SCRIPT_PATH="$(realpath "$0")"
    TMP_SCRIPT="/tmp/updated_script.sh"
    TMP_RESOURCES="/tmp/resources.tar.gz"
    INSTALL_DIR="$INSTALL_LOCATION"

    # Cleanup temporary files
    cleanup() { rm -f "$TMP_SCRIPT" "$TMP_RESOURCES"; }
    trap cleanup EXIT

    # Check if script is already installed
    if [ "$SCRIPT_PATH" != "$INSTALL_LOCATION/bin/commodebian.sh" ]; then
        display_message "\nThis seems to be a first run.\nInstalling to $INSTALL_LOCATION/bin/commodebain.sh now." $display_output "info"
        cp "$SCRIPT_PATH" "$INSTALL_LOCATION/bin/commodebain.sh" 2>/dev/null
        if ! [ $? -eq 0 ]; then
            display_message "Could not copy script to $INSTALL_LOCATION/bin/commodebain.sh" $display_output "error"
            exit 1
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
        exit 1
    fi

    # Verify downloaded file is a valid bash script
    if ! head -n 1 "$TMP_SCRIPT" | grep -q '^#!/bin/bash'; then
        display_message "Downloaded file is not a valid script" $display_output "error"
        exit 1
    fi

    # Extract new version
    REMOTE_VERSION=$(grep -m1 -o 'VERSION=[0-9]\+\.[0-9]\+' "$TMP_SCRIPT" | cut -d= -f2)
    REMOTE_VERSION="${REMOTE_VERSION:-unknown}"

    # Simple version comparison (could be enhanced)
    if [ "$REMOTE_VERSION" != "unknown" ] && [ "$CURRENT_VERSION" = "$REMOTE_VERSION" ]; then
        display_message "Script is already up to date (version $CURRENT_VERSION)" $display_output "info"
        exit 0
    fi

    # Define backup script path
    BACKUP_SCRIPT="${SCRIPT_PATH}.bak"

    # Backup current script
    if ! cp "$SCRIPT_PATH" "$BACKUP_SCRIPT" 2>/dev/null; then
        display_message "Could not create backup" $display_output "error"
        exit 1
    fi

    # Replace script
    dialog --infobox "Installing update..." 3 50
    if cp "$TMP_SCRIPT" "$SCRIPT_PATH" && chmod +x "$SCRIPT_PATH"; then
        display_message "Update to version ${REMOTE_VERSION} successful!\n\nBackup saved as: $BACKUP_SCRIPT\n\nRestarting..." $display_output "success"
        exec "$SCRIPT_PATH" "$@"
    else
        cp "$BACKUP_SCRIPT" "$SCRIPT_PATH" 2>/dev/null
        display_message "Update failed, restored original script" $display_output "error"
        exit 1
    fi
}

# Function to reboot the system
function reboot_function {

    tput civis
    clear
    # check if installed
    if check_script_installation; then
        run_with_sudo shutdown -r now
        safe_exit 0
    else
        display_message "\nERROR can't shutdown not installed correctly.\n\nPlease run this script as root or with sudo." $display_output "error"
        tput cvvis
        safe_exit 1
    fi
}

# Function to shutdown the system
function shutdown_function {

    tput civis
    clear
    if check_script_installation; then
        run_with_sudo shutdown -h now
        safe_exit 0
    else
        display_message "\nERROR can't shutdown not installed correctly.\n\nPlease run this script as root or with sudo." $display_output "error"
        tput cvvis
        safe_exit 1
    fi
}

# Function to install Commodebian (ensures dialog, wget, and commodebian.sh are installed)
function install_commodebian {

    display_message "Setting up Commodebian..." $display_output "info"

    # Install or update the script in the target location
    if [ ! -f "$INSTALL_LOCATION/bin/commodebian.sh" ]; then
        display_message "Commodebian is not installed. Installing..." $display_output "info"
        run_with_sudo cp "$0" "$INSTALL_LOCATION/bin/commodebian.sh" || {
            display_message "Failed to copy script to $INSTALL_LOCATION/bin. Check your permissions."  $display_output "error"
            safe_exit 1
        }
        run_with_sudo chmod +x "$INSTALL_LOCATION/bin/commodebian.sh"
        display_message "Commodebian installed successfully." $display_output "success"
    else
        # todo: check if the script is up to date
        #       do a better check than diff
        #       if not, prompt to update
        if ! diff "$0" "$INSTALL_LOCATION/bin/commodebian.sh" > /dev/null; then
            display_message "Commodebian is outdated. Updating..." $display_output "info"

            backup_file "$INSTALL_LOCATION/bin/commodebian.sh" || {
                display_message "Failed to backup the existing script." $display_output "error"
                safe_exit 1
            }
            run_with_sudo cp "$0" "$INSTALL_LOCATION/bin/commodebian.sh" || {
                display_message "Failed to copy the updated script." $display_output "error"
                safe_exit 1
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
            run_with_sudo useradd -m "$USER_NAME" || {
                display_message "Failed to create user '$USER_NAME'." $display_output "error"
                safe_exit 1
            }
            display_message "User '$USER_NAME' created successfully." $display_output "success"
        else
            display_message "User '$USER_NAME' does must be created to continue." $display_output "error"
            safe_exit 1
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
    
    run_with_sudo apt update -qq > /dev/null
    # if update fails exit
    if [ $? -ne 0 ]; then 
        display_message "Failed to update package lists. Check your network connection." $display_output "error"
        safe_exit 1
    fi

    # check if sudo is installed
    if ! command -v sudo &> /dev/null; then
        display_message "sudo is not installed. Installing..." $display_output "info"
        run_with_sudo apt install -y sudo -qq < /dev/null > /dev/null || {
            display_message "Failed to install sudo. Check your package manager or network connection." $display_output "error"
            safe_exit 1
        }
        # Add user to sudo group
        display_message "Adding user '$USER_NAME' to sudo group..." $display_output "info"
        run_with_sudo usermod -aG sudo $USER_NAME || {
            display_message "Failed to add user to sudo group." $display_output "error"
            safe_exit 1
        }
        # Modify sudoers file to allow NOPASSWD for sudo group
        display_message "Configuring sudoers file to allow passwordless sudo for sudo group..." $display_output "info"
        run_with_sudo echo "%sudo   ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/sudo_nopasswd
        # Set proper permissions on the sudoers file
        run_with_sudo chmod 440 /etc/sudoers.d/sudo_nopasswd

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
                safe_exit 1
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
    # check if emulator is installed
    check_vice

    # check if user autologin is enabled
    check_user_autologin
    # check if autostart is enabled
    check_autostart
    
    # check tcpser is configured
    check_tcpser
    # check if tcpser is running
    check_tcpser_running

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
