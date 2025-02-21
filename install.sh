#!/bin/bash

# Resources
# https://linuxize.com/post/bash-functions/
# https://www.pluralsight.com/resources/blog/cloud/conditions-in-bash-scripting-if-statements
# https://opensource.com/article/18/5/you-dont-know-bash-intro-bash-arrays
# https://www.gnu.org/software/bash/manual/html_node/Arrays.html

dotpath=`pwd`

# Utility functions
stage () {  
  # https://dev.to/ifenna__/adding-colors-to-bash-scripts-48g4
  echo -e "\e[32m========== $@ ==========\e[0m"
}

pkgs=()
pkg () {
    # https://stackoverflow.com/a/23585994
    for value in "$@"; do
	pkgs+=($value)
    done
}

reg=~/.installedpackages
flush () {
    # Delete duplicates
    pkgs=(`echo ${pkgs[@]} | tr ' ' '\n' | sort | uniq`)
    
    if ! [ -f $reg ]; then
	# First time running install.sh
	stage "Installing ${pkgs[@]}"
        sudo apt install ${pkgs[@]} && echo "${pkgs[@]} " > $reg
    else
	# Read contents of $reg and put it into an array
	# https://www.tpointtech.com/bash-read-file
	oldpkgs=()
	while read -d " " word; do  
	    oldpkgs+=($word)
	done < $reg

	# The old contents of the file aren't needed anymore
	echo "${pkgs[@]} " > $reg

	# Get the difference between them
	# https://stackoverflow.com/questions/2312762/compare-difference-of-two-arrays-in-bash#comment78031743_28161520
	newpkgs=(`echo ${oldpkgs[@]} ${oldpkgs[@]} ${pkgs[@]} | tr ' ' '\n' | sort | uniq -u `) # packages to install
	rmpkgs=(`echo ${oldpkgs[@]} ${pkgs[@]} ${pkgs[@]} | tr ' ' '\n' | sort | uniq -u `) # packages to remove

	# Install packages
	# https://serverfault.com/a/924549
	if (( ${#newpkgs[@]} )); then
	    stage "Installing ${newpkgs[@]}"
	    sudo apt install ${newpkgs[@]}
	fi

	# Remove packages
	if (( ${#rmpkgs[@]} )); then
	    stage "Removing ${rmpkgs[@]}"
	    sudo apt remove ${rmpkgs[@]}
	    sudo apt autoremove
            sudo apt autopurge
            sudo apt autoclean
	fi
    fi
    stage "Upgrading packages"
    sudo apt upgrade || ( sudo apt-get update; sudo apt upgrade)
}

# Packages go here
pkg stow git emacs torbrowser-launcher okular lmms # General purpose
pkg autoconf texinfo libgtk-3-dev libgif-dev libxpm-dev libgnutls28-dev libncurses-dev libmagickwand-dev libtree-sitter-dev # for compiling Emacs
flush

# Emacs config
emacsdir=~/.emacs.d
emacsdot="$dotpath/emacs"
mkdir -p $emacsdir
if ! [ -f $emacsdir/init.org ]; then
    stage "Adding Emacs config"

    # Tangle init.org
    emacs --batch --file $emacsdot/init.org --eval "(progn (require 'ob-tangle) (org-babel-tangle))"
    
    # https://www.cyberciti.biz/faq/creating-hard-links-with-ln-command/
    ln $emacsdot/init.org $emacsdir/init.org
    ln $emacsdot/init.el $emacsdir/init.el
    ln $emacsdot/early-init.el $emacsdir/early-init.el
fi

# Keyd config
if ! which -s keyd; then
    # https://stackoverflow.com/a/4632032
    stage "Installing keyd"
    keyddir=`mktemp -d`
    cd $keyddir

    # Clone repository, compile and install
    git clone --depth=1 https://github.com/rvaiya/keyd.git
    cd keyd
    make && sudo make install

    # Add config and enable the systemd keyd service
    sudo mkdir -p /etc/keyd/
    sudo stow -S -t /etc/keyd -d $dotpath/keyd .
    sudo systemctl enable --now keyd

    # Go back and remove temp files
    cd $dotpath
    rm -r -f $keyddir
fi

# Joplin
JOPLIN_INSTALL_DIR="${HOME}/.joplin"
JOPLIN_RUN_SCRIPT=false

if [ -f "${JOPLIN_INSTALL_DIR}/VERSION" ]; then
    # Stolen from Joplin's script
    JOPLIN_RELEASE_VERSION=$(wget -qO - "https://api.github.com/repos/laurent22/joplin/releases/latest" | grep -Po '"tag_name": ?"v\K.*?(?=")')
    if [[ $(< "${JOPLIN_INSTALL_DIR}/VERSION") != "${JOPLIN_RELEASE_VERSION}" ]]; then
	JOPLIN_RUN_SCRIPT=true
	stage "Updating Joplin"
    fi
else
    JOPLIN_RUN_SCRIPT=true
    stage "Installing Joplin"
fi

if [[ "${JOPLIN_RUN_SCRIPT}" == true ]]; then
    wget -O - https://raw.githubusercontent.com/laurent22/joplin/dev/Joplin_install_and_update.sh | bash --install-dir "${JOPLIN_INSTALL_DIR}"
fi
