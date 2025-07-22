#!/bin/bash
LOGFILE="setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

# Colors
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

spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

handle_error() {
    error "$1"
    exit 1
}

# Prompt for sudo password once
read -rsp "Enter your sudo password: " SUDO_PASSWORD
echo

run_sudo() {
    echo "$SUDO_PASSWORD" | sudo -S "$@" || handle_error "Failed: $*"
}

section "Set Git identity"
read -rp "Enter your GitHub name: " git_name
read -rp "Enter your GitHub email: " git_email
git config --global user.name "$git_name"
git config --global user.email "$git_email"
success "GitHub identity set"

section "Updating system"
run_sudo pacman -Syu --noconfirm & spinner
success "System updated!"

section "Installing essential packages for Hyprland"
run_sudo pacman -S --noconfirm --needed\
  base-devel git wget curl zsh stow fastfetch btop less \
  bluez bluez-utils inotify-tools flatpak sof-firmware \
  hyprland hyprpaper xdg-desktop-portal-hyprland \
  network-manager-applet blueman power-profiles-daemon \
  qt5-wayland qt6-wayland qt5ct qt6ct nwg-look \
  papirus-icon-theme ttf-jetbrains-mono-nerd ttf-font-awesome \
  noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-indic-otf hyprshot cliphist rofi-wayland & spinner
success "Essential Wayland and desktop packages installed"

section "Enabling services"
run_sudo systemctl enable --now bluetooth
run_sudo systemctl enable --now reflector.timer
run_sudo systemctl enable --now paccache.timer
run_sudo systemctl enable --now power-profiles-daemon
success "Services enabled and started"

section "Installing paru (AUR helper)"
cd /tmp || handle_error "cd /tmp failed"
git clone https://aur.archlinux.org/paru.git & spinner
cd paru || handle_error "cd paru failed"
makepkg -si --noconfirm & spinner
cd ~
success "paru installed"

section "Installing AUR packages"
paru -S --noconfirm graphite-gtk-theme \
    ghostty visual-studio-code-bin \
    timeshift-autosnap wlogout & spinner
success "AUR packages installed"



section "Installing Node via nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash & spinner
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 22 & spinner
success "Node.js installed"

section "Installing pyenv"
curl -fsSL https://pyenv.run | bash & spinner
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init --path)"' >> ~/.zshrc
source ~/.zshrc
success "pyenv installed"

section "Installing zoxide"
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh & spinner
success "zoxide installed"

section "Installing Zed editor"
curl -f https://zed.dev/install.sh | sh & spinner
success "Zed installed"

section "Changing default shell to zsh"
run_sudo chsh -s "$(which zsh)" "$USER"
success "Shell changed to zsh"

section "Cloning dotfiles"
if [ ! -d ~/dotfiles ]; then
    git clone https://github.com/VijetHegde604/dotfiles.git ~/dotfiles & spinner
    success "Dotfiles cloned"
else
    warn "Dotfiles already exist, skipping clone"
fi

section "Applying dotfiles with stow"
cd ~/dotfiles || handle_error "cd ~/dotfiles failed"
stow * & spinner
success "Dotfiles applied"

section "GTK and Icon Theme Setup"
mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0

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

section "Setting Qt theme environment"
echo 'export QT_QPA_PLATFORMTHEME=qt6ct' >> ~/.zshrc
echo 'export XDG_CURRENT_DESKTOP=Hyprland' >> ~/.zshrc
echo 'export XDG_SESSION_TYPE=wayland' >> ~/.zshrc
echo 'export XDG_SESSION_DESKTOP=Hyprland' >> ~/.zshrc
success "Qt and Wayland environment variables set"

section "Setting battery charge threshold"
if [ -f /sys/class/power_supply/BAT0/charge_control_end_threshold ]; then
    cat <<EOF | sudo tee /etc/systemd/system/battery-threshold.service > /dev/null
[Unit]
Description=Set battery charge threshold
After=sysinit.target
[Service]
Type=oneshot
ExecStart=/bin/bash -c "sleep 1 && echo 80 | tee /sys/class/power_supply/BAT0/charge_control_end_threshold"
[Install]
WantedBy=multi-user.target
EOF
    run_sudo systemctl enable --now battery-threshold.service
    success "Battery charge threshold service enabled"
else
    warn "Battery control not supported"
fi

section "Installing Tailscale"
run_sudo curl -fsSL https://tailscale.com/install.sh | sh & spinner
success "Tailscale installed"

section "Cleaning up"
rm -rf /tmp/paru
success "Cleaned up temporary files"

echo -e "${green}🎉 Hyprland setup complete! Please reboot.${normal}"
