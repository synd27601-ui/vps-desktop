#!/usr/bin/env bash
# 1. Tự động cài đặt nếu máy ảo mới chưa có VNC
if ! command -v vncserver >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 xfce4-goodies tigervnc-standalone-server tigervnc-common \
    novnc websockify dbus-x11
fi

# 2. Cấu hình xstartup cho XFCE nếu chưa có
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

# 3. Dọn dẹp lock cũ và bật VNC + noVNC
vncserver -kill :1 2>/dev/null || true
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
pkill -f "websockify.*6080" 2>/dev/null || true

vncserver :1 -localhost yes -SecurityTypes None -geometry 1366x768 -depth 24
nohup websockify --web=/usr/share/novnc/ 6080 localhost:5901 >/dev/null 2>&1 &
sleep 2

# 4. Mở Port 6080 Public
gh codespace ports visibility 6080:public -c "$CODESPACE_NAME" 2>/dev/null || true
