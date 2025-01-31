#!/bin/sh -e

# Define color codes for output
RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'

# Set the directory for my-bash
MYBASHFOLDER="$HOME/.my-bash"

# Check if the my-bash directory exists, if not, create it
if [ ! -d "$MYBASHFOLDER" ]; then
    echo "${YELLOW}Creating my-bash directory: $MYBASHFOLDER${RC}"
    mkdir -p "$MYBASHFOLDER"
    echo "${GREEN}my-bash directory created: $MYBASHFOLDER${RC}"
fi

# Remove the existing my-bash directory if it exists
if [ -d "$MYBASHFOLDER" ]; then rm -rf "$MYBASHFOLDER"; fi

# Clone the mybash repository into the my-bash directory
echo "${YELLOW}Cloning mybash repository into:$MYBASHFOLDER${RC}"
if git clone https://github.com/tonytech83/my-bash "$MYBASHFOLDER"; then
    echo "${GREEN}Successfully cloned my-bash repository${RC}"
else
    echo "${RED}Failed to clone my-bash repository${RC}"
    exit 1
fi

# Initialize variables for package manager, sudo command, superuser group, and git path
PACKAGER=""
SUDO_CMD=""
SUGROUP=""
GITPATH=""

# Change to the my-bash directory or exit if it fails
cd "$MYBASHFOLDER" || exit

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check the environment for necessary tools and permissions
checkEnv() {
    # Check for required commands
    REQUIREMENTS='curl groups sudo'
    for req in $REQUIREMENTS; do
        if ! command_exists "$req"; then
            echo "${RED}To run me, you need: $REQUIREMENTS${RC}"
            exit 1
        fi
    done

    # Determine the package manager to use
    PACKAGEMANAGER='apt dnf yum pacman zypper'
    for pgm in $PACKAGEMANAGER; do
        if command_exists "$pgm"; then
            PACKAGER="$pgm"
            echo "Using $pgm"
            break
        fi
    done

    # Exit if no supported package manager is found
    if [ -z "$PACKAGER" ]; then
        echo "${RED}Can't find a supported package manager${RC}"
        exit 1
    fi

    # Determine the command for privilege escalation
    if command_exists sudo; then
        SUDO_CMD="sudo"
    elif command_exists doas && [ -f "/etc/doas.conf" ]; then
        SUDO_CMD="doas"
    else
        SUDO_CMD="su -c"
    fi

    echo "Using $SUDO_CMD as privilege escalation software"

    # Check if the current directory is writable
    GITPATH=$(dirname "$(realpath "$0")")
    if [ ! -w "$GITPATH" ]; then
        echo "${RED}Can't write to $GITPATH${RC}"
        exit 1
    fi

    # Check for membership in a superuser group
    SUPERUSERGROUP='wheel sudo root'
    for sug in $SUPERUSERGROUP; do
        if groups | grep -q "$sug"; then
            SUGROUP="$sug"
            echo "Super user group $SUGROUP"
            break
        fi
    done

    # Ensure the user is a member of the superuser group
    if ! groups | grep -q "$SUGROUP"; then
        echo "${RED}You need to be a member of the sudo group to run me!${RC}"
        exit 1
    fi
}

# Function to install dependencies
installDepend() {
    # List of dependencies to install (space-separated, not quoted)
    DEPENDENCIES="bash bash-completion tree fastfetch wget unzip fontconfig"

    echo "${YELLOW}Installing dependencies...${RC}"
    
    if [ "$PACKAGER" = "pacman" ]; then
        # Install AUR helper if not present
        if ! command_exists yay && ! command_exists paru; then
            echo "Installing yay as AUR helper..."
            ${SUDO_CMD} ${PACKAGER} --noconfirm -S base-devel
            cd /opt && ${SUDO_CMD} git clone https://aur.archlinux.org/yay-git.git && ${SUDO_CMD} chown -R "${USER}:${USER}" ./yay-git
            cd yay-git && makepkg --noconfirm -si
        else
            echo "AUR helper already installed"
        fi

        # Determine which AUR helper to use
        if command_exists yay; then
            AUR_HELPER="yay"
        elif command_exists paru; then
            AUR_HELPER="paru"
        else
            echo "No AUR helper found. Please install yay or paru."
            exit 1
        fi
        "${AUR_HELPER}" --noconfirm -S ${DEPENDENCIES}

    elif [ "$PACKAGER" = "dnf" ]; then
        ${SUDO_CMD} ${PACKAGER} install -y ${DEPENDENCIES}
    else
        ${SUDO_CMD} ${PACKAGER} install -yq ${DEPENDENCIES}
    fi
}

installFont() {
    # Check if the JetBrains Nerd Font is installed
    FONT_NAME="JetBrainsMono"
    if fc-list :family | grep -iq "$FONT_NAME"; then
        echo "Font '$FONT_NAME' is installed."
    else
        echo "Installing font '$FONT_NAME'"
        # URL for the font download
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
        FONT_DIR="$HOME/.local/share/fonts"
        # Check if the font URL is accessible
        if wget -q --spider "$FONT_URL"; then
            TEMP_DIR=$(mktemp -d)
            wget -q --show-progress "$FONT_URL" -O "$TEMP_DIR"/"${FONT_NAME}".zip
            unzip "$TEMP_DIR"/"${FONT_NAME}".zip -d "$TEMP_DIR"
            mkdir -p "$FONT_DIR"/"$FONT_NAME"
            mv "${TEMP_DIR}"/*.ttf "$FONT_DIR"/"$FONT_NAME"
            # Update the font cache
            fc-cache -fv
            # Delete temporary files created for font installation
            rm -rf "${TEMP_DIR}"
            echo "'$FONT_NAME' installed successfully."
        else
            echo "Font '$FONT_NAME' not installed. Font URL is not accessible."
        fi
    fi
}

# Function to install Oh My Posh
installOhMyPosh() {
    if command_exists oh-my-posh; then
        echo "Oh My Posh already installed"
        return
    fi

    # Install Oh My Posh
    if ! curl -sS https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin; then
        echo "${RED}Something went wrong during starship install!${RC}"
        exit 1
    fi
}

# Function to install fzf
installFzf() {
    if command_exists fzf; then
        echo "Fzf already installed"
    else
        # Clone and install fzf
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install
    fi
}

# Function to install Zoxide
installZoxide() {
    if command_exists zoxide; then
        echo "Zoxide already installed"
        return
    fi

    # Install Zoxide
    if ! curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
        echo "${RED}Something went wrong during zoxide install!${RC}"
        exit 1
    fi
}

# Function to create fastfetch configuration
create_fastfetch_config() {
    # Get the correct user home directory
    USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)

    # Create fastfetch config directory if it doesn't exist
    if [ ! -d "$USER_HOME/.config/fastfetch" ]; then
        mkdir -p "$USER_HOME/.config/fastfetch"
    fi
    # Remove existing fastfetch config file if it exists
    if [ -e "$USER_HOME/.config/fastfetch/config.jsonc" ]; then
        rm -f "$USER_HOME/.config/fastfetch/config.jsonc"
    fi
    # Create a symbolic link for the fastfetch config
    ln -svf "$GITPATH/config.jsonc" "$USER_HOME/.config/fastfetch/config.jsonc" || {
        echo "${RED}Failed to create symbolic link for fastfetch config${RC}"
        exit 1
    }
}

# Function to link configuration files
linkConfig() {
    # Get the correct user home directory
    USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)

    # Check if a bashrc file is already present
    OLD_BASHRC="$USER_HOME/.bashrc"
    if [ -e "$OLD_BASHRC" ]; then
        echo "${YELLOW}Moving old bash config file to $USER_HOME/.bashrc.bak${RC}"
        if ! mv "$OLD_BASHRC" "$USER_HOME/.bashrc.bak"; then
            echo "${RED}Can't move the old bash config file!${RC}"
            exit 1
        fi
    fi

    # Link the new bash config file
    echo "${YELLOW}Linking new bash config file...${RC}"
    ln -svf "$GITPATH/.bashrc" "$USER_HOME/.bashrc" || {
        echo "${RED}Failed to create symbolic link for .bashrc${RC}"
        exit 1
    }
    # Link the Oh My Posh theme file
    ln -svf "$GITPATH/tt-thenme-1.omp.json" "$USER_HOME/.config/oh-my-posh-theme/tt-thenme-1.omp.json" || {
        echo "${RED}Failed to create symbolic link for tt-thenme-1.omp.json${RC}"
        exit 1
    }
}

# Execute the functions in order
checkEnv
installDepend
installFont
installOhMyPosh
installFzf
installZoxide
create_fastfetch_config

# Link configuration and provide feedback
if linkConfig; then
    printf "${GREEN}Done!\nRestart your shell to see the changes.${RC}\n"
else
    echo "${RED}Something went wrong!${RC}"
fi
