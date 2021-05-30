#!/bin/bash
##########################################
## Dedicated Script to Community GeekPi ##
## RaspberryPi + RaspbianOS + HA + MQTT ##
## by: hellresistor 2021-05 V0.5 Alpha  ##
##########################################
# shellcheck disable=SC1091

####################
## CHANGE IT ZONE ##
MYMQTTUSER="homeassistant"
MYMQTTPASS="Str0ngP455w0rd"
RPIBUILD="raspberrypi4"

###############
## Variables ##
MYIP=$(ifconfig eth0 | awk '{ print $2}' | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
MYDEPPACKAGES=(sudo git curl network-manager software-properties-common apt-transport-https apparmor-utils ca-certificates dbus jq python3 python3-pip mosquitto)
source /etc/os-release

#####################
## Basic functions ##
function ok { echo "[OK] $*"; sleep 0.5; }
function error { echo "[ERROR] $*"; sleep 0.5; exit 1; }
function warn { echo "[WARN] $*"; sleep 1; }
function info { echo "[INFO] $*"; sleep 1; }

###################
## Verify system ##
info "Checking Compatible System ..."
if [[ "$USER" == "pi" ]] ; then
 error "Please use < sudo -i > command to log as root"
elif [[ "$USER" == "root" ]]; then
 ok "Root User Logged"
else
 error "$USER User NOT VALID. Use root"
fi
case "${ID,,}" in
 raspbian) ok "Raspbian System Detected !!" ;;
 *) error "Operating System NOT VALID" ;;
esac
case "$(uname -m)" in
 aarch64|armv7l) ok "ARCH $(uname -m) Detected !!" ;;
 *) error "$(uname -m) Architeture system NOT VALID" ;;
esac

#############################
## Installing dependencies ##
info "Updating System ..."
apt-get -y update > /dev/null 2>&1 && apt-get -y upgrade > /dev/null 2>&1
info "Installing Dependencies ..."
for i in "${MYDEPPACKAGES[@]}" ; do
 if command -v "$i" > /dev/null 2>&1; then
  info "Package $i is already Installed ..."
 else 
  if sudo apt-get -y install "$i" > /dev/null 2>&1; then
   ok "Package $i installed !!"
  else
   error "Unable install $i package ..."
  fi
 fi
done

############################
## Configuring the System ##
info "Configuring System ..."
if sudo systemctl disable ModemManager > /dev/null 2>&1 ; then
  ok "ModemManager Disabled !!"
else
  error "Some problem on ModemManager service ..."
fi
if sudo systemctl stop ModemManager > /dev/null 2>&1 ; then
  ok "ModemManager Stopped !!"
else
  error "Some problem on ModemManager service ..."
fi
##mount | grep securityfs
##mount securityfs -t securityfs /sys/kernel/security
if sed -i 's/.*/& lsm=apparmor/' /boot/cmdline.txt ; then
  ok "apparmor added into cmdline.txt file Succefully !!"
else
  error "Some problem adding apparmor config ..."
fi

#########################################
## Installing HomeAssistant Supervised ##
cd ~ || error "Cannot find directory"
info "Installing Docker ..."
if curl -fsSL get.docker.com | sh > /dev/null 2>&1 ; then
 ok "Docker Installed Succefully !! "
else
 error "A DOCKER BIG PROBLEM !!!!"
fi
info "Installing HomeAssistant Supervised ..."
if curl -sL "https://raw.githubusercontent.com/Kanga-Who/home-assistant/master/supervised-installer.sh" | bash -s -- -m "$RPIBUILD"; then
 echo
 info "PLEASE, Wait here, and Finish the HomeAssistant Setup on WebPage"
 warn "If unable open http://$MYIP:8123 , just wait little more and keep trying !!!"
 info "When you ENTER ON HomeAssistant DASHBOARD, Back here and ..."
 read -n 1 -r -s -p $'Press enter to continue...\n'
 ok "HomeAssistant Supervised Installed Succefully !! "
else
 error "A HOMEASSISTANT INSTALLATION BIG PROBLEM !!!!"
fi

################################################
## Installing and config Mosquitto MQTTBroker ##
info "Installing and configuring Mosquitto MQTTBroker Server ..."
if cat >>  /etc/mosquitto/conf.d/mosquitto.conf <<EOTF
allow_anonymous false
password_file /etc/mosquitto/conf.d/pwfile
port 1883
EOTF
then
 ok "Mosquito MQTT Broker Server Configured Succefully !!"
else
  error "Mosquito MQTT Broker Server NOT Configured ..."
fi
if echo -e "${MYMQTTPASS}//n${MYMQTTPASS}" | sudo mosquitto_passwd -c /etc/mosquitto/conf.d/pwfile $MYMQTTUSER
then
 ok "Created $MYMQTTUSER User for Mosquitto Succefully !!"
else
 error "Some problem creating user $MYMQTTUSER to Mosquitto ..."
fi
if sudo service mosquitto restart
then
  ok "Mosquito MQTT Broker Restarted Succefully !!"
else
  error "Some problem with Mosquito MQTT Broker Service ..."
fi
info "Add Mosquitto configuration into homeassistant configuration.yaml file..."
if cat >> /usr/share/hassio/homeassistant/configuration.yaml <<EOTF
# Local MQTT server
mqtt:
  discovery: true
  discovery_prefix: homeassistant
  broker: $MYIP
  port: 1883
  client_id: home-assistant-1
  keepalive: 60
  username: $MYMQTTUSER
  password: $MYMQTTPASS

EOTF
then
 ok "Mosquito MQTT Broker added to homeassistant configuration.yaml file Succefully !!"
else
  error "Some problem adding Mosquito MQTT Broker into HomeAssistant configuration.yaml file ..."
fi

#######################
## Configure Crontab ##
info "Configuring Crontab jobs ..."
crontab -l > mycron
echo "0 5 * * 5 sudo apt -y update && sudo apt -y upgrade && sudo apt -y autoremove" >> mycron
if crontab mycron ; then
 ok "Set Crontab jobs Succefully !! "
else
 error "Some problem adding the Crontab jobs ..."
fi
sudo -u pi -c 'rm mycron'

#############
## The END ##
ok "Instalation and Configuration of Raspberry + HomeAssistant + MQTT Server COMPLETED !!!"
apt-get -y autoremove
info "A reboot command should be executed on this System :) "
exit 0
