#!/bin/bash

function isRoot() {
	if [ "$EUID" -ne 0 ]; then
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

function updateOs(){
	apt-get update
	apt-get dist-upgrade -y
}

function installRequriment(){
	apt-get install wget curl certbot git zsh unzip -y
}

function downloadV2(){
	mkdir -p /opt/vmess
	mkdir -p /var/log/v2ray/
	cd /opt/vmess
	FILE=/opt/vmess/v2ray
	if [ -f "$FILE" ]; then
	    echo "Not download any more... :)"
	else 
	    	wget http://cdn.goldaccess.xyz/v-linux2-64.zip
	    	unzip -o v-linux2-64.zip
		rm v-linux2-64.zip
	fi
}

function choosePort(){
	echo ""
	echo "What port do you want OpenVPN to listen to?"
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

function makeConfig(){
	rm /opt/vmess/server.json
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
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "'$VPASS'",
            "alterId": 0,
            "security": "auto"
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
	} >> /opt/vmess/server.json
}

function makeService(){
	rm /usr/bin/vmess.sh
	{
		
		echo '#!/bin/bash
/opt/vmess/v2ray -c=/opt/vmess/server.json'
	
	} >> /usr/bin/vmess.sh
	chmod +x /usr/bin/vmess.sh 
	rm /etc/systemd/system/vmess.service
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
ExecStart=/usr/bin/vmess.sh
SyslogIdentifier=Diskutilization
#ExecStop=

[Install]
WantedBy=multi-user.target'

	} >> /etc/systemd/system/vmess.service 
	
	systemctl enable vmess.service 
	echo 'Service created'
	systemctl restart vmess.service 
	echo 'Service started'
	echo 'Check service:  systemctl status vmess.service'
	
}
function getIP(){
	VIP="$(curl https://api.ipify.org)"
}
initialCheck
updateOs
installRequriment
downloadV2
getIP
cd /opt/vmess
choosePort
makeConfig
makeService

echo 'Your server secret key: '$VPASS
echo 'Your IP: '$VIP 
echo 'Your port: '$VPORT 
echo 'N-joy :) - xStack|4xmen Team'

