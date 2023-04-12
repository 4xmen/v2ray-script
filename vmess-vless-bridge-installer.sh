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
  mkdir -p /opt/vmess
  mkdir -p /var/log/v2ray/
  cd /opt/vmess
  FILE=/opt/vmess/v2ray
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
  echo "What port do you want v2ray (vmess) to listen to?"
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
  /opt/vmess/client$VSUFFIX.json
  VPASS="991832cc-"$(shuf -i1000-9999 -n1)"-"$(shuf -i1000-9999 -n1)"-"$(shuf -i1000-9999 -n1)"-7731d533fffe"
  {

    echo '{
  "log": {
    "access": "/var/log/v2ray/access'$VSUFFIX'.log",
    "error": "/var/log/v2ray/error'$VSUFFIX'.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": '$VPORT',
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "'$VPASS'",
            "alterId": 0,
            "security": "aes-128-gcm"
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "'$SIP'",
            "port": '$SPORT',
            "users": [
              {
                "id": "'$SKEY'",
                "encryption": "none",
                "level": 0
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws"
      },
      "mux": {
        "enabled": true
      }
    },
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
  },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "settings": {
      "rules": [
        {
          "type": "field",
          "outboundTag": "freedom",
          "domain": [
            "regexp:.*\\.ir$"
          ]
        }
      ]
    }
  }
}
'
  } >>/opt/vmess/client$VSUFFIX.json

}

function getIP() {
  VIP="$(curl https://api.ipify.org)"
}
function makeService() {
  rm /usr/bin/vmess$VSUFFIX.sh
  {

    echo '#!/bin/bash
/opt/vmess/v2ray -c=/opt/vmess/client'$VSUFFIX'.json'

  } >>/usr/bin/vmess$VSUFFIX.sh
  chmod +x /usr/bin/vmess$VSUFFIX.sh
  rm /etc/systemd/system/vmess$VSUFFIX.service
  {

    echo '[Unit]
Description=Vmess Peoxy
Documentation=

[Service]
Type=simple
User=root
Group=root
TimeoutStartSec=0
Restart=on-failure
RestartSec=30s
#ExecStartPre=
ExecStart=/usr/bin/vmess'$VSUFFIX'.sh
SyslogIdentifier=Diskutilization
#ExecStop=

[Install]
WantedBy=multi-user.target'

  } >>/etc/systemd/system/vmess$VSUFFIX.service

  systemctl enable vmess$VSUFFIX.service
  echo 'Service created'
  systemctl restart vmess$VSUFFIX.service
  echo 'Service started'
  echo 'Check service:  systemctl status vmess'$VSUFFIX'.service'

}
function getUpStreamInfo() {

  SPORT=1935
  read -rp "Server IP address: " -e -i "$SIP" SIP
  read -rp "Server secret key: " -e -i "$SKEY" SKEY
  read -rp "Server port: " -e -i "$SPORT" SPORT
  VCLIENT="xstack : )"
  read -rp "Client name: " -e -i "$VCLIENT" VCLIENT
  echo "!! Serice suffix is important when you need more than one service"
  read -rp "Service Suffix: " -e -i "x1" VSUFFIX

}
getUpStreamInfo
initialCheck
updateOs
installRequriment
downloadV2
cd /opt/vmess
getIP
choosePort
makeConfig
makeService
echo 'Your vmess config: '
echo ' '
VCONF='{"add":"'$VIP'","aid":"0","host":"","id":"'$VPASS'","net":"tcp","path":"","port":"'$VPORT'","ps":"'$VCLIENT'","scy":"auto","sni":"","tls":"none","type":"none","v":"2"}'
echo -n 'vmess://'
echo -n $VCONF | base64 -w 0
echo ' '
echo ' '
echo 'N-joy :) - xStack|4xmen Team'
