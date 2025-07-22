#!/bin/bash
LOGFILE="setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

# === COLORS ===
bold=$(tput bold)
normal=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
cyan=$(tput setaf 6)
purple=$(tput setaf 5)

info()    { echo "${cyan}ℹ️ $1${normal}"; }
success() { echo "${green}✅ $1${normal}"; }
warn()    { echo "${yellow}⚠️ $1${normal}"; }
error()   { echo "${red}❌ $1${normal}"; }
section() { echo "${purple}\n====== 🚀 $1 ======${normal}"; }

# === SPINNER ===
run_with_spinner() {
    "$@" &
    pid=$!
    delay=0.1
    spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        printf " [%c]  " "$spinstr"
        spinstr=${spinstr#?}${spinstr%"$spinstr"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    wait $pid
}

handle_error() {
    error "$1"
    exit 1
}

# === SUDO SESSION ===
section "Validating sudo"
sudo -v || handle_error "Sudo validation failed"

# === GIT SETUP ===
section "Set Git identity"
read -rp "Enter your GitHub name: " git_name
read -rp "Enter your GitHub email: " git_email
git config --global user.name "$git_name"
git config --global user.email "$git_email"
git config --global credential.helper libsecret
git config --global init.defaultBranch main
success "GitHub identity set"

# === UPDATE SYSTEM ===
section "Updating system"
run_with_spinner sudo pacman -Syu --noconfirm
success "System updated"

# === INSTALL ESSENTIAL PACKAGES ===
section "Installing essential packages for Hyprland"
run_with_spinner sudo pacman -S --noconfirm --needed \
    base-devel git wget curl zsh stow fastfetch btop less \
    bluez bluez-utils inotify-tools flatpak sof-firmware \
    hyprland hyprpaper xdg-desktop-portal-hyprland \
    network-manager-applet blueman power-profiles-daemon \
    qt5-wayland qt6-wayland qt5ct qt6ct nwg-look \
    papirus-icon-theme ttf-jetbrains-mono-nerd ttf-font-awesome \
    noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-indic-otf \
    hyprshot cliphist rofi-wayland reflector timeshift pacman-contrib \
    pavucontrol thunar libsecret
success "Essential Wayland and desktop packages installed"

# === SERVICES ===
section "Enabling services"
sudo systemctl enable --now bluetooth
sudo systemctl enable --now reflector.timer
sudo systemctl enable --now paccache.timer
sudo systemctl enable --now power-profiles-daemon
success "Services enabled and started"

# === PARU INSTALL ===
section "Installing paru (AUR helper)"
cd /tmp || handle_error "cd /tmp failed"
git clone https://aur.archlinux.org/paru.git || handle_error "Failed to clone paru"
cd paru || handle_error "cd paru failed"
run_with_spinner makepkg -si --noconfirm
cd ~
success "paru installed"

# === AUR PACKAGES ===
section "Installing AUR packages"
run_with_spinner paru -S --noconfirm graphite-gtk-theme ghostty \
    visual-studio-code-bin timeshift-autosnap wlogout
success "AUR packages installed"

# === NODEJS ===
section "Installing Node via nvm"
run_with_spinner curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
run_with_spinner nvm install 22
success "Node.js installed"

# === PYENV ===
section "Installing pyenv"
run_with_spinner curl -fsSL https://pyenv.run | bash
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init --path)"' >> ~/.zshrc
source ~/.zshrc
success "pyenv installed"

# === ZOXIDE ===
section "Installing zoxide"
run_with_spinner curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
success "zoxide installed"

# === ZED ===
section "Installing Zed editor"
run_with_spinner curl -f https://zed.dev/install.sh | sh
success "Zed installed"

# === ZSH DEFAULT ===
section "Changing default shell to zsh"
sudo chsh -s "$(which zsh)" "$USER"
success "Shell changed to zsh"

# === DOTFILES ===
section "Cloning dotfiles"
if [ ! -d ~/dotfiles ]; then
    run_with_spinner git clone https://github.com/VijetHegde604/dotfiles.git ~/dotfiles
    success "Dotfiles cloned"
else
    warn "Dotfiles already exist, skipping clone"
fi

section "Applying dotfiles with stow"
cd ~/dotfiles || handle_error "cd ~/dotfiles failed"
[ -d ~/.config/hypr ] && mv ~/.config/hypr ~/.config/hypr.bak
[ -d ~/.config/kitty ] && mv ~/.config/kitty ~/.config/kitty.bak
mkdir -p ~/.config/waybar

run_with_spinner stow -d ~/dotfiles -t ~ hypr
run_with_spinner stow -d ~/dotfiles -t ~ waybar
run_with_spinner stow -d ~/dotfiles -t ~ kitty
success "Dotfiles applied"

# === GTK THEME ===
section "GTK and Icon Theme Setup"
mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0

cd /tmp
git clone https://github.com/vinceliuice/Graphite-gtk-theme.git
cd Graphite-gtk-theme || handle_error "Failed to clone Graphite theme"
./install.sh -c dark -s compact -s standard -l --tweaks black rimless || handle_error "Graphite theme install failed"

cat > ~/.config/gtk-3.0/settings.ini <<EOF
[Settings]
gtk-theme-name=Graphite-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono Nerd Font 10
EOF

cp ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini

if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme "Graphite-Dark"
    gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
    gsettings set org.gnome.desktop.interface font-name "JetBrainsMono Nerd Font 10"
fi
success "GTK and icon theme applied"

# === QT ENV VARS ===
section "Setting Qt theme environment"
{
echo 'export QT_QPA_PLATFORMTHEME=qt6ct'
echo 'export XDG_CURRENT_DESKTOP=Hyprland'
echo 'export XDG_SESSION_TYPE=wayland'
echo 'export XDG_SESSION_DESKTOP=Hyprland'
} >> ~/.zshrc
success "Qt and Wayland environment variables set"

# === BATTERY THRESHOLD ===
section "Setting battery charge threshold"
if [ -f /sys/class/power_supply/BAT0/charge_control_end_threshold ]; then
    cat <<EOF | sudo tee /etc/systemd/system/battery-threshold.service > /dev/null
[Unit]
Description=Set battery charge threshold
After=sysinit.target
[Service]
Type=oneshot
ExecStart=/bin/bash -c "sleep 1 && echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold"
[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl enable --now battery-threshold.service
    success "Battery charge threshold service enabled"
else
    warn "Battery control not supported"
fi

# === TAILSCALE ===
section "Installing Tailscale"
run_with_spinner curl -fsSL https://tailscale.com/install.sh | sh
success "Tailscale installed"

# === CLEANUP ===
section "Cleaning up"

read -rp "Remove optional packages (dolphin wofi grim slurp)? [y/N]: " response
if [[ $response =~ ^[Yy]$ ]]; then
    sudo pacman -Rns --noconfirm dolphin wofi grim slurp
    success "Optional packages removed"
else
    warn "Skipped optional package removal"
fi

rm -rf /tmp/paru /tmp/Graphite-gtk-theme

success "Cleaned up temporary files"

# === DONE ===
echo -e "${green}🎉 Hyprland setup complete! Please reboot.${normal}"
