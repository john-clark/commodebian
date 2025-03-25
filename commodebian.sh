#!/bin/bash
#
# Commodebian - A menu system for Commodore Vice Emulator 
# copyright (c) 2025 - John Clark
# https://github.com/john-clark/commodebian/

VERSION=0.1.23   # Version of the script
ONLINE_URL="https://raw.githubusercontent.com/john-clark/commodebian/main/commodebian.sh" # URL to download the latest version of the script
INSTALL_LOCATION="/usr/local" # Location to install Commodebian
COMMODEBIAN_CONF="$INSTALL_LOCATION/etc/commodebian.conf" # Configuration file
PACKAGES="pv build-essential autoconf automake libtool libsdl2-dev libsdl2-image-dev libcurl4-openssl-dev libglew-dev libpng-dev zlib1g-dev flex byacc xa65 dos2unix" # Packages to install

AUTOSTART_LINES=(
    "# Commodebian Autostart"
    "if [ -f \"$COMMODEBIAN_CONF\" ]; then clear && $INSTALL_LOCATION/bin/commodebian.sh boot || $INSTALL_LOCATION/bin/commodebian.sh menu; fi"
)

# Check if the script is being run as root
ROOT=$( [ "$(id -u)" -eq 0 ] && echo "true" || echo "false" )

# Determine the regular user's home directory if running with sudo
if [ -n "$SUDO_USER" ]; then
    # Get the home directory of the user who invoked sudo
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    # Check if the home directory was found
    if [ -z "$USER_HOME" ]; then
        echo "Error: Could not determine home directory for user $SUDO_USER."
        exit 1
    fi
else
    USER_HOME="$HOME"  # Fallback to $HOME if running as root without sudo
fi
PROFILE_FILE="$USER_HOME/.profile"

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

#fucntion to check Commodebian version
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
        echo "Required file $file not found."
        return 1
    fi
}

# function to Check if the script is being run from $INSTALL_LOCATION/bin
function check_script_location {
    if ! [ "$(realpath "$0")" = "$INSTALL_LOCATION/bin/commodebian.sh" ]; then
        echo "This script must be run from $INSTALL_LOCATION/bin/commodebian.sh"
        exit 1
    fi
}

# Function to check if prerequisites are installed
function check_prerequisites {
    # Check if dialog is installed
    if ! command -v dialog &> /dev/null; then
        echo "dialog is not installed. Run \"commodebian install\" with sudo."
        exit 1
    fi
    # Check if wget is installed
    if ! command -v wget &> /dev/null; then
        echo "wget is not installed. Run \"commodebian install\" with sudo."
        exit 1
    fi
}

# Function to install Commodebian (makes sure dialog, wget and commodebian.sh are installed)
function install_commodebian {
    setup_message="Setting up Commodebian...\n"
    # Check if script is run with sudo or as root
    if [ "$ROOT" != "true" ]; then
        echo -e "\033[31mCommodebian is not yet setup and must be run as root or with sudo.\033[0m"
        exit 1
    else
        setup_message+="Running with correct permissions.\n"
    fi

    setup_message+="Checking for required packages...\n"
    # Requirements for this script
    if ! command -v dialog &> /dev/null; then
        setup_message+="dialog is not installed. Installing it now...\n"
        DEBIAN_FRONTEND=noninteractive apt-get install -y dialog -qq < /dev/null > /dev/null
        if ! [ $? -eq 0 ]; then
            echo "Failed to install dialog. Please check your system's package manager or network connection."
            exit 1
        fi
    else
        setup_message+="dialog is installed.\n"
    fi
    if ! command -v wget &> /dev/null; then
        setup_message+="wget is not installed. Installing it now...\n"
        DEBIAN_FRONTEND=noninteractive apt-get install -y wget -qq < /dev/null > /dev/null
        if ! [ $? -eq 0 ]; then
            echo "Failed to install wget. Please check your system's package manager or network connection."
            exit 1
        fi
    else
        setup_message+="wget is installed.\n"
    fi

    # Check if the script is being run from $INSTALL_LOCATION/bin
    if ! [ -f $INSTALL_LOCATION/bin/commodebian.sh ]; then
        setup_message+="Commodebian is not installed. Installing now...\n"
        cp "$0" $INSTALL_LOCATION/bin/commodebian.sh
        if ! [ $? -eq 0 ]; then
            echo "Failed to copy script to $INSTALL_LOCATION/bin. Please check your permissions."
            exit 1
        fi
        # Check if the script was copied successfully
        if ! [ -f $INSTALL_LOCATION/bin/commodebian.sh ]; then
            echo "Failed to copy script to $INSTALL_LOCATION/bin. Please check your permissions."
            exit 1
        fi
        # Check if the script is executable
        if ! [ -x $INSTALL_LOCATION/bin/commodebian.sh ]; then
            chmod +x $INSTALL_LOCATION/bin/commodebian.sh
            if ! [ $? -eq 0 ]; then
                echo "Failed to make script executable. Please check your permissions."
                exit 1
            fi
        fi
        setup_message+="Commodebian installed successfully.\n"
    else
        diff "$0" $INSTALL_LOCATION/bin/commodebian.sh > /dev/null
        if ! [ $? -eq 0 ]; then
            setup_message+="Commodebian is outdated. Updating now...\n"
            mv $INSTALL_LOCATION/bin/commodebian.sh $INSTALL_LOCATION/bin/commodebian.sh.bak
            if ! [ $? -eq 0 ]; then
                echo "Failed to backup script. Please check permissions."
                exit 1
            fi
            cp "$0" $INSTALL_LOCATION/bin/commodebian.sh
            if ! [ $? -eq 0 ]; then
                echo "Failed to copy script to $INSTALL_LOCATION/bin. Please check permissions."
                exit 1
            fi
            setup_message+="Commodebian updated successfully.\n"
        fi
    fi

    setup_message+="Commodebian setup complete.\n"
    echo -e "\n$setup_message"
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
    if ! [ -f $COMMODEBIAN_CONF ]; then
        echo "Configuration file not found. Running setup..."
        create_config
    fi
}

# function to create config file
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
VERSION="$VERSION"
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
    # Check if the file was created successfully
    if [ $? -eq 0 ]; then
        dialog --colors --msgbox "\Z2Configuration file created successfully.\Zn" 6 50
    else
        dialog --colors --msgbox "\Z1Error: Could not create config file.\Zn" 6 50
        return 1
    fi
    # Set the file permissions
    chmod 666 $COMMODEBIAN_CONF
}

# Function to display the status of the last command
function dialog_status {
    if [ $1 -eq 0 ]; then
        dialog --colors --msgbox "\Z2$2 successful.\Zn" 6 50
    else
        dialog --colors --msgbox "\Z1Error: $2 failed.\Zn" 6 50
    fi
}

function show_welcome {
    dialog --clear --backtitle "Commodebian" \
               --title "Welcome" \
               --msgbox "\n   Welcome to the Commodore Debian script." 7 50
}

function show_exit {
    dialog --clear --backtitle "Commodebian" \
                   --title "Goodbye" \
                   --msgbox "\nThank you for using the Commodore Debian script." 7 60
}

# function to boot the emulator
function boot_emu {
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
        dialog --title "Setup Commodebian" --yesno \
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
        return 1
    fi
}

# Function to perform self-update
function self_update {
    # check if running as root
    if [ "$ROOT" != "true" ]; then
        echo "Error: This option must be run as root or with sudo."
        return 1
    fi
    
    #check if prerequisites are installed
    check_prerequisites
    #check if commodebian is installed
    check_commodebian_install

    SCRIPT_URL="http://192.168.1.2/commodebian.sh"
    SCRIPT_PATH="$(realpath "$0")"
    TMP_SCRIPT="/tmp/updated_script.sh"
    TEMP_FILE=$(mktemp)

    # Cleanup function
    cleanup() {
        rm -f "$TEMP_FILE" "$TMP_SCRIPT"
    }
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
    cleanup() {
        rm -f "$TEMP_FILE"
        rm -f "$LOG_FILE"
    }
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

# Function to install autostart
function install_autostart {
    check_prerequisites
    check_commodebian_install
    check_commodebian_setup
    check_commodebian_version

    # Ensure the .profile file exists
    if ! [ -f "$PROFILE_FILE" ]; then
        touch "$PROFILE_FILE"
        if ! [ $? -eq 0 ]; then
            dialog --colors --msgbox "\Z1Error: Could not create $PROFILE_FILE.\Zn" 6 50
            return 1
        fi
    fi

    # Add the lines to .profile if they don't already exist
    for line in "${AUTOSTART_LINES[@]}"; do
        if ! grep -Fxq "$line" "$PROFILE_FILE"; then
            echo "$line" >> "$PROFILE_FILE"
        fi
    done

    # Ensure all lines are written correctly
    for line in "${AUTOSTART_LINES[@]}"; do
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
    for line in "${AUTOSTART_LINES[@]}"; do
        escaped_line=$(printf '%s\n' "$line" | sed 's/[]\/$*.^[]/\\&/g')
        sed -i "/$escaped_line/d" "$PROFILE_FILE"
    done

    dialog --msgbox "Autostart removed successfully!" 6 50
}

# Function to display the config menu
function show_install_menu {
    HEIGHT=20
    WIDTH=50
    CHOICE_HEIGHT=14
    BACKTITLE="Commodebian $VERSION"
    TITLE="Commodebian Installer Menu"
    MENU="Use arrow keys to move through options"
    
    if $ROOT; then
        OPTIONS=(
                x  "  Exit to command Line  "
                m  "  Main Menu  "
                "" ""
                1  "  Check for Updates  "
                2  "  Install dependencies  "
                3  "  Edit dependencies  "
                "" ""
                4  "  Download Vice  "
                5  "  Extract Vice  "
                6  "  Build Vice  "
                7  "  Install Vice  "
                "" ""
                8  "  Install autostart  "
                9  "  Remove autostart  "
        )
    else
        OPTIONS=(
                m  "  Return to Main Menu  "
                "" ""
                8  "  Install autostart  "
                9  "  Remove autostart  "
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
                8) install_autostart ;;
                9) remove_autostart ;;
                m) show_main_menu ;;
                x) clear ; exit 0 ;;
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

    HEIGHT=34
    WIDTH=90
    CHOICE_HEIGHT=35
    BACKTITLE="Commodebian $VERSION"
    TITLE="Commodebian Main Menu"
    MENU="Use arrow keys to move through options"

    OPTIONS=(
            
            a  "  ABOUT COMMODEBIAN"
            b  "  START COMMODORE EMULATOR"
            "" ""
            "" "- CHOOSE EMULATOR TO RUN AT BOOT -" 
            "" ""
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
            "" ""
            "" "- OTHER OPTIONS -"
            "" ""
            i "  INSTALLATION MENU"
            "" ""
            "" "- SYSTEM OPTIONS -"
            "" ""
            r "  REBOOT"
            s "  SHUTDOWN"
            x  "  Exit to command Line"
    )

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
            
            1)  change_config "EMU" "$INSTALL_LOCATION/bin/x64"
                ;;
            2)  change_config "EMU" "$INSTALL_LOCATION/bin/x64dtv"
                ;;
            3)  change_config "EMU" "$INSTALL_LOCATION/bin/x64sc"
                ;;
            4)  change_config "EMU" "$INSTALL_LOCATION/bin/x64sc"
                ;;
            5)  change_config "EMU" "$INSTALL_LOCATION/bin/x128"
                ;;
            6)  change_config "EMU" "$INSTALL_LOCATION/bin/x128"
                ;;
            7)  change_config "EMU" "$INSTALL_LOCATION/bin/xcbm2"
                ;;
            8)  change_config "EMU" "$INSTALL_LOCATION/bin/xcbm5x0"
                ;;
            9)  change_config "EMU" "$INSTALL_LOCATION/bin/xvic"
                ;;
            10) change_config "EMU" "$INSTALL_LOCATION/bin/xplus4"
                ;;
            11) change_config "EMU" "$INSTALL_LOCATION/bin/xpet"
                ;;
            a)  show_about_menu
                #less -P "Use arrow up and down keys to scroll - Press q to quit" $INSTALL_LOCATION/etc/commodebian/installation_guide.txt   
                ;;
            b)  boot_emu
                ;;
            i)  show_install_menu
                ;;
            r) reboot_function
                ;;
            s) shutdown_function
                ;;
            x) clear ; exit 0
                ;;
        esac
    done
}

# Function to change configuration variable
function change_config {
    # Check if the config file exists
    if ! [ -f $COMMODEBIAN_CONF ]; then
        dialog --colors --msgbox "\Z1Error: Configuration file not found.\Zn" 6 50
        return 1
    fi

    if [ -z "$1" ]; then
        dialog --colors --msgbox "\Z1Error: Variable $1 not set.\Zn" 6 50
        return 1
    fi

    # Change the variable in the config file
    escaped_key=$(printf '%q' "$1")
    if grep -q "^$escaped_key=" "$COMMODEBIAN_CONF"; then
        current_value=$(grep "^$escaped_key=" "$COMMODEBIAN_CONF" | cut -d= -f2 | tr -d '"')
        if [ "$current_value" != "$2" ]; then
            sed -i "s|^$escaped_key=.*|$escaped_key=\"$2\"|" "$COMMODEBIAN_CONF"
        fi
    else
        echo "$escaped_key=\"$2\"" >> "$COMMODEBIAN_CONF"
    fi

    # Check if the change was successful
    if [ $? -eq 0 ]; then
        dialog --colors --msgbox "\Z2Configuration updated successfully.\Zn" 6 50
        return 0
    else
        dialog --colors --msgbox "\Z1Error: Could not update configuration.\Zn" 6 50
        return 1
    fi
}

# function to check if running in ssh
function check_ssh {
    if [ "$SSH_CONNECTION" ]; then
        # Running in a remote session
        echo "Detected: Remote SSH session."
        echo "Please run this script from the console or terminal."
        exit 1
    fi
}

# Function to display the about menu
function show_about_menu {
    dialog --clear --backtitle "Commodebian" \
               --title "About Commodebian" \
               --msgbox "\n   Commodebian $VERSION\n\nThis is a menu system for the Commodore Vice Emulator.\n\nAuthor: 5k7m4n\nEmail: 5k7m4n@gmail.com" \
                10 50
    #printf "\n\nPress any key to return to the main menu..."
    #read -n 1 -s
    clear
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
        echo "Commodebian version $VERSION"
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