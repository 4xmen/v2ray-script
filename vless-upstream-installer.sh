#!/bin/bash

function isRoot() {
  if [ "$EUID" -ne 0 ]; then
    echo "Sorry, you need to run this as root"
    return 1
  fi
}

function tunAvailable() {
  if [ ! -e /dev/net/tun ]; then
    return 1
  fi
}
function initialCheck() {
  if ! isRoot; then
    echo "Sorry, you need to run this as root"
    exit 1
  fi
  if ! tunAvailable; then
    echo "TUN is not available"
    exit 1
  fi
}

function updateOs() {
  apt-get update
  apt-get dist-upgrade -y
}

function installRequriment() {
  apt-get install wget curl certbot git zsh unzip -y
}

function downloadV2() {
  mkdir -p /opt/vless
  mkdir -p /var/log/v2ray/
  cd /opt/vless
  FILE=/opt/vless/v2ray
  if [ -f "$FILE" ]; then
    echo "Could not download any more... :)"
  else
    wget https://github.com/v2ray/v2ray-core/releases/download/v4.28.2/v2ray-linux-64.zip
    unzip -o v2ray-linux-64.zip
    rm v2ray-linux-64.zip
  fi
}

function choosePort() {
  echo ""
  echo "What port do you want v2ray (vless) to listen to?"
  echo "   1) Default: 1935 (RTMP)"
  echo "   2) Custom"
  echo "   3) Random [49152-65535]"
  until [[ $PORT_CHOICE =~ ^[1-3]$ ]]; do
    read -rp "Port choice [1-3]: " -e -i 1 PORT_CHOICE
  done
  case $PORT_CHOICE in
  1)
    VPORT="1935"
    ;;
  2)
    until [[ $VPORT =~ ^[0-9]+$ ]] && [ "$VPORT" -ge 1 ] && [ "$VPORT" -le 65535 ]; do
      read -rp "Custom port [1-65535]: " -e -i 1935 VPORT
    done
    ;;
  3)
    # Generate random number within private ports range
    VPORT=$(shuf -i49152-65535 -n1)
    echo "Random Port: $VPORT"
    ;;
  esac
}

function makeConfig() {
  rm /opt/vless/server.json
  VPASS="991832cc-"$(shuf -i1000-9999 -n1)"-"$(shuf -i1000-9999 -n1)"-"$(shuf -i1000-9999 -n1)"-7731d533fffe"
  {
    echo '{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [


    {
      "listen": "0.0.0.0",
      "port": '$VPORT',
      "protocol": "vless",
       "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "'$VPASS'",
             "level": 0
          }
        ]
      },

      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/"
        }
      },
      "mux": {
        "enabled": true
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "freedom"
    }
  ],
  "dns": {
    "servers": [
      "8.8.8.8",
      "8.8.4.4",
      "localhost"
    ]
  }
}'
  } >>/opt/vless/server.json
}

function makeService() {
  rm /usr/bin/vless.sh
  {

    echo '#!/bin/bash
/opt/vless/v2ray -c=/opt/vless/server.json'

  } >>/usr/bin/vless.sh
  chmod +x /usr/bin/vless.sh
  rm /etc/systemd/system/vless.service
  {

    echo '[Unit]
Description=vless Peoxy
Documentation=

[Service]
Type=simple
User=root
Group=root
TimeoutStartSec=0
Restart=on-failure
RestartSec=30s
#ExecStartPre=
ExecStart=/usr/bin/vless.sh
SyslogIdentifier=Diskutilization
#ExecStop=

[Install]
WantedBy=multi-user.target'

  } >>/etc/systemd/system/vless.service

  systemctl enable vless.service
  echo 'Service created'
  systemctl restart vless.service
  echo 'Service started'
  echo 'Check service:  systemctl status vless.service'

}
function getIP() {
  VIP="$(curl https://api.ipify.org)"
}
initialCheck
updateOs
installRequriment
downloadV2
getIP
cd /opt/vless
choosePort
makeConfig
makeService

echo 'Your server secret key: '$VPASS
echo 'Your IP: '$VIP
echo 'Your port: '$VPORT
echo 'N-joy :) - xStack|4xmen Team'
