#!/bin/bash
# filepath: commodebian/functions/utils.sh
# Utility/helper functions

# Make sure this was called from the main script
if [[ -z "$COMMODORE" ]]; then
    echo "This script is not meant to be run directly."
    return 1
fi

# Function to check if running in ssh
# This function checks if the script is being run in a remote SSH session.
# If the SSH_CONNECTION variable is set, it indicates that the script is running in a remote session.
# Usage: check_ssh
# Returns:
#   - 0 if not running in a remote SSH session (i.e., running in a console).
#   - 1 if running in a remote SSH session.
function check_ssh {

    if [ "$SSH_CONNECTION" ]; then
        # Running in a remote session
        #display_message "Detected Remote SSH session Please run this script from the console or terminal.\n" $display_output "error"
        return 1
    fi
}

# Function to change file permissions (#fix this to either use echo or dialog)
# This function will change the permissions of a specified file.
# Usage: change_file_permissions <file_path> <permissions>
# Example: change_file_permissions "/path/to/file.txt" "755"
# Parameters:
#   - file: The path to the file for which you want to change permissions.
#   - permissions: The permissions to set for the file (e.g., "755", "644", etc.).
# Returns:
#   - 0 if the permissions were changed successfully.
#   - 1 if there was an error (e.g., file not found, invalid permissions).
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

# Function to display messages in console or dialog
# This function will display a message in either the console or a dialog box.
# Usage: display_message "Your message here" [display_type] [message_type]
# Parameters:
#   - message: The message to display
#   - display: The type of display (console or dialog). Default is "console".
#   - type: The type of message (info, error, success, yesno). Default is "info".
#   - If type is "yesno", it will prompt the user for a yes/no response and return 0 for yes and 1 for no.
# Example: display_message "Hello, World!" "dialog" "info"
# Example: display_message "Are you sure?" "dialog" "yesno"
function display_message {

    local message="$1"             # Message to display
    local display="${2:-console}"  #"console" or "dialog"
    local type="${3:-info}"        # Default type is "info" (can be "info", "error", "success", or "yesno")

    case "$display" in
        # Display a console message
        console)
            case "$type" in
                info) echo -e "$message"                           # Default text for info
                      wait_for_keypress #added for debugging
                      ;;
                error) echo -e "\033[31mError: $message\033[0m" ;; # Red text for errors
                success) echo -e "\033[32m$message\033[0m" ;;      # Green text for success
                yesno) echo -n -n "$message"                          # Prompt for yes/no
                    read -p " (y/n): " response
                    case "$response" in
                        [yY]) return 0 ;;
                        *) return 1 ;;
                    esac ;;          
                *) echo -e "$message" ;;                              # Default text for info
            esac ;;
        # Display a dialog message
        dialog)
            # automatically detirmine the message box size based on the message length
            local height=$(( $(echo "$message" | wc -l) + 5 ))
            local width=$(( ${#message} + 10 ))
            # for each \n add an extra line to the height
            height=$(( $height + $(echo "$message" | grep -o "\n" | wc -l) ))
            case "$type" in
                info)    dialog --infobox --backtitle "$BACKTITLE" "$message" $height $width                        # Default text for info
                         wait_for_keypress #added for debugging
                         ;;
                error)   dialog --colors --msgbox --backtitle "$BACKTITLE" "\Z1Error: $message\Zn" $height $width ;; # Red text for errors
                success) dialog --colors --msgbox --backtitle "$BACKTITLE" "\Z2$message\Zn" $height $width ;;        # Green text for success
                yesno)   dialog --yesno --backtitle "$BACKTITLE" "$message" $height $width                           # Prompt for yes/no
                         return $? 
                         ;;
                *)       dialog --colors --msgbox --backtitle "$BACKTITLE" "$message" $height $width ;;                       # Default text for info
            esac ;;
        # Handle other display types if needed
        *) echo "Invalid display type." ;;
    esac
}

# Function to wait for a keypress
# This function will wait for a single keypress from the user.
function wait_for_keypress {

    read -n 1 -s -r -p "Press any key to continue..."
}

# Function to display the status of the last command
# This function will check the exit status of the last command executed
# and display a message based on whether it was successful or not.
# Usage: dialog_status <exit_status> [<error_message>]
function dialog_status {

    # Check if the exit status is provided
    [ $1 -eq 0 ] && display_message "successful." "dialog" "success" || display_message "$2 failed." "dialog" "error"
}

# Function to check if running in a console or terminal
# This function will check if the script is running in a console or terminal.
# It will return 0 if running in a console and 1 if running in a terminal.
function set_terminal_display {

    if check_ssh; then
        # Running in a console
        BACKTITLE="Commodebian $VERSION"
    else
        # Running in a terminal
        BACKTITLE="Commodebian $VERSION (TERMINAL MODE)"
    fi
}

# function to move file to backup
# This function will create a backup of a file by moving it to a new file with a .bak extension.
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
# This function will write the provided lines to a file, creating a backup if the file already exists.
# Usage: write_file <file_path> <line1> <line2> ...
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
# This function checks if 'sudo' is installed and if the user has permission to use it.
# If 'sudo' is not available or the user does not have permission, it will return an error message.
# Usage: check_sudo
# Returns:
#   - 0 if 'sudo' is installed and the user has permission to use it.
#   - 1 if 'sudo' is not installed or the user does not have permission.
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
# This function will check if sudo is available and if the user has permission to use it.
# If sudo is not available or the user does not have permission, it will prompt for the root password and run the command using su.
# Usage: run_with_sudo <command>
# Example: run_with_sudo "apt-get update"
function run_with_sudo {

    # Check if sudo is available
    if ! check_sudo; then
        display_message "Please enter the root password to run the command." "console"
        read -s root_password
        echo
        su -c "$*" <<EOF
$root_password
EOF
        if [ $? -ne 0 ]; then
            display_message "Failed to execute the command with root privileges." $display_output "error"
            return 1
        fi
    else
        # Run the command with sudo
        sudo "$@"
    fi
    # Check if the command was successful
    if [ $? -ne 0 ]; then
        display_message "Failed to execute the command: $*" $display_output "error"
        return 1
    fi
    return 0
}

# Function to check if running as root (returns 0 if running as root, 1 if not)
function check_running_as_root {

    if [ "$(id -u)" -ne 0 ]; then
        # Not running as root
        return 1
    fi
    # Running as root
    return 0
}

# If prerequisites are not installed, use console for messages
function set_message_display {

    if check_script_prerequisites; then
        display_output="dialog"
    fi
}

# Function to list files in a directory with a specific extension
# This function will find all files with a given extension in a directory
# and return an array of options for use in a dialog menu.
# Usage: list_files "/path/to/directory" "extension" "options_array"
# Example: list_files "/usr/local/bin" "sh" "options_array"
function list_files {

    # Check if the directory and extension are provided
    local dir="$1"
    local extension="$2"
    local options=("$3")
    if [ -d "$dir" ]; then
        local files=$(find "$dir" -type f -name "*.$extension" | sort)
        local index=2
        for file in $files; do
            local name=$(basename "$file")
            options+=("$index" "  $name")
            ((index++))
        done
    else
        display_message "Directory $dir not found." "dialog" "error"
        return 1
    fi
    echo "${options[@]}"
}