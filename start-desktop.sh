#!/usr/bin/env bash
# ==============================================================================
# VPS Desktop - Auto Setup: XFCE + noVNC + Chrome + FB Manager Extension
# Repo: synd27601-ui/vps-desktop
# Chay tu dong moi khi Codespace khoi dong (postStartCommand)
# ==============================================================================

EXT_URL="https://synd-fb-automation-manager.vercel.app/api/extension/download"
EXT_DIR="$HOME/.chrome-extensions/fb-manager"
CHROME_FLAGS="--no-sandbox --disable-dev-shm-usage --no-first-run --no-default-browser-check --password-store=basic"

# ==============================================================================
# 1. Cài đặt XFCE Desktop + VNC + noVNC (chỉ lần đầu tiên)
# ==============================================================================
if ! command -v vncserver >/dev/null 2>&1; then
  echo "[1/6] Đang cài đặt XFCE4, TigerVNC, noVNC..."
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 xfce4-goodies tigervnc-standalone-server tigervnc-common \
    novnc websockify dbus-x11 wget curl unzip
fi

# ==============================================================================
# 2. Cài đặt Google Chrome (chỉ lần đầu tiên)
# ==============================================================================
if ! command -v google-chrome-stable >/dev/null 2>&1; then
  echo "[2/6] Đang cài đặt Google Chrome..."
  wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo apt-get install -y ./google-chrome-stable_current_amd64.deb || sudo apt-get -f install -y
  rm -f google-chrome-stable_current_amd64.deb
fi

# Đảm bảo có unzip
if ! command -v unzip >/dev/null 2>&1; then
  sudo apt-get install -y unzip
fi

# ==============================================================================
# 3. Tải / kiểm tra FB Manager Extension
# ==============================================================================
echo "[3/6] Đang tải / kiểm tra FB Manager Extension..."
mkdir -p "$EXT_DIR"
if [ ! -f "$EXT_DIR/manifest.json" ]; then
  wget -q -O /tmp/fb-manager-ext.zip "$EXT_URL" 2>/dev/null
  if [ -f /tmp/fb-manager-ext.zip ] && [ "$(stat -c%s /tmp/fb-manager-ext.zip 2>/dev/null || echo 0)" -gt 1000 ]; then
    unzip -o /tmp/fb-manager-ext.zip -d "$EXT_DIR" >/dev/null 2>&1
    echo "    -> Extension đã cài đặt tại: $EXT_DIR"
  fi
  rm -f /tmp/fb-manager-ext.zip
else
  echo "    -> Extension đã có sẵn."
fi

# ==============================================================================
# 4. Cấu hình VNC + Chrome Developer Mode + Keyring bypass
# ==============================================================================
echo "[4/6] Đang cấu hình môi trường..."

# VNC xstartup
mkdir -p "$HOME/.vnc"
cat << 'EOF' > "$HOME/.vnc/xstartup"
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export DISPLAY=:1
exec startxfce4
EOF
chmod +x "$HOME/.vnc/xstartup"

# Chrome Developer Mode = ON + triệt tiêu Keyring popup
pkill -f gnome-keyring-daemon 2>/dev/null || true
rm -rf ~/.local/share/keyrings/* 2>/dev/null || true

CHROME_DIR="$HOME/.config/google-chrome/Default"
mkdir -p "$CHROME_DIR"
PREFS_FILE="$CHROME_DIR/Preferences"

if [ ! -f "$PREFS_FILE" ] || [ ! -s "$PREFS_FILE" ]; then
  cat << 'EOF' > "$PREFS_FILE"
{
  "extensions": {
    "ui": {
      "developer_mode": true
    }
  },
  "browser": {
    "has_seen_welcome_page": true,
    "check_default_browser": false
  },
  "bookmark_bar": {
    "show_on_all_tabs": true
  }
}
EOF
else
  python3 -c "
import json
p = '$PREFS_FILE'
try:
    with open(p) as f: d = json.load(f)
except: d = {}
d.setdefault('extensions', {}).setdefault('ui', {})['developer_mode'] = True
d.setdefault('browser', {})['has_seen_welcome_page'] = True
d.setdefault('browser', {})['check_default_browser'] = False
with open(p, 'w') as f: json.dump(d, f, indent=2)
" 2>/dev/null || true
fi

# Chrome Policy: DevTools luôn bật
sudo mkdir -p /etc/opt/chrome/policies/managed
sudo tee /etc/opt/chrome/policies/managed/vps-devmode.json > /dev/null << 'POLICY'
{
  "DeveloperToolsAvailability": 1,
  "ExtensionInstallAllowlist": ["*"],
  "BookmarkBarEnabled": true
}
POLICY

# XFCE Autostart cho Chrome (mở Chrome khi Desktop XFCE khởi động)
mkdir -p "$HOME/.config/autostart"
cat << EOF > "$HOME/.config/autostart/google-chrome.desktop"
[Desktop Entry]
Type=Application
Exec=google-chrome-stable $CHROME_FLAGS --load-extension=$EXT_DIR
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Google Chrome
EOF

# Desktop shortcut
mkdir -p "$HOME/.local/share/applications" "$HOME/Desktop"
cat << EOF > "$HOME/.local/share/applications/google-chrome.desktop"
[Desktop Entry]
Version=1.0
Name=Google Chrome
Exec=google-chrome-stable $CHROME_FLAGS --load-extension=$EXT_DIR %U
Terminal=false
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
EOF
cp "$HOME/.local/share/applications/google-chrome.desktop" "$HOME/Desktop/" 2>/dev/null || true
chmod +x "$HOME/Desktop/google-chrome.desktop" 2>/dev/null || true

# ==============================================================================
# 5. Khởi động VNC + noVNC (Dọn dẹp triệt để lock cũ và chạy nền an toàn)
# ==============================================================================
echo "[5/6] Đang khởi động Desktop noVNC..."

# Dọn dẹp triệt để lock file cũ và tiến trình zombie khi Codespace vừa thức dậy
vncserver -kill :1 2>/dev/null || true
pkill -9 -f "websockify" 2>/dev/null || true
pkill -9 -f "Xtigervnc.*:1" 2>/dev/null || true
sudo rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 "$HOME/.vnc/"*.pid "$HOME/.vnc/"*.log 2>/dev/null || true
sleep 1

# Khởi động TigerVNC trên display :1
vncserver :1 -localhost yes -SecurityTypes None -geometry 1366x768 -depth 24
sleep 2

# Khởi động websockify độc lập hoàn toàn bằng nohup và chuyển giao ra nền
nohup websockify --web=/usr/share/novnc/ 6080 localhost:5901 </dev/null >/tmp/websockify.log 2>&1 &
sleep 2

# Đảm bảo port 6080 luôn public
gh codespace ports visibility 6080:public -c "$CODESPACE_NAME" 2>/dev/null || true

# ==============================================================================
# 6. Khởi chạy Chrome với Extension
# ==============================================================================
echo "[6/6] Đang khởi động Chrome + FB Manager Extension..."

if ! pgrep -f "chrome" >/dev/null 2>&1; then
  DISPLAY=:1 nohup google-chrome-stable \
    $CHROME_FLAGS \
    --load-extension="$EXT_DIR" </dev/null >/dev/null 2>&1 &
fi

echo ""
echo "=========================================================="
echo " VPS DESKTOP ĐÃ SẴN SÀNG!"
echo " ✅ XFCE Desktop + noVNC (Port 6080 Public)"
echo " ✅ Google Chrome (Developer Mode = ON)"
echo " ✅ FB Manager Extension đã load sẵn"
echo " ✅ Không popup Keyring"
echo ""
echo " Desktop URL: https://${CODESPACE_NAME}-6080.app.github.dev/vnc.html?autoconnect=true&resize=scale"
echo "=========================================================="