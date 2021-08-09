#!/bin/bash
############################################################
## Dedicated Script to Community GeekPi and HomeAssistant ##
##     RaspberryPi 4 + Debian 10 aarch64 + UPSplus + HA   ##
##  by: hellresistor         2021-08         V0.8 Alpha   ##
############################################################
# shellcheck disable=SC1091

####################
## CHANGE IT ZONE ##
MYMQTTUSER="homeassistant"
MYMQTTPASS="Str0ngP455w0rd"
RPIBUILD="raspberrypi4-64"

###############
## Variables ##
MYIP=$(ifconfig eth0 | awk '{ print $2}' | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
MYDEPPACKAGES=(sudo git curl network-manager software-properties-common apt-transport-https apparmor-utils ca-certificates dbus jq python3 python3-pip i2c-tools python3-tzlocal python3-sdnotify python3-colorama python3-unidecode python3-paho-mqtt )
MYPYTHONDEP=(RPi.GPIO smbus smbus2 pi-ina219 paho-mqtt requests)
source /etc/os-release

#####################
## Basic functions ##
endy=$'\e[0m'
greeny=$'\e[92m'
bluey=$'\e[94m'
redy=$'\e[91m'
yellowy=$'\e[93m'
function ok { echo -e "${greeny}[OK] $* ${endy}"; }
function error { echo -e "${redy}[ERROR] $* ${endy}"; exit 1; }
function warn { echo -e "${yellowy}[WARN] $* ${endy}"; }
function info { echo -e "${bluey}[INFO] $* ${endy}"; }

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
info "Installing python3 Dependencies ..."
for f in "${MYPYTHONDEP[@]}" ; do
 info "Installing $f package ..."
 pip3 install "$f" > /dev/null 2>&1
done

############################
## Configuring the System ##
info "Configuring System ..."
if sudo systemctl disable ModemManager > /dev/null 2>&1 ; then
  ok "ModemManager Disabled !!"
else
  warn "Some problem on ModemManager service ..."
fi
if sudo systemctl stop ModemManager > /dev/null 2>&1 ; then
  ok "ModemManager Stopped !!"
else
  warn "Some problem on ModemManager service ..."
fi

#########################################
## Installing HomeAssistant Supervised ##
cd ~ || error "Cannot find directory"
info "Installing Docker ..."
if curl -fsSL get.docker.com | sh ; then
 ok "Docker Installed Succefully !! "
else
 error "A DOCKER BIG PROBLEM !!!!"
fi

info "To Install HA Supervised Do this steps...."
info " 1- on user session run:  sudo -i "
info " 2- in root session run:  curl -sL "https://raw.githubusercontent.com/Kanga-Who/home-assistant/master/supervised-installer.sh" | bash -s -- -m "$RPIBUILD" "
info " 3- Wait .... until first HA wizard configuration (on webpage)."


##############################
## Configure GeekPi UPSPlus ##
info "Configuring GeekPi UPSplus ..."
if grep -q 'dtparam=i2c_arm=on' /boot/firmware/config.txt; then
 echo "dtoverlay=i2c-rtc,ds1307,addr=0x68
dtparam=i2c_vc=on
dtoverlay=dwc2,dr_mode=host
dtoverlay=miniuart-bt
force_turbo=1" | tee -a /boot/firmware/config.txt
else
 echo "dtparam=i2c_arm=on
dtoverlay=i2c-rtc,ds1307,addr=0x68
dtparam=i2c_vc=on
dtoverlay=dwc2,dr_mode=host
dtoverlay=miniuart-bt
force_turbo=1" | tee -a /boot/firmware/config.txt
fi

if [[ -f "/etc/modules-load.d/rpi4.conf" ]] ; then
  ok "Module rpi4.conf exists !!"
else
 echo "snd-bcm2835
i2c-dev
rtc-ds1307
#i2c-bcm2835
dwc2" | sudo tee -a /etc/modules-load.d/rpi4.conf
 ok "Added Modules to kernel!"
fi
systemctl restart module-init-tools

sudo apt-get -y remove fake-hwclock || warn "fake-hwclock not exist..."
sudo update-rc.d -f fake-hwclock remove || warn "fake-hwclock not exist..."

sed -i '/if \[ -e \/run\/systemd\/system \] \; then/,+2 s/^/#/' /lib/udev/hwclock-set

if sudo hwclock ; then
 ok "hwclock"
else
 warn "Fixing hwclock"
 mkdir  /usr/lib/systemd/scripts
cat > /usr/lib/systemd/scripts/rtc <<EOF
#!/bin/bash
echo "ds1307 0x68" > /sys/class/i2c-adapter/i2c-3/new_device
hwclock -s
EOF
sudo chmod 755 /usr/lib/systemd/scripts/rtc
cat > /usr/lib/systemd/system/rtc.service <<EOF
[Unit]
Description=rtc
Before=network.target
[Service]
ExecStart=/usr/lib/systemd/scripts/rtc
Type=oneshot
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable rtc
fi

#cd ~ || error "Cannot find directory"
#if curl -Lso- https://git.io/JLygb | bash > /dev/null 2>&1 ; then
# ok "UPSplus Installed Succefully !!"
#else
# error "A BIG PROBLEM with UPSplus scrypt ..."
#fi




########################################################
## Configuring MQTTBroker to UPSplus On HomeAssistant ##
info "Configuring UPSPlus_mqtt to mqttbrioker On HomeAssistant ..."
cd /opt || error "Cannot find directory"
git clone https://github.com/frtz13/UPSPlus_mqtt.git
cd UPSPlus_mqtt
sed -i "s/BROKER=.*/BROKER = $MYIP/" fanShutDownUps.ini > /dev/null 2>&1 || error "Unable to set BROKER into fanShutDownUps.ini"
sed -i "s/USERNAME = .*/USERNAME = $MYMQTTUSER/" fanShutDownUps.ini > /dev/null 2>&1 || error "Unable to set USERNAME into fanShutDownUps.ini"
sed -i "s/PASSWORD = .*/PASSWORD = $MYMQTTPASS/" fanShutDownUps.ini > /dev/null 2>&1 || error "Unable to set PASSWORD into fanShutDownUps.ini"
sed -i "s/PROTECTION_VOLTAGE_MARGIN_mV =.*/PROTECTION_VOLTAGE_MARGIN_mV = 300/" fanShutDownUps.ini > /dev/null 2>&1 || error "Unable to set PROTECTION_VOLTAGE_MARGIN_mV into fanShutDownUps.ini"
sed -i '/^DEVICE_BUS =.*/a DEVICE_BUS = 3' fanShutDownUps.py > /dev/null 2>&1 || warn "DEVICE BUS not set ..."

# python3 /opt/UPSPlus_mqtt/fanShutDownUps.py --notimerbias &

info "Create Service for frtz13 script"
cat > UPSPlus_mqtt.service <<EOF
[Unit]
Description=UPSPlus MQTT HA by frtz13
Documentation=https://github.com/frtz13/UPSPlus_mqtt
After=network.target mosquitto.service network-online.target
Wants=network-online.target
Requires=network.target

[Service]
Type=notify
User=daemon
Group=daemon
WorkingDirectory=/opt/UPSPlus_mqtt/
ExecStart=/usr/bin/python3 -u /opt/UPSPlus_mqtt/fanShutDownUps.py
StandardOutput=null
#StandardOutput=syslog
#SyslogIdentifier=ISPliDet
StandardError=journal
Environment=PYTHONUNBUFFERED=1
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo ln -s /opt/UPSPlus_mqtt/UPSPlus_mqtt.service /etc/systemd/system/UPSPlus_mqtt.service
sudo systemctl daemon-reload
sudo systemctl enable UPSPlus_mqtt.service


##############
# RPiReporter MQTT2HA
sudo git clone https://github.com/ironsheep/RPi-Reporter-MQTT2HA-Daemon.git /opt/RPi-Reporter-MQTT2HA-Daemon
cd /opt/RPi-Reporter-MQTT2HA-Daemon
sudo pip3 install -r requirements.txt || error "Cannot install requirements for RPiReporter MQTT2HA"
sudo cp /opt/RPi-Reporter-MQTT2HA-Daemon/config.{ini.dist,ini}
sed -i "s/hostname =.*/hostname = $MYIP/" config.ini > /dev/null 2>&1 || error "Unable to set BROKER into config.ini"
sed -i "s/base_topic =.*/base_topic = home\/sensor/" config.ini > /dev/null 2>&1 || error "Unable to set BROKER into config.ini"
sed -i "s/username =.*/username = $MYMQTTUSER/" config.ini > /dev/null 2>&1 || error "Unable to set BROKER into config.ini"
sed -i "s/password =.*/password = $MYMQTTPASS/" config.ini > /dev/null 2>&1 || error "Unable to set BROKER into config.ini"

sudo ln -s /opt/RPi-Reporter-MQTT2HA-Daemon/isp-rpi-reporter.service /etc/systemd/system/isp-rpi-reporter.service
sudo systemctl daemon-reload
sudo systemctl enable isp-rpi-reporter.service


#######################
## Configure Crontab ##
info "Configuring Crontab jobs ..."
sudo crontab -l > mycron
echo "0 5 * * 5 sudo apt -y update && sudo apt -y upgrade && sudo apt -y autoremove" >> mycron
if sudo crontab mycron ; then
 ok "Set Crontab jobs Succefully !! "
else
 error "Some problem adding the Crontab jobs ..."
fi
sudo rm mycron

#############
## The END ##
ok "Instalation and Configuration of Raspberry + UPSplus + HomeAssistant COMPLETED !!!"
apt-get -y autoremove  > /dev/null 2>&1
info "A reboot command should be executed on this System :) "
exit 0
