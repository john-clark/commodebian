#!/bin/bash
# filepath: commodebian/functions/menu.sh
# Menu-related functions

# Make sure this was called from the main script
if [[ -z "$COMMODORE" ]]; then
    echo "This script is not meant to be run directly."
    return 1
fi

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
            x) clear; safe_exit 0 ;;
        esac
    done
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
            *) clear; show_main_menu; safe_exit 0 ;;
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
    
    # Use the list_files helper function to populate the options
    OPTIONS=($(list_files "$DISK_DIR" "d64" "${OPTIONS[@]}"))
    if [ $? -ne 0 ]; then
        # If the directory is not found or no files are present, display an error message
        display_message "Disk directory not found or no disk files available." "dialog" "error"
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
                    safe_exit 0
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

    # Use the list_files helper function to populate the options
    OPTIONS=($(list_files "$CART_DIR" "crt" "${OPTIONS[@]}"))
    if [ $? -ne 0 ]; then
        # If the directory is not found or no files are present, display an error message
        display_message "Cartridge directory not found or no disk files available." "dialog" "error"
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
                    safe_exit 0
                fi
                SELECTED_CART=$(echo "$CART_FILES" | sed -n "$((CHOICE - 1))p")
                change_config "CRT" "$SELECTED_CART"
                ;;
        esac
    done
}

# Function to display the installation menu
function show_install_menu {

    # check if prerequisites are installed
    check_script_prerequisites

    HEIGHT=20
    WIDTH=50
    CHOICE_HEIGHT=14
    TITLE="Commodebian Installer Menu"
    MENU="Use arrow keys to move through options"

    OPTIONS=(
            "" " Return to main menu"
            "" ""
            ""  "  This will install the necessary components for Commodebian."
            ""  "  Choose an option below to proceed."
            ""  ""
            1   "  Install Vice Emulator"
            2   "  Install User Profile Changes"
            3   "  Install TCPSer"
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
            1) show_install_vice_menu ;;
            2) show_install_profile_menu ;;
            3) show_tcpser_menu ;;
            *) 
                # If the user selects the return option or presses cancel
                if [ -z "$CHOICE" ]; then
                    clear
                    show_main_menu
                    safe_exit 0
                fi
                # If the user selects an invalid option, just return to the main menu
                display_message "Invalid option selected." "dialog" "error"
                ;;
        esac
    done
}

# Function to display the install menu
function show_install_profile_menu {

    # check if prerequisites are installed
    check_script_prerequisites

    HEIGHT=20
    WIDTH=50
    CHOICE_HEIGHT=14
    TITLE="Commodebian Installer Menu"
    MENU="Use arrow keys to move through options"
    
    OPTIONS=(
            "" " Return to main menu"
            "" ""
            ""  "  This will setup the user profile"
            ""  "  to start the emulator on boot." 
            ""  ""
            1   "  Install autostart"
            2   "  Remove autostart"
            3   "  Edit user profile"
            ""  ""
            ""  " Install autologin for the user"
            ""  ""
            4   "  Install autologin"
            5   "  Remove autologin"
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
            1) install_autostart ;;
            2) remove_autostart ;;
            3) edit_user_profile ;;
            4) install_autologin ;;
            5) remove_autologin ;;
            *) 
                # If the user selects the return option or presses cancel
                if [ -z "$CHOICE" ]; then
                    clear
                    show_main_menu
                    safe_exit 0
                fi
                # If the user selects an invalid option, just return to the main menu
                display_message "Invalid option selected." "dialog" "error"
                ;;
        esac
    done
}

# Function to display the install menu
function show_install_vice_menu {

    # check if prerequisites are installed
    check_script_prerequisites

    HEIGHT=20
    WIDTH=50
    CHOICE_HEIGHT=14
    TITLE="Commodebian Installer Menu"
    MENU="Use arrow keys to move through options"
    
    OPTIONS=(
            1  "  Install dependencies  "
            2  "  Edit dependencies  "
            3  "  Download Vice  "
            4  "  Extract Vice  "
            5  "  Build Vice  "
            6  "  Install Vice  "
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
            1) install_vice_dependencies ;;
            2) edit_dependencies ;;
            3) download_vice ;;
            4) extract_vice ;;
            5) build_vice ;;
            6) install_vice ;;
            *) 
                # If the user selects the return option or presses cancel
                if [ -z "$CHOICE" ]; then
                    clear
                    show_main_menu
                    safe_exit 0
                fi
                # If the user selects an invalid option, just return to the main menu
                display_message "Invalid option selected." "dialog" "error"
                ;;
        esac
    done
}

# Function to display the tcpser menu
function show_tcpser_menu {

    WIDTH=90
    CHOICE_HEIGHT=35
    TITLE="TCPSER MENU"
    MENU="Use arrow keys to move through options"

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
            *)  clear; show_main_menu; safe_exit 0 ;;
        esac
    done
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