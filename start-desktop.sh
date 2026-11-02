#!/usr/bin/env bash
# 1. Tự động cài đặt XFCE + noVNC nếu máy mới chưa có
if ! command -v vncserver >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 xfce4-goodies tigervnc-standalone-server tigervnc-common \
    novnc websockify dbus-x11 wget curl
fi

# 2. Tự động cài đặt Google Chrome nếu máy mới chưa có
if ! command -v google-chrome-stable >/dev/null 2>&1; then
  wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo apt-get install -y ./google-chrome-stable_current_amd64.deb || sudo apt-get -f install -y
  rm -f google-chrome-stable_current_amd64.deb
fi

# 3. Cấu hình XFCE xstartup
if [ ! -f "$HOME/.vnc/xstartup" ]; then
  mkdir -p "$HOME/.vnc"
  cat << 'EOF' > "$HOME/.vnc/xstartup"
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export DISPLAY=:1
exec startxfce4
EOF
  chmod +x "$HOME/.vnc/xstartup"
fi

# 4. Tạo Autostart cho XFCE
mkdir -p "$HOME/.config/autostart"
cat << 'EOF' > "$HOME/.config/autostart/google-chrome.desktop"
[Desktop Entry]
Type=Application
Exec=google-chrome-stable --no-sandbox --disable-dev-shm-usage --no-first-run --no-default-browser-check
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Google Chrome
EOF

# 5. Dọn dẹp lock cũ và khởi động VNC + noVNC
vncserver -kill :1 2>/dev/null || true
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
pkill -f "websockify.*6080" 2>/dev/null || true

vncserver :1 -localhost yes -SecurityTypes None -geometry 1366x768 -depth 24
nohup websockify --web=/usr/share/novnc/ 6080 localhost:5901 >/dev/null 2>&1 &
sleep 2

# 6. Mở Port 6080 Public để không bị lỗi 404
gh codespace ports visibility 6080:public -c "$CODESPACE_NAME" 2>/dev/null || true

# 7. Khởi chạy Google Chrome trên Display :1
if ! pgrep -f "chrome" >/dev/null 2>&1; then
  DISPLAY=:1 nohup google-chrome-stable \
    --no-sandbox \
    --disable-dev-shm-usage \
    --no-first-run \
    --no-default-browser-check >/dev/null 2>&1 &
fi
