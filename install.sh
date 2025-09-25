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
section() { echo -e "${purple}\n====== 🚀 $1 ======${normal}"; }

# === PROGRESS INDICATOR ===
run_task() {
    local cmd="$*"
    local msg="${cyan}⏳ Running:${normal} $cmd"
    echo "$msg"
    {
        eval "$cmd"
    } &
    pid=$!

    i=0
    while kill -0 $pid 2>/dev/null; do
        dots=$(printf ".%.0s" $(seq 1 $((i%4))))
        printf "\r${cyan}   Working$dots   ${normal}"
        sleep 0.5
        ((i++))
    done
    wait $pid
    rc=$?
    printf "\r"
    return $rc
}

handle_error() {
    error "$1"
    exit 1
}

# === SUDO SESSION ===
section "Validating sudo"
sudo -v || handle_error "Sudo validation failed"

# === GIT CONFIG ===
section "Set Git identity"
read -rp "Enter your GitHub name: " git_name
read -rp "Enter your GitHub email: " git_email
git config --global user.name "$git_name"
git config --global user.email "$git_email"
git config --global credential.helper libsecret
git config --global init.defaultBranch main
success "Git identity configured"

# === UPDATE SYSTEM ===
section "Updating system"
run_task sudo pacman -Syu --noconfirm || handle_error "System update failed"
success "System updated"

# === ESSENTIAL PACKAGES ===
section "Installing core packages"
run_task sudo pacman -S --noconfirm --needed \
    base-devel git wget curl zsh stow fastfetch btop less \
    bluez bluez-utils inotify-tools flatpak sof-firmware \
    hyprland hyprpaper xdg-desktop-portal-hyprland \
    network-manager-applet blueman power-profiles-daemon \
    qt5-wayland qt6-wayland qt5ct qt6ct nwg-look \
    papirus-icon-theme ttf-jetbrains-mono-nerd ttf-font-awesome \
    noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-indic-otf \
    hyprshot cliphist rofi-wayland reflector timeshift pacman-contrib \
    pavucontrol thunar libsecret hyprlock hypridle xdg-user-dirs brightnessctl \
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-afc gvfs-smb \
    unzip zip tar rsync neofetch fzf ripgrep
success "Core Wayland and desktop packages installed"

# === SERVICES ===
section "Enabling services"
sudo systemctl enable --now bluetooth reflector.timer paccache.timer power-profiles-daemon
success "Services enabled"

# === PARU INSTALL ===
section "Installing paru (AUR helper)"
if ! command -v paru &>/dev/null; then
    cd /tmp || handle_error "cd /tmp failed"
    git clone https://aur.archlinux.org/paru.git
    cd paru || handle_error "cd paru failed"
    run_task makepkg -si --noconfirm || handle_error "paru install failed"
    cd ~
    success "paru installed"
else
    warn "paru already installed"
fi

# === AUR PACKAGES ===
section "Installing AUR packages"
run_task paru -S --noconfirm google-chrome ghostty \
    visual-studio-code-bin timeshift-autosnap wlogout
success "AUR packages installed"

# === NODEJS via NVM ===
section "Installing Node.js (nvm)"
run_task curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
run_task nvm install 22
success "Node.js installed"

# === PYENV ===
section "Installing pyenv"
run_task curl -fsSL https://pyenv.run | bash
{
    echo 'export PYENV_ROOT="$HOME/.pyenv"'
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"'
    echo 'eval "$(pyenv init --path)"'
} >> ~/.zshrc
success "pyenv installed"

# === ZOXIDE ===
section "Installing zoxide"
run_task curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
success "zoxide installed"

# === ZED ===
section "Installing Zed editor"
run_task curl -f https://zed.dev/install.sh | sh
success "Zed installed"

# === ZSH DEFAULT ===
section "Changing default shell"
if [ "$SHELL" != "$(which zsh)" ]; then
    sudo chsh -s "$(which zsh)" "$USER"
    success "Default shell changed to zsh"
else
    warn "Already using zsh"
fi

# === DOTFILES ===
section "Dotfiles setup"
if [ ! -d ~/dotfiles ]; then
    run_task git clone https://github.com/VijetHegde604/dotfiles.git ~/dotfiles
    success "Dotfiles cloned"
else
    warn "Dotfiles already exist"
fi

cd ~/dotfiles || handle_error "cd dotfiles failed"
[ -d ~/.config/hypr ] && mv ~/.config/hypr ~/.config/hypr.bak
[ -d ~/.config/kitty ] && mv ~/.config/kitty ~/.config/kitty.bak
mkdir -p ~/.config/waybar

for pkg in hypr waybar kitty wlogout; do
    run_task stow -d ~/dotfiles -t ~ "$pkg"
done
success "Dotfiles applied"

# === THEMES ===
section "GTK + Icons"
cd /tmp
git clone https://github.com/vinceliuice/Graphite-gtk-theme.git
cd Graphite-gtk-theme || handle_error "Graphite theme clone failed"
./install.sh -c dark -s compact -l --tweaks black rimless
cat > ~/.config/gtk-3.0/settings.ini <<EOF
[Settings]
gtk-theme-name=Graphite-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono Nerd Font 10
EOF
cp ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini
success "GTK theme applied"

# === QT ENV VARS ===
section "Setting Qt env vars"
{
echo 'export QT_QPA_PLATFORMTHEME=qt6ct'
echo 'export XDG_CURRENT_DESKTOP=Hyprland'
echo 'export XDG_SESSION_TYPE=wayland'
echo 'export XDG_SESSION_DESKTOP=Hyprland'
} >> ~/.zshrc
success "Qt env vars set"

# === BATTERY ===
section "Battery threshold"
if [ -f /sys/class/power_supply/BAT0/charge_control_end_threshold ]; then
    cat <<EOF | sudo tee /etc/systemd/system/battery-threshold.service >/dev/null
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
    success "Battery threshold set to 80%"
else
    warn "Battery control not supported"
fi

# === TAILSCALE ===
section "Installing Tailscale"
run_task curl -fsSL https://tailscale.com/install.sh | sh
success "Tailscale installed"

# === CLEANUP ===
section "Cleanup"
rm -rf /tmp/paru /tmp/Graphite-gtk-theme
success "Temporary files removed"

# === DONE ===
echo -e "${green}🎉 Hyprland setup complete! Please reboot.${normal}"
