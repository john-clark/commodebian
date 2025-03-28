#!/bin/bash
# filepath: commodebian/functions/vice.sh
# vice-related functions

# Make sure this was called from the main script
if [[ -z "$COMMODORE" ]]; then
    echo "This script is not meant to be run directly."
    return 1
fi

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
function install_vice_dependencies {

    TEMP_FILE=$(mktemp)
    VICE_INSTALL_LOG_FILE="/tmp/install_vice_dependencies.log"
    # Cleanup function
    cleanup() { rm -f "$TEMP_FILE" "$VICE_INSTALL_LOG_FILE"; }
    trap cleanup EXIT

    # Start package installation
    DEBIAN_FRONTEND=noninteractive apt-get install -y $PACKAGES --show-progress > "$VICE_INSTALL_LOG_FILE" 2>&1 &
    APT_PID=$!

    # Function to parse the progress
    parse_progress() {
        local progress_line
        progress_line=$(tail -n 1 "$VICE_INSTALL_LOG_FILE" | grep -o 'Progress: [0-9]\+%' | awk '{print $2}' | tr -d '%')
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
                less "$VICE_INSTALL_LOG_FILE"
            else
                cat "$VICE_INSTALL_LOG_FILE"
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

    # Check if the file exists before extracting
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

    # Check if the configuration was successful
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
    run_as_sudo make install > /dev/null 2>&1
    dialog_status $? "Installed Vice"
}

# Function to check the Vice installation
function check_vice_installation {

    # Check if Vice is installed by checking for the x64 binary
    if ! command -v x64 &> /dev/null; then
        display_message "Vice is not installed. Please install it." "dialog" "error"
        return 1
    fi
    display_message "Vice is installed." "dialog" "success"
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
