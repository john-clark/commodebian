#!/bin/bash
#
# Commodebian - A menu system for Commodore Vice Emulator 
# copyright (c) 2025 - John Clark
# https://github.com/john-clark/commodebian/
VERSION=0.3
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

# Function to check if sudo is available and the user has permission
function check_sudo {
    # Check if sudo is installed
    if ! command -v sudo &> /dev/null; then
        echo "Error: 'sudo' is not installed. Please install it and try again."
        return 1
    fi
    # Check if the user has sudo privileges
    if ! sudo -n true 2>/dev/null; then
        echo "Error: You do not have permission to use 'sudo' or a password is required."
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

# Function to change file permissions (#fix this to either use echo or dialog)
function change_file_permissions {
    local file="$1"
    local permissions="$2"

    if [ -z "$file" ] || [ -z "$permissions" ]; then
        echo "Error: File or permissions not specified."
        return 1
    fi

    echo "Changing permissions of $file to $permissions"
    run_with_sudo chmod "$permissions" "$file" || {
        echo "Error: Failed to change permissions for $file"
        return 1
    }

    echo "Permissions changed successfully for $file"
    return 0
}

# Function to check if running in ssh
function check_ssh {
    if [ "$SSH_CONNECTION" ]; then
        # Running in a remote session
        echo "Detected: Remote SSH session. Please run this script from the console or terminal."
        return 1
    fi
}

if check_ssh; then
    # Running in a console
    BACKTITLE="Commodebian $VERSION"
else
    # Running in a terminal
    BACKTITLE="Commodebian $VERSION (TERMINAL MODE)"
fi

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
function show_console_online_version {
    LATEST_VERSION=$(check_online_version)
    echo "The latest version of Commodebian is $LATEST_VERSION"
}


# Function to check if Commodebian is installed
function check_commodebian_install {
    # check if prerequisites are installed
    check_prerequisites
    # check if commodebian.sh is in the install location
    if ! [ -f "$INSTALL_LOCATION/bin/commodebian.sh" ]; then
        echo "Commodebian is not installed. Please run the install script."
        return 1
    fi
    #test if commodebian.sh is in the path
    if ! command -v commodebian.sh &> /dev/null; then
        echo "Commodebian is not in path. Please fix your system to include /usr/local/bin."
        return 1
    fi
    #check to see if script was run as /usr/local/bin/commodebian.sh
    if ! [ "$(realpath "$0")" = "$INSTALL_LOCATION/bin/commodebian.sh" ]; then
        echo "Commodebian is already installed. Just run commodebian.sh, it is in your path."
        return 1
    fi
    #check version    
    if ! [ "$VERSION" = "$(grep -m1 -o 'VERSION=[0-9]\+\.[0-9]\+' "$INSTALL_LOCATION/bin/commodebian.sh" | cut -d= -f2)" ]; then
        echo "Commodebian is outdated. Please run the install script."
        return 1
    fi
}

# Function to check Commodebian version
function check_commodebian_version {
    # check if prerequisites are installed
    check_prerequisites
    #wget the latest version and check version number
    LATEST_VERSION=$(wget -qO- $ONLINE_URL | grep -m1 -o 'VERSION=[0-9]\+\.[0-9]\+' | cut -d= -f2)
    #LATEST_VERSION=$(curl -s $ONLINE_URL | grep 'version=' | awk -F'=' '{print $2}')
    if ! [ "$VERSION" = "$LATEST_VERSION" ]; then
        return 1
    fi
}

# Function to check if Commodebian is setup
function check_commodebian_setup {
    # check if prerequisites are installed
    check_prerequisites
    # check if installed first
    check_commodebian_install
    # look for config file
    if ! [ -f "$COMMODEBIAN_CONF" ]; then
        echo "Required file $COMMODEBIAN_CONF not found."
        return 1
    fi
}

# Function to check if the script is being run from $INSTALL_LOCATION/bin
function check_script_location {
    if ! [ "$(realpath "$0")" = "$INSTALL_LOCATION/bin/commodebian.sh" ]; then
        echo "This script must be run from $INSTALL_LOCATION/bin/commodebian.sh"
        exit 1
    fi
}

# Function to check if prerequisites are installed
function check_prerequisites {
    local missing=()
    for cmd in dialog wget sudo; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo "The following prerequisites are missing: ${missing[*]}"
        echo "Run \"commodebian install\" as root to install them."
        exit 1
    fi
}

# Centralized function to check configuration file
function check_config_file {
    # Check if the config file exists
    if [ ! -f "$COMMODEBIAN_CONF" ]; then
        dialog --colors --msgbox "\Z1Error: Configuration file not found at $COMMODEBIAN_CONF.\Zn" 6 50
        return 1
    fi

    # Check if the file is readable
    if [ ! -r "$COMMODEBIAN_CONF" ]; then
        dialog --colors --msgbox "\Z1Error: Configuration file at $COMMODEBIAN_CONF is not readable.\Zn" 6 50
        return 1
    fi

    # Validate the file's syntax without executing it
    if ! bash -n "$COMMODEBIAN_CONF"; then
        dialog --colors --msgbox "\Z1Error: Configuration file at $COMMODEBIAN_CONF contains syntax errors.\Zn" 6 50
        return 1
    fi

    # Optionally source the file to ensure it loads correctly (remove if not needed)
    if ! source "$COMMODEBIAN_CONF"; then
        dialog --colors --msgbox "\Z1Error: Could not load configuration file at $COMMODEBIAN_CONF.\Zn" 6 50
        return 1
    fi

    return 0
}

# Function to change configuration variable
function change_config {
    # Check if the config file exists and is valid
    check_config_file || return 1

    # Ensure the variable name is provided
    if [ -z "$1" ]; then
        dialog --colors --msgbox "\Z1Error: No variable specified.\Zn" 6 50
        return 1
    fi

    # Ensure the value is provided
    if [ -z "$2" ]; then
        dialog --colors --msgbox "\Z1Error: No value specified.\Zn" 6 50
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
        dialog --colors --msgbox "\Z1Error: Directory $config_dir is not writable.\nRun with sudo or fix permissions.\Zn" 8 50
        return 1
    fi

    # Check file permissions explicitly
    if [ ! -w "$COMMODEBIAN_CONF" ]; then
        dialog --colors --msgbox "\Z1Error: Config file $COMMODEBIAN_CONF is not writable.\nCheck permissions.\Zn" 8 50
        return 1
    fi

    # Check if the variable exists and update it
    if grep -q "^$escaped_key=" "$COMMODEBIAN_CONF"; then
        sed -i "s|^$escaped_key=.*|$escaped_key=\"$escaped_value\"|" "$COMMODEBIAN_CONF"
        if [ $? -ne 0 ]; then
            dialog --colors --msgbox "\Z1Error: Failed to update $key in $COMMODEBIAN_CONF.\Zn" 6 50
            return 1
        fi
    else
        # Add the variable if it doesn’t exist
        echo "$escaped_key=\"$escaped_value\"" >> "$COMMODEBIAN_CONF"
        if [ $? -ne 0 ]; then
            dialog --colors --msgbox "\Z1Error: Failed to append $key to $COMMODEBIAN_CONF.\Zn" 6 50
            return 1
        fi
    fi

    # Verify the change (more flexible match)
    if grep -q "^$escaped_key=\"[^\"]*\"$" "$COMMODEBIAN_CONF"; then
        dialog --colors --msgbox "\Z2Configuration updated successfully.\n$key set to \"$value\".\Zn" 8 50
        return 0
    else
        dialog --colors --msgbox "\Z1Error: Could not verify update for $key.\nFile contents:\n$(cat "$COMMODEBIAN_CONF")\Zn" 10 60
        return 1
    fi
}

# Function to install Commodebian (ensures dialog, wget, and commodebian.sh are installed)
function install_commodebian {
    echo "Setting up Commodebian..."

    # Ensure the script is run with root privileges
    if [ "$ROOT" != "true" ]; then
        echo -e "\033[31mError: Commodebian must be run as root or with sudo.\033[0m"
        exit 1
    fi

    # Install or update the script in the target location
    if [ ! -f "$INSTALL_LOCATION/bin/commodebian.sh" ]; then
        echo "Commodebian is not installed. Installing..."
        cp "$0" "$INSTALL_LOCATION/bin/commodebian.sh" || {
            echo "Error: Failed to copy script to $INSTALL_LOCATION/bin. Check your permissions."
            exit 1
        }
        chmod +x "$INSTALL_LOCATION/bin/commodebian.sh"
        echo "Commodebian installed successfully."
    else
        if ! diff "$0" "$INSTALL_LOCATION/bin/commodebian.sh" > /dev/null; then
            echo "Commodebian is outdated. Updating..."
            mv "$INSTALL_LOCATION/bin/commodebian.sh" "$INSTALL_LOCATION/bin/commodebian.sh.bak" || {
                echo "Error: Failed to backup the existing script."
                exit 1
            }
            cp "$0" "$INSTALL_LOCATION/bin/commodebian.sh" || {
                echo "Error: Failed to copy the updated script."
                exit 1
            }
            chmod +x "$INSTALL_LOCATION/bin/commodebian.sh"
            echo "Commodebian updated successfully."
        else
            echo "Commodebian is already up to date."
        fi
    fi

    # validate user exists
    if ! id "$USER_NAME" &> /dev/null; then
        echo "User '$USER_NAME' does not exist. Creating..."
        useradd -m "$USER_NAME" || {
            echo "Error: Failed to create user '$USER_NAME'."
            exit 1
        }
    fi
    
    # next update profile
    if ! [ -f "$PROFILE_FILE" ]; then
        echo "Profile file not found. Creating..."
        touch "$PROFILE_FILE" || {
            echo "Error: Failed to create profile file."
            exit 1
        }
    fi

    # Add the lines to .profile if they don't already exist
    for line in "${PROFILE_AUTOSTART_LINES[@]}"; do
        if ! grep -Fxq "$line" "$PROFILE_FILE"; then
            echo "$line" >> "$PROFILE_FILE"
        fi
    done

    enable_user_autologin


    apt update -qq > /dev/null
    # if update fails exit
    if [ $? -ne 0 ]; then
        echo "Error: Failed to update package lists. Check your network connection."
        exit 1
    fi

    # check if sudo is installed
    if ! command -v sudo &> /dev/null; then
        echo "sudo is not installed. Installing..."
        apt install -y sudo -qq < /dev/null > /dev/null || {
            echo "Error: Failed to install sudo. Check your package manager or network connection."
            exit 1
        }
        # Add user to sudo group
        echo "Adding user '$USER_NAME' to sudo group..."
        usermod -aG sudo $USER_NAME || {
            echo "Error: Failed to add user to sudo group."
            exit 1
        }
        # Modify sudoers file to allow NOPASSWD for sudo group
        echo "Configuring sudoers file to allow passwordless sudo for sudo group..."
        echo "%sudo   ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/sudo_nopasswd
        # Set proper permissions on the sudoers file
        chmod 440 /etc/sudoers.d/sudo_nopasswd

        # Prompt for reboot
        read -p "Installation complete. The system needs to reboot for changes to take effect. Do you want to reboot now? (y/n): " REBOOT
        if [[ "$REBOOT" == "y" || "$REBOOT" == "Y" ]]; then
            echo "Rebooting system..."
            reboot
        else
            echo "Please reboot the system manually for changes to take effect."
        fi
    else
        echo "sudo is already installed."
    fi

    # Install required packages if missing
    for pkg in dialog wget unzip; do
        if ! command -v "$pkg" &> /dev/null; then
            echo "$pkg is not installed. Installing..."
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" -qq < /dev/null > /dev/null || {
                echo "Error: Failed to install $pkg. Check your package manager or network connection."
                exit 1
            }
        else
            echo "$pkg is already installed."
        fi
    done

    echo "Commodebian setup complete."
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
            echo "Error: Failed to create directory $OVERRIDE_DIR."
            exit 1
        fi
    fi

    # Write the autologin override configuration
    cat > "$OVERRIDE_FILE" << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF

    if [ $? -ne 0 ]; then
        echo "Error: Failed to write autologin configuration to $OVERRIDE_FILE."
        exit 1
    fi

    # Reload systemd to apply changes
    systemctl daemon-reload
    if [ $? -ne 0 ]; then
        echo "Error: Failed to reload systemd configuration."
        exit 1
    fi

    # Enable the service (optional, usually enabled by default)
    systemctl enable "$GETTY_SERVICE" 2>/dev/null

    # Inform the user
    echo "Autologin configured for user '$USER' on TTY1."
}

#function to disable user autologin
function disable_user_autologin {
    OVERRIDE_DIR="/etc/systemd/system/$GETTY_SERVICE.d"
    OVERRIDE_FILE="$OVERRIDE_DIR/autologin.conf"
    # move override file to backup in home folder
    mv $OVERRIDE_FILE /home/$USER_NAME/autologin.conf.bak
    # Reload systemd to apply changes
    systemctl daemon-reload
    if [ $? -ne 0 ]; then
        echo "Error: Failed to reload systemd configuration."
        exit 1
    fi
    # Inform the user
    echo "Autologin disabled for user '$USER' on TTY1."
}

# Function to setup Commodebian
function setup_commodebian {
    # check if prerequisites are installed
    check_prerequisites
    install_commodebian
    create_config
}

# Function to check if Commodebian config is installed
function check_config {
    # Check if the configuration file exists
    if ! [ -f "$COMMODEBIAN_CONF" ]; then
        echo "Configuration file not found. Running setup..."
        create_config
    fi
}

# Function to create config file
function create_config {
    # check to see if commodebian is already installed
    check_commodebian_install
    # Check if the config file already exists
    if [ -f $COMMODEBIAN_CONF ]; then
        dialog --colors --msgbox "\Z1Error: Config file already exists.\Zn" 6 50
        # load config file and make sure all variables are there
        if ! bash -n "$COMMODEBIAN_CONF"; then
            dialog --colors --msgbox "\Z1Error: Configuration file contains syntax errors.\Zn" 6 50
            return 1
        fi
        source $COMMODEBIAN_CONF
        # check if file loaded correctly
        if [ $? -ne 0 ]; then
            dialog --colors --msgbox "\Z1Error: Could not load config file.\Zn" 6 50
            return 1
        fi
        # check if version is set
        if ! [ -z "$VERSION" ]; then
            # found version don't need to recreate
        return 0
    fi
        # version not found display error
        dialog --colors --msgbox "\Z1Error: Could not load version from config file.\Zn" 6 50
        return 1
    fi
    # Check if the directory exists
    if ! [ -d "$(dirname $COMMODEBIAN_CONF)" ]; then
        dialog --colors --msgbox "\Z1Error: Configuration directory does not exist.\Zn" 6 50
        return 1
    fi
    # Check if the file can be created
    if ! touch "$COMMODEBIAN_CONF"; then
        dialog --colors --msgbox "\Z1Error: Could not create config file.\Zn" 6 50
        return 1
    fi

    # Write the default values to the config file
    echo "Creating configuration file at $COMMODEBIAN_CONF..."
cat << EOF > $COMMODEBIAN_CONF
#!/bin/bash
#Commodebian Configuration File
#This file is automatically generated by the Commodebian script.
#Do not edit this file directly. Use the Commodebian script to modify it.
VERSION=0.3
#DEFAULT EMULATOR
EMU=$INSTALL_LOCATION/bin/x64
#DEFAULT OPTIONS
OPTS=-sdl2
#DEFAULT ROM
ROM=$INSTALL_LOCATION/share/vice/C64/kernal.rom
#DEFAULT DISK
DISK=$INSTALL_LOCATION/share/vice/C64/blank.d64
#DEFAULT TAPE
TAPE=$INSTALL_LOCATION/share/vice/C64/blank.t64
#DEFAULT CARTRIDGE
CRT=$INSTALL_LOCATION/share/vice/C64/blank.crt
EOF
    [ $? -eq 0 ] && chmod 666 "$COMMODEBIAN_CONF" && dialog --colors --msgbox "\Z2Configuration file created successfully.\Zn" 6 50 || { dialog --colors --msgbox "\Z1Error: Could not create config file.\Zn" 6 50; return 1; }
    # Set the file permissions
    chmod 666 $COMMODEBIAN_CONF
}

# Function to display the status of the last command
function dialog_status {
    [ $1 -eq 0 ] && dialog --colors --msgbox "\Z2$2 successful.\Zn" 6 50 || dialog --colors --msgbox "\Z1Error: $2 failed.\Zn" 6 50
}

function show_welcome {
    dialog --clear --backtitle "$BACKTITLE" --title "Welcome" --msgbox "\n   Welcome to the Commodore Debian script." 7 50
}

function show_exit {
    dialog --clear --backtitle "$BACKTITLE" --title "Goodbye" --msgbox "\nThank you for using the Commodore Debian script." 7 60
}

# Function to boot the emulator
function boot_emu {
    # check if running in terminal
    if ! check_ssh; then
        dialog --colors --msgbox "\Z1Error: This option is only available from the console.\Zn" 6 50
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
        echo "Configuration file found. Loading configuration..."
        source $COMMODEBIAN_CONF
        # Check if the configuration file loaded correctly
        if [ $? -ne 0 ]; then
            echo "Error: Could not load configuration file."
            exit 1
        fi
        # Check if the version is set
        if [ -z "$VERSION" ]; then
            echo "Error: Could not load version from config file. Running the setup."
            setup_commodebian
        fi
        # Check if the emulator is set
        if [ -z "$EMU" ]; then
            echo "Emulator not set in config. Running the setup."
            setup_commodebian
        else
            # Check if the emulator exists
            if ! [ -f $EMU ]; then
                echo "Emulator not found. Running the setup."
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
                echo "Running emulator: $EMU"
                echo "    with options: $OPTS"
                $EMU $OPTS > /dev/null 2>&1
                # Check if the emulator ran successfully   
                if [ $? -eq 0 ]; then
                    echo "Emulator running successfully."
                else
                    echo "Error: Could not run emulator."
                    exit 1
                fi
            fi
        fi
    fi
}

# Function to display the config menu
function show_notsetup {
    if ! [ -f $COMMODEBIAN_CONF ]; then
        # check if running in terminal
        dialog --title "Setup Commodebian" --backtitle $BACKTITLE --yesno \
                       "\nWelcome to Commodebian.\n\nThe menu system for Commodore Vice Emulator.\n
This script is designed to help you setup and install an easy to use system.\n\nWould you like to set it up now?" 13 60
        RESPONSE=$?

        if [ $RESPONSE -eq 1 ]; then 
            dialog --colors --msgbox "\nSetup canceled." 7 50
            return 1
        fi
        if [ $RESPONSE -eq 0 ]; then
            dialog --colors --msgbox "\nSetup starting..." 7 50
            create_config
            show_installed_menu
        fi
    else
        dialog --colors --msgbox "\Z1Error: Commodebian is already installed.\Zn" 6 50
    fi
}

# Function to perform self-update
function self_update {
    # check if running as root
    [ "$ROOT" != "true" ] && { echo "Error: This option must be run as root or with sudo."; return 1; }
    #check if prerequisites are installed
    check_prerequisites
    #check if commodebian is installed
    check_commodebian_install
    SCRIPT_URL=$ONLINE_URL
    SCRIPT_PATH="$(realpath "$0")"
    TMP_SCRIPT="/tmp/updated_script.sh"
    TEMP_FILE=$(mktemp)

    cleanup() { rm -f "$TEMP_FILE" "$TMP_SCRIPT"; }
    trap cleanup EXIT

    # Check if script is already installed
    if [ "$SCRIPT_PATH" != "$INSTALL_LOCATION/bin/commodebian.sh" ]; then
        dialog --colors --msgbox "\nThis seems to be a first run.\nInstalling to $INSTALL_LOCATION/bin/commodebain.sh now." 8 50
        cp "$SCRIPT_PATH" "$INSTALL_LOCATION/bin/commodebain.sh" 2>/dev/null
        if ! [ $? -eq 0 ]; then
            dialog --colors --msgbox "\Z1Error: Could not copy script to $INSTALL_LOCATION/bin/commodebain.sh\Zn" 6 50
            return 1
        fi
        SCRIPT_PATH=$INSTALL_LOCATION
        chmod +x "$SCRIPT_PATH"
        create_config
    fi

    # Get current script version
    CURRENT_VERSION=$(grep -m1 -o 'VERSION=[0-9]\+\.[0-9]\+' "$SCRIPT_PATH" | cut -d= -f2)
    if [[ -z "$CURRENT_VERSION" || ! "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Unable to determine the current version. Please check the script format."
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
        dialog --colors --msgbox "\Z1Error: Failed to download the script\Zn" 6 50
        return 1
    fi

    # Verify downloaded file is a valid bash script
    if ! head -n 1 "$TMP_SCRIPT" | grep -q '^#!/bin/bash'; then
        dialog --colors --msgbox "\Z1Error: Downloaded file is not a valid script\Zn" 6 50
        return 1
    fi

    # Extract new version
    REMOTE_VERSION=$(grep -m1 -o 'VERSION=[0-9]\+\.[0-9]\+' "$TMP_SCRIPT" | cut -d= -f2)
    REMOTE_VERSION="${REMOTE_VERSION:-unknown}"

    # Simple version comparison (could be enhanced)
    if [ "$REMOTE_VERSION" != "unknown" ] && [ "$CURRENT_VERSION" = "$REMOTE_VERSION" ]; then
        dialog --msgbox "Script is already up to date (version $CURRENT_VERSION)" 6 50
        return 0
    fi

    # Define backup script path
    BACKUP_SCRIPT="${SCRIPT_PATH}.bak"

    # Backup current script
    if ! cp "$SCRIPT_PATH" "$BACKUP_SCRIPT" 2>/dev/null; then
        dialog --colors --msgbox "\Z1Error: Could not create backup\Zn" 6 50
        return 1
    fi

    # Replace script
    dialog --infobox "Installing update..." 3 50
    if cp "$TMP_SCRIPT" "$SCRIPT_PATH" && chmod +x "$SCRIPT_PATH"; then
        dialog --msgbox "Update to version ${REMOTE_VERSION} successful!\n\nBackup saved as: $BACKUP_SCRIPT\n\nRestarting..." 8 50
        exec "$SCRIPT_PATH" "$@"
    else
        cp "$BACKUP_SCRIPT" "$SCRIPT_PATH" 2>/dev/null
        dialog --colors --msgbox "\Z1Update failed, restored original script\Zn" 6 50
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
        dialog --msgbox "Packages updated successfully!" 6 50
    else
        # If the user pressed Cancel, notify them
        dialog --msgbox "No changes were made." 6 50
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
        dialog --msgbox "Vice archive already exists at $FILE. Skipping download." 6 50
    else
        dialog --colors --infobox "Downloading Vice..." 3 50
        # Download the file to /tmp
        wget -q --show-progress -O "$FILE" "$URL"
        
        # Check if the download was successful
        if [ $? -eq 0 ]; then
            dialog --msgbox "Vice downloaded successfully to $FILE." 6 50
        else
            dialog --colors --msgbox "\Z1Error: Failed to download Vice.\Zn" 6 50
        fi
    fi
}

# Function to extract Vice
function extract_vice {
    EXTRACT_DIR="$INSTALL_LOCATION/src/vice-3.9"  # Define the destination directory
    FILE="/tmp/vice-3.9.tar.gz"  # Ensure this is the correct path to the downloaded file

    if [ ! -f "$FILE" ]; then
        dialog --colors --msgbox "\Z1Error: $FILE does not exist. Please download the Vice archive first.\Zn" 6 50
        return 1
    fi

    # Check if the extraction directory exists
    if [ -d "$EXTRACT_DIR" ]; then
        dialog --title "Overwrite Directory" --yesno --defaultno "The directory $EXTRACT_DIR already exists. Do you want to overwrite it?" 7 60
        RESPONSE=$?

        if [ $RESPONSE -eq 1 ]; then  # If "No" is selected (EXIT_STATUS is 1)
            dialog --colors --msgbox "Extraction canceled." 6 50
            return 1
        fi
    else
        # Create the directory if it does not exist
    mkdir -p "$EXTRACT_DIR"
    fi

    # Extract the file to $INSTALL_LOCATION/src/vice-3.9
    dialog --infobox "Extracting Vice to $EXTRACT_DIR..." 3 50
    tar -xzf "$FILE" -C "$EXTRACT_DIR" > /dev/null 2>&1

    # Check if the extraction was successful
    if [ $? -eq 0 ]; then
        dialog --msgbox "Vice extracted successfully to $EXTRACT_DIR." 6 50
    else
        dialog --colors --msgbox "\Z1Error: Failed to extract Vice.\Zn" 6 50
    fi
}

# Function to build Vice
function build_vice {
    if ! cd vice-3.9/; then
        dialog --colors --msgbox "\Z1Error: Could not change to vice-3.9 directory\Zn" 6 50
        return 1
    fi
    dialog --colors --infobox "\Z2Running autogen.sh...\Zn" 3 50
    ./autogen.sh > /dev/null 2>&1
    dialog_status $? "Ran autogen.sh"

    dialog --colors --infobox "\Z2Configuring Vice...\Zn" 3 50
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
    dialog --colors --infobox "\Z2Installing Vice...\Zn" 3 50
    make install > /dev/null 2>&1
    dialog_status $? "Installed Vice"
}

# Function to configure system
function configure_system {
    # check if prerequisites are installed
    check_prerequisites
    # check if commodebian is installed
    check_commodebian_install
    # check if commodebian is setup
    check_commodebian_setup
    # check if commodebian is up to date
    check_commodebian_version

    # show install menu
    show_install_menu
    dialog --colors --msgbox "\Z2System configured successfully.\Zn" 6 50
}

# Function to start tcpser
function start_tcpser {
    [ ! -f "$TCPSER_BIN" ] && { dialog --colors --msgbox "\Z1Error: tcpser binary not found.\Zn" 6 50; return 1; }
    systemctl is-active tcpser.service > /dev/null 2>&1 && { dialog --colors --msgbox "\Z1Error: tcpser service is already running.\Zn" 6 50; return 1; }
    dialog --colors --infobox "Starting tcpser service..." 3 50
    sudo systemctl start tcpser.service && dialog --colors --msgbox "\Z2tcpser started successfully.\Zn" 6 50 || dialog --colors --msgbox "\Z1Error: Failed to start tcpser.\Zn" 6 50
}

# Function to stop tcpser
function stop_tcpser {
    [ ! -f "$TCPSER_BIN" ] && { dialog --colors --msgbox "\Z1Error: tcpser binary not found.\Zn" 6 50; return 1; }
    systemctl is-active tcpser.service > /dev/null 2>&1 || { dialog --colors --msgbox "\Z1Error: tcpser service is not running.\Zn" 6 50; return 1; }
    dialog --colors --infobox "Stopping tcpser service..." 3 50
    sudo systemctl stop tcpser.service && dialog --colors --msgbox "\Z2tcpser stopped successfully.\Zn" 6 50 || dialog --colors --msgbox "\Z1Error: Failed to stop tcpser.\Zn" 6 50
}

# Function to install tcpser (combines all steps)
function install_tcpser {
    [ "$ROOT" != "true" ] && { dialog --colors --msgbox "\Z1Error: Root access required.\Zn" 6 50; return 1; }
    [ -f "$TCPSER_BIN" ] && { dialog --colors --msgbox "\Z1Error: tcpser binary already exists.\Zn" 6 50; return 1; }
    for cmd in wget tar make gcc systemctl; do
        command -v "$cmd" &> /dev/null || { dialog --colors --msgbox "\Z1Error: $cmd is required but not installed.\Zn" 6 50; return 1; }
    done
    download_tcpser && extract_tcpser && compile_tcpser && install_tcpser_binary && setup_tcpser_service && { dialog --colors --msgbox "\Z2tcpser installation complete! Use 'systemctl start tcpser.service' to start.\Zn" 6 50; rm -f "/tmp/tcpser-${LATEST_RELEASE}.tar.gz"; }
}

# Function to remove tcpser
function remove_tcpser {
    [ "$ROOT" != "true" ] && { dialog --colors --msgbox "\Z1Error: Root access required.\Zn" 6 50; return 1; }
    [ ! -f "$TCPSER_BIN" ] && { dialog --colors --msgbox "\Z1Error: tcpser binary not found.\Zn" 6 50; return 1; }
    dialog --colors --infobox "Removing tcpser..." 3 50
    sudo systemctl stop tcpser.service 2>/dev/null
    sudo systemctl disable tcpser.service 2>/dev/null
    sudo rm -f "/etc/systemd/system/tcpser.service" "$TCPSER_BIN" "$INSTALL_LOCATION/src/tcpser" -r
    sudo systemctl daemon-reload
    [ $? -eq 0 ] && dialog --colors --msgbox "\Z2tcpser removed successfully.\Zn" 6 50 || dialog --colors --msgbox "\Z1Error: Failed to remove tcpser.\Zn" 6 50
}

# Function to edit tcpser config
function edit_tcpser_config {
    # Check if the config file exists
    if ! [ -f "$TCPSER_CONF" ]; then
        dialog --colors --msgbox "\Z1Error: TCPSER configuration file not found.\Zn" 6 50
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

    dialog --colors --infobox "Downloading tcpser ${LATEST_RELEASE} to ${TMP_DIR}..." 3 50
    wget -O "$ARCHIVE_FILE" "$ARCHIVE_URL" || { dialog --colors --msgbox "\Z1Error: Failed to download tcpser from ${ARCHIVE_URL}\Zn" 6 50; return 1; }
    dialog --colors --msgbox "\Z2tcpser downloaded successfully to ${ARCHIVE_FILE}.\Zn" 6 50
}

# Function to extract tcpser
function extract_tcpser {
    TMP_DIR="/tmp"
    SRC_DIR="$INSTALL_LOCATION/src/tcpser"
    LATEST_RELEASE=$(wget -qO- "https://api.github.com/repos/go4retro/tcpser/releases/latest" | grep -oP '"tag_name": "\K[^"]+')
    ARCHIVE_FILE="${TMP_DIR}/tcpser-${LATEST_RELEASE}.tar.gz"

    [ ! -f "$ARCHIVE_FILE" ] && { dialog --colors --msgbox "\Z1Error: tcpser archive not found. Please download it first.\Zn" 6 50; return 1; }
    dialog --colors --infobox "Extracting tcpser to ${SRC_DIR}..." 3 50
    sudo mkdir -p "$SRC_DIR" || { dialog --colors --msgbox "\Z1Error: Failed to create directory ${SRC_DIR}\Zn" 6 50; return 1; }
    sudo tar -xzf "$ARCHIVE_FILE" -C "$SRC_DIR" --strip-components=1 || { dialog --colors --msgbox "\Z1Error: Failed to extract tcpser\Zn" 6 50; return 1; }
    dialog --colors --msgbox "\Z2tcpser extracted successfully to ${SRC_DIR}.\Zn" 6 50
}

# Function to compile tcpser
function compile_tcpser {
    SRC_DIR="$INSTALL_LOCATION/src/tcpser"
    [ ! -d "$SRC_DIR" ] && { dialog --colors --msgbox "\Z1Error: Source directory ${SRC_DIR} not found. Please extract tcpser first.\Zn" 6 50; return 1; }
    dialog --colors --infobox "Compiling tcpser in ${SRC_DIR}..." 3 50
    cd "$SRC_DIR" || { dialog --colors --msgbox "\Z1Error: Cannot change to ${SRC_DIR}\Zn" 6 50; return 1; }
    sudo make || { dialog --colors --msgbox "\Z1Error: Compilation failed. Check dependencies (e.g., build-essential).\Zn" 6 50; return 1; }
    dialog --colors --msgbox "\Z2tcpser compiled successfully.\Zn" 6 50
}

# Function to install tcpser binary
function install_tcpser_binary {
    SRC_DIR="$INSTALL_LOCATION/src/tcpser"
    BIN_DIR="$INSTALL_LOCATION/bin"
    [ ! -f "$SRC_DIR/tcpser" ] && { dialog --colors --msgbox "\Z1Error: tcpser binary not found in ${SRC_DIR}. Please compile it first.\Zn" 6 50; return 1; }
    dialog --colors --infobox "Installing tcpser binary to ${BIN_DIR}..." 3 50
    sudo install -m 755 "$SRC_DIR/tcpser" "$BIN_DIR/tcpser" || { dialog --colors --msgbox "\Z1Error: Failed to install tcpser binary\Zn" 6 50; return 1; }
    dialog --colors --msgbox "\Z2tcpser binary installed successfully to ${BIN_DIR}.\Zn" 6 50
}

# Function to setup tcpser systemd service
function setup_tcpser_service {
    SERVICE_DIR="/etc/systemd/system"
    SERVICE_FILE="$SERVICE_DIR/tcpser.service"
    dialog --colors --infobox "Creating tcpser systemd service..." 3 50
    cat << EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=tcpser - TCP to Serial Bridge for Retro Computing
After=network.target

[Service]
ExecStart=$INSTALL_LOCATION/bin/tcpser -v 25232 -p 6400 -s 2400 -tSs -l 7
ExecStop=/usr/bin/pkill -f tcpser
Restart=always
User=nobody
Group=nogroup

[Install]
WantedBy=multi-user.target
EOF
    [ $? -ne 0 ] && { dialog --colors --msgbox "\Z1Error: Failed to create service file\Zn" 6 50; return 1; }

    sudo systemctl daemon-reload || { dialog --colors --msgbox "\Z1Error: Failed to reload systemd daemon\Zn" 6 50; return 1; }
    sudo systemctl enable tcpser.service || { dialog --colors --msgbox "\Z1Error: Failed to enable tcpser service\Zn" 6 50; return 1; }
    dialog --colors --msgbox "\Z2tcpser service setup successfully.\Zn" 6 50
}

# Function to view tcpser status
function view_tcpser_status {
    [ ! -f "$TCPSER_BIN" ] && { dialog --colors --msgbox "\Z1Error: tcpser binary not found.\Zn" 6 50; return 1; }
    STATUS=$(systemctl is-active tcpser.service)
    [ "$STATUS" = "active" ] && dialog --colors --msgbox "\Z2tcpser is running.\Zn" 6 50 || dialog --colors --msgbox "\Z1tcpser is not running.\Zn" 6 50
}

# Function to view tcpser help
function view_tcpser_help {
    [ ! -f "$TCPSER_BIN" ] && { dialog --colors --msgbox "\Z1Error: tcpser binary not found.\Zn" 6 50; return 1; }
    $TCPSER_BIN -h | dialog --colors --textbox - 20 80
}

# Function to install autostart
function install_autostart {

    # Ensure the .profile file exists
    if ! [ -f "$PROFILE_FILE" ]; then
        touch "$PROFILE_FILE"
        if ! [ $? -eq 0 ]; then
            dialog --colors --msgbox "\Z1Error: Could not create $PROFILE_FILE.\Zn" 6 50
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
            dialog --colors --msgbox "\Z1Error: Failed to write line: $line\Zn" 6 50
            return 1
        fi
    done
    dialog --msgbox "Autostart setup completed successfully!" 6 50
}

# Function to remove autostart
function remove_autostart {
    # Escape special characters in the lines for sed
    for line in "${PROFILE_AUTOSTART_LINES[@]}"; do
        escaped_line=$(printf '%s\n' "$line" | sed 's/[]\/$*.^[]/\\&/g')
        sed -i "/$escaped_line/d" "$PROFILE_FILE"
    done

    dialog --msgbox "Autostart removed successfully!" 6 50
}

# Function to edit the user profile
function edit_profile {
    PROFILE_FILE="$HOME/.profile"
    TEMP_FILE=$(mktemp)
    # Check if the .profile file exists
    if ! [ -f "$PROFILE_FILE" ]; then
        dialog --colors --msgbox "\Z1Error: $PROFILE_FILE does not exist.\Zn" 6 50
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

# Function to display the install menu
function show_install_menu {
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
    check_prerequisites
    # check if commodebian is installed
    check_commodebian_install
    # check if commodebian is setup
    check_commodebian_setup
    # check if commodebian is up to date
    check_commodebian_version
    
    # Check if the config file exists
    if ! [ -f $COMMODEBIAN_CONF ]; then
        dialog --colors --msgbox "\Z1Error: Could not load config file.\Zn" 6 50
        return 1
    fi
    # Load the config file
    source $COMMODEBIAN_CONF
    # check if file loaded correctly
    if [ $? -ne 0 ]; then
        dialog --colors --msgbox "\Z1Error: Could not load config file.\Zn" 6 50
        return 1
    fi

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

# Function to edit options
function edit_emulator_options {
    check_config_file
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
        dialog --colors --msgbox "\Z1Error: Could not load config file.\Zn" 6 50
        return 1
    fi
    # Load the config file
    source $COMMODEBIAN_CONF
    # check if file loaded correctly
    if [ $? -ne 0 ]; then
        dialog --colors --msgbox "\Z1Error: Could not load config file.\Zn" 6 50
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
    check_config_file
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
        dialog --colors --msgbox "\Z1Error: Disk directory not found.\Zn" 6 50
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
    check_config_file
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
        dialog --colors --msgbox "\Z1Error: Cartridge directory not found.\Zn" 6 50
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
    if [ "$ROOT" = "true" ]; then
        tput civis
        clear
        shutdown -r now
        exit 0
    else
        tput cvvis
        printf "\nERROR can't shutdown not root\n\n"
        exit 1
    fi
}

# Function to shutdown the system
function shutdown_function {
    if [ "$ROOT" = "true" ]; then
        tput civis
        clear
        shutdown -h now
        exit 0
    else
        tput cvvis
        printf "\nERROR can't shutdown not root\n\n"
        exit 1
    fi
}

### Main script starts here ###

# Check for modifier keywords
case "$1" in
    boot)
        # this is to run the emulator at boot
        check_ssh
        echo "Running emulator..."
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
        echo "Installing Commodebian..."
        install_commodebian
        exit 0
        ;;
    setup)
        # this is to setup the requirements for the vice emulator
        echo "Setting up Commodebian..."
        setup_commodebian
        exit 0
        ;;
    update)
        # this is to update the script
        echo "Updating Commodebian..."
        self_update
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
        show_console_online_version
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
check_commodebian_install
# check if check was successful
if ! [ $? -eq 0 ]; then
    echo "Error: Commodebian not setup. Please run the script with the sudo and the install option."
    exit 1
fi

show_welcome

if ! [ -f $COMMODEBIAN_CONF ]; then
    show_notsetup
fi

if [ "$ROOT" = "true" ]; then
    show_install_menu
else
    if [ -f $COMMODEBIAN_CONF ]; then
        show_main_menu
    else    # not root and not installed
        echo "Error: Commodebian not setup. Please run the script with the sudo and the install option."
        exit 1
    fi
fi
exit 0