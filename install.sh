#!/bin/sh -e

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'

MYBASHFOLDER="$HOME/.my-bash"

if [ ! -d "$MYBASHFOLDER" ]; then
	echo "${YELLOW}Creating my-bash directory: $MYBASHFOLDER${RC}"
	mkdir -p "$MYBASHFOLDER"
	echo "${GREEN}my-bash directory created: $MYBASHFOLDER${RC}"
fi

if [ -d "$MYBASHFOLDER" ]; then rm -rf "$MYBASHFOLDER"; fi

echo "${YELLOW}Cloning mybash repository into:$MYBASHFOLDER${RC}"
git clone https://github.com/tonytech83/my-bash "$MYBASHFOLDER"
if [ $? -eq 0 ]; then
    echo "${GREEN}Successfully cloned my-bash repository${RC}"
else
    echo "${RED}Failed to clone my-bash repository${RC}"
    exit 1
fi

# add variables to top level so can easily be accessed by all functions
PACKAGER=""
SUDO_CMD=""
SUGROUP=""
GITPATH=""

cd "$MYBASHFOLDER" || exit

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

checkEnv() {
    ## Check for requirements.
    REQUIREMENTS='curl groups sudo'
    for req in $REQUIREMENTS; do
        if ! command_exists "$req"; then
            echo "${RED}To run me, you need: $REQUIREMENTS${RC}"
            exit 1
        fi
    done

    ## Check Package Handler
    PACKAGEMANAGER='apt dnf yum pacman zypper'
    for pgm in $PACKAGEMANAGER; do
        if command_exists "$pgm"; then
            PACKAGER="$pgm"
            echo "Using $pgm"
            break
        fi
    done

    if [ -z "$PACKAGER" ]; then
        echo "${RED}Can't find a supported package manager${RC}"
        exit 1
    fi

    if command_exists sudo; then
        SUDO_CMD="sudo"
    elif command_exists doas && [ -f "/etc/doas.conf" ]; then
        SUDO_CMD="doas"
    else
        SUDO_CMD="su -c"
    fi

    echo "Using $SUDO_CMD as privilege escalation software"

    ## Check if the current directory is writable.
    GITPATH=$(dirname "$(realpath "$0")")
    if [ ! -w "$GITPATH" ]; then
        echo "${RED}Can't write to $GITPATH${RC}"
        exit 1
    fi

    ## Check SuperUser Group

    SUPERUSERGROUP='wheel sudo root'
    for sug in $SUPERUSERGROUP; do
        if groups | grep -q "$sug"; then
            SUGROUP="$sug"
            echo "Super user group $SUGROUP"
            break
        fi
    done

    ## Check if member of the sudo group.
    if ! groups | grep -q "$SUGROUP"; then
        echo "${RED}You need to be a member of the sudo group to run me!${RC}"
        exit 1
    fi
}

installDepend() {
	## Dependencies to isntall
	DEPENDENCIES='bash bash-completion tree fastfetch wget unzip fontconfig'

	echo "${YELLOW}Installing dependencies...${RC}"	
	if [ "$PACKAGER" = "pacman" ]; then
        	if ! command_exists yay && ! command_exists paru; then
            	echo "Installing yay as AUR helper..."
            	${SUDO_CMD} ${PACKAGER} --noconfirm -S base-devel
            	cd /opt && ${SUDO_CMD} git clone https://aur.archlinux.org/yay-git.git && ${SUDO_CMD} chown -R "${USER}:${USER}" ./yay-git
            	cd yay-git && makepkg --noconfirm -si
        	else
            	echo "AUR helper already installed"
        	fi
        	if command_exists yay; then
            	AUR_HELPER="yay"
        	elif command_exists paru; then
            	AUR_HELPER="paru"
        	else
            	echo "No AUR helper found. Please install yay or paru."
            	exit 1
        	fi
        	${AUR_HELPER} --noconfirm -S ${DEPENDENCIES}
    	elif [ "$PACKAGER" = "dnf" ]; then
        	${SUDO_CMD} ${PACKAGER} install -y ${DEPENDENCIES}
    	else
        	${SUDO_CMD} ${PACKAGER} install -yq ${DEPENDENCIES}
    	fi

    # Check to see if the MesloLGS Nerd Font is installed (Change this to whatever font you would like)
    FONT_NAME="JetBrainsMono"
    if fc-list :family | grep -iq "$FONT_NAME"; then
        echo "Font '$FONT_NAME' is installed."
    else
        echo "Installing font '$FONT_NAME'"
        # Change this URL to correspond with the correct font
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
        FONT_DIR="$HOME/.local/share/fonts"
        # check if the file is accessible
        if wget -q --spider "$FONT_URL"; then
            TEMP_DIR=$(mktemp -d)
            wget -q --show-progress $FONT_URL -O "$TEMP_DIR"/"${FONT_NAME}".zip
            unzip "$TEMP_DIR"/"${FONT_NAME}".zip -d "$TEMP_DIR"
            mkdir -p "$FONT_DIR"/"$FONT_NAME"
            mv "${TEMP_DIR}"/*.ttf "$FONT_DIR"/"$FONT_NAME"
            # Update the font cache
            fc-cache -fv
            # delete the files created from this
            rm -rf "${TEMP_DIR}"
            echo "'$FONT_NAME' installed successfully."
        else
            echo "Font '$FONT_NAME' not installed. Font URL is not accessible."
        fi
    fi
}

installOhMyPosh() {
	if command_exists oh-my-posh; then
        	echo "Oh My Posh already installed"
        	return
    	fi

	if ! curl -sS https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin; then
        	echo "${RED}Something went wrong during starship install!${RC}"
        	exit 1
	fi
}

installFzf() {
	if command_exists fzf; then
        	echo "Fzf already installed"
    	else
        	git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        	~/.fzf/install
    	fi
}

installZoxide() {
    if command_exists zoxide; then
        echo "Zoxide already installed"
        return
    fi

    if ! curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
        echo "${RED}Something went wrong during zoxide install!${RC}"
        exit 1
    fi
}

create_fastfetch_config() {
    ## Get the correct user home directory.
    USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
    
    if [ ! -d "$USER_HOME/.config/fastfetch" ]; then
        mkdir -p "$USER_HOME/.config/fastfetch"
    fi
    # Check if the fastfetch config file exists
    if [ -e "$USER_HOME/.config/fastfetch/config.jsonc" ]; then
        rm -f "$USER_HOME/.config/fastfetch/config.jsonc"
    fi
    ln -svf "$GITPATH/config.jsonc" "$USER_HOME/.config/fastfetch/config.jsonc" || {
        echo "${RED}Failed to create symbolic link for fastfetch config${RC}"
        exit 1
    }
}

linkConfig() {
    ## Get the correct user home directory.
    USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
    ## Check if a bashrc file is already there.
    OLD_BASHRC="$USER_HOME/.bashrc"
    if [ -e "$OLD_BASHRC" ]; then
        echo "${YELLOW}Moving old bash config file to $USER_HOME/.bashrc.bak${RC}"
        if ! mv "$OLD_BASHRC" "$USER_HOME/.bashrc.bak"; then
            echo "${RED}Can't move the old bash config file!${RC}"
            exit 1
        fi
    fi

    echo "${YELLOW}Linking new bash config file...${RC}"
    ln -svf "$GITPATH/.bashrc" "$USER_HOME/.bashrc" || {
        echo "${RED}Failed to create symbolic link for .bashrc${RC}"
        exit 1
    }
}

checkEnv
installDepend
installOhMyPosh
installFzf
installZoxide
create_fastfetch_config

if linkConfig; then
    echo "${GREEN}Done!\nrestart your shell to see the changes.${RC}"
else
    echo "${RED}Something went wrong!${RC}"
fi

