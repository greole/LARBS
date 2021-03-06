#!/bin/bash

# Luke's Auto Rice Boostrapping Script (LARBS)
# by Luke Smith <luke@lukesmith.xyz>
# License: GNU GPLv3

# You can provide a custom repository with -r or a custom programs csv with -p.
# Otherwise, the script will use my defaults.

### DEPENDENCIES: git and make . Make sure these are either in the progs.csv file or installed beforehand.

###
### OPTIONS AND VARIABLES ###
###

while getopts ":a:r:p:h" o; do case "${o}" in
	h) echo -e "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\\n  -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message" && exit ;;
	r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit ;;
	p) progsfile=${OPTARG} ;;
	a) aurhelper=${OPTARG} ;;
	*) echo "-$OPTARG is not a valid option." && exit ;;
esac done

# DEFAULTS:
[ -z ${dotfilesrepo+x} ] && dotfilesrepo="https://github.com/lukesmithxyz/voidrice.git"
[ -z ${progsfile+x} ] && progsfile="https://raw.githubusercontent.com/LukeSmithxyz/LARBS/master/progs.csv"
[ -z ${aurhelper+x} ] && aurhelper="yay"

###
### FUNCTIONS ###
###

initialcheck() { pacman -S --noconfirm --needed dialog || { echo "Are you sure you're running this as the root user? Are you sure you're using an Arch-based distro? ;-) Are you sure you have an internet connection?"; exit; } ;}

# preinstallmsg() { \
# 	dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit; }
# 	}

# welcomemsg() { \
# 	dialog --title "Welcome!" --msgbox "Welcome to Luke's Auto-Rice Bootstrapping Script!\\n\\nThis script will automatically install a fully-featured i3wm Arch Linux desktop, which I use as my main machine.\\n\\n-Luke" 10 60
# 	}

refreshkeys() { \
	echo "Refreshing Arch Keyring..." 4 40
	pacman --noconfirm -Sy archlinux-keyring &>/dev/null
	}

getuserandpass() { \
	# Prompts user for new username an password.
	# Checks if username is valid and confirms passwd.
	name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit
	namere="^[a-z_][a-z0-9_-]*$"
	while ! [[ "${name}" =~ ${namere} ]]; do
		name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [[ ${pass1} == ${pass2} ]]; do
		unset pass2
		pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done ;}

usercheck() { \
	! (id -u $name &>/dev/null) ||
	dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists on this system. LARBS can install for a user already existing, but it will \\Zboverwrite\\Zn any conflicting settings/dotfiles on the user account.\\n\\nLARBS will \\Zbnot\\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that LARBS will change $name's password to the one you just gave." 14 70
	}

adduserandpass() { \
	# Adds user `$name` with password $pass1.
	echo "Adding user \"$name\"..." 4 50
	useradd -m -g wheel -s /bin/bash "$name" &>/dev/null ||
	usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2 ;}

gitclone() {
	#$(mktemp -d)
	dir=/home/go/data/code
	# dialog --title "LARBS Installation" --infobox "Installing \`$(basename $1)\` ($n of $total) via \`git\` and \`make\`. $(basename $1) $2." 5 70
	cd "$dir" || exit
    git clone --depth 1 "$1" $dir/$(basename $1);}

gitclonecmake() {
	gitclone $1 $2
    dir=/home/go/data/code/$(basename $1)
    mkdir $dir/build
    cd $dir/build
    cmake .. $2
    make
    sudo make install;}

maininstall() { # Installs all needed programs from main repo.
	# dialog --title "LARBS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2." 5 70
	sudo pacman --noconfirm --needed -S "$1"
	}

aurinstall() { \
	# dialog --title "LARBS Installation" --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2." 5 70
    echo "Installing $1"
	grep "^$1$" <<< "$aurinstalled" && return
	sudo -u go yaourt -S --noconfirm "$1" 
	}

installationloop() { \
	# ([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" > /tmp/progs.csv
    cp progs.csv /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	aurinstalled=$(pacman -Qm | awk '{print $1}')
	while IFS=, read -r tag program comment; do
	n=$((n+1))
	case "$tag" in
	"") maininstall "$program" "$comment" ;;
	"A") aurinstall "$program" "$comment" ;;
	"G") gitclone "$program" "$comment" ;;
	"GC") gitclonecmake "$program" "$comment" ;;
	esac
	done < /tmp/progs.csv ;}

serviceinit() { for service in "$@"; do
	echo "Enabling \"$service\"..." 4 40
	systemctl enable "$service"
	systemctl start "$service"
	done ;}

newperms() { # Set special sudoers settings for install (or after).
	sed -i "/#LARBS/d" /etc/sudoers
	echo -e "$@ #LARBS" >> /etc/sudoers ;}

systembeepoff() { echo "Getting rid of that retarded error beep sound..." 10 50
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;}

putgitrepo() { # Downlods a gitrepo $1 and places the files in $2 only overwriting conflicts
	echo "Downloading and installing config files..." 4 60
	dir=$(mktemp -d)
	chown -R "$name":wheel "$dir"
	sudo -u "$name" git clone --depth 1 "$1" "$dir"/gitrepo &>/dev/null &&
	sudo -u "$name" mkdir -p "$2" &&
	sudo -u "$name" cp -rT "$dir"/gitrepo "$2"
	}

resetpulse() { echo "Reseting Pulseaudio..." 4 50
	killall pulseaudio
	sudo -n "$name" pulseaudio --start ;}

preinstall() {
	mkdir -p $HOME/data/code
    sudo sed -i "s/#en_GB.UTF-8/en_GB.UTF-8/g" /etc/locale.gen
    sudo locale-gen
}

postinstall() {
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
	sudo chsh -s /bin/zsh go
	# Link dotfiles
	ln -s /home/go/data/Configs/dotfiles/zshrc /home/go/.zshrc
	ln -s /home/go/data/Configs/dotfiles/vimrc /home/go/.vimrc
	ln -s /home/go/data/Configs/dotfiles/tmux.conf /home/go/.tmux.conf
	cd /tmp
	curl https://raw.githubusercontent.com/Shougo/neobundle.vim/master/bin/install.sh > install.sh
	sh ./install.sh
}

manualinstall() { # Installs $1 manually if not installed. Used only for AUR helper here.
	[[ -f /usr/bin/$1 ]] || (
	echo "Installing \"$1\", an AUR helper..."
	cd /tmp
	rm -rf /tmp/"$1"*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"$1".tar.gz &&
	sudo -u "$name" tar -xvf "$1".tar.gz &>/dev/null &&
	cd "$1" &&
	sudo -u $name makepkg --noconfirm -si &>/dev/null
	cd /tmp) ;}

finalize(){ \
	echo "Preparing welcome message..."
	echo "exec_always --no-startup-id notify-send -i ~/.scripts/larbs.png '<b>Welcome to LARBS:</b> Press Super+F1 for the manual.' -t 10000"  >> /home/$name/.config/i3/config
	# dialog --title "All done!" --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment.\\n\\n-Luke" 12 80
	}

###
### THE ACTUAL SCRIPT ###
###
### This is how everything happens in an intuitive format and order.
###

### TODO:
### 	* Import gpg and ssh keys
###	* offline imap crontab
###	* setup zsh
###     * setup rcs

# Check if user is root on Arch distro. Install dialog.
# initialcheck

# Welcome user.
# welcomemsg || { clear; exit; }

# Get and verify username and password.
# getuserandpass

# Give warning if user already exists.
# usercheck || { clear; exit; }

# Last chance for user to back out before install.
# preinstallmsg || { clear; exit; }
preinstall

### The rest of the script requires no user input.

#adduserandpass

# Refresh Arch keyrings.
refreshkeys

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

manualinstall $aurhelper

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop

# Install the dotfiles in the user's home directory
putgitrepo "$dotfilesrepo" "/home/$name"

# Install the LARBS Firefox profile in ~/.mozilla/firefox/
putgitrepo "https://github.com/LukeSmithxyz/mozillarbs.git" "/home/$name/.mozilla/firefox"

# Pulseaudio, if/when initially installed, often needs a restart to work immediately.
[[ -f /usr/bin/pulseaudio ]] && resetpulse

# Enable services here.
sudo serviceinit cronie

# Most important command! Get rid of the beep!
systembeepoff

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
newperms "%wheel ALL=(ALL) ALL\\n%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/yay"

# Make pacman and yay colorful because why not.
sed -i "s/^#Color/Color/g" /etc/pacman.conf

# Last message! Install complete!
finalize
clear
postinstall
