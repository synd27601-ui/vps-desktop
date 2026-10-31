#!/usr/bin/env bash
vncserver -kill :1 2>/dev/null || true
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
pkill -f "websockify.*6080" 2>/dev/null || true

# Khởi động XFCE Desktop & noVNC
vncserver :1 -localhost yes -SecurityTypes None -geometry 1366x768 -depth 24
nohup websockify --web=/usr/share/novnc/ 6080 localhost:5901 >/dev/null 2>&1 &
sleep 2

# Đảm bảo cổng 6080 là Public
gh codespace ports visibility 6080:public -c "$CODESPACE_NAME" 2>/dev/null || true
