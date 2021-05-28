#!/bin/bash
############################################################
## Dedicated Script to Community GeekPi and HomeAssistant ##
############################################################

###############
## CHANGE IT ##
MYMQQTUSER="homeassistant"
MYMQQTPASS="Str0ngP455w0rd"
RPIBUILD="raspberrypi4"

###############
## Variables ##
MYIP=$(ifconfig eth0 | awk '{ print $2}' | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
MYDEPPACKAGES=("sudo" "git" "curl" "network-manager" "software-properties-common" "apt-transport-https" "apparmor-utils" "ca-certificates" "dbus" "jq" "python3" "python3-pip" "i2c-tools" "mosquitto" "mosquitto-clients")
MYPYTHONDEP=("RPi.GPIO" "smbus" "smbus2" "pi-ina219" "paho-mqtt" "requests")

function ok { echo "[OK] $*"; sleep 0.5; }
function error { echo "[ERROR] $*"; sleep 0.5; exit 1; }

###################
## Verify system ##
if id "pi" >/dev/null 2>&1; then
 error "Please use < sudo -i > command to log as root"
elif id "root" >/dev/null 2>&1; then
 ok "Root User Logged"
else
 error "User NOT VALID"
fi
case "${ID,,}" in
 raspbian) ok "Raspbian System Detected !!" ;;
 *) error "Operating System NOT VALID" ;;
esac
case "$(uname -m)" in
 aarch64|arm) ok "ARCH $(uname -m) Detected !!" ;;
 *) error "Architeture system NOT VALID" ;;
esac

#############################
## Installing dependencies ##
apt -y update && apt -y upgrade && apt -y autoremove
for i in "${MYDEPPACKAGES[@]}"
 do
  if ! command -v "$i" > /dev/null 2>&1 || { 
   echo "Installing $i package ..."; 
   sudo apt -y install "$i";}; then
   error "Some problem ..."
  else
   ok "Package $i installed !!"
  fi
 done

for f in "${MYPYTHONDEP[@]}"
 do
  if ! command -v "pip3 $f" > /dev/null 2>&1 || { 
   echo "Installing $f package ..."; 
   sudo pip3 install "$f" ;}; then
   error "Some problem ..."
  else
   ok "Package $i installed !!"
  fi
 done

############################
## Configuring the System ##
if sudo systemctl disable ModemManager ; then
  ok "ModemManager Disabled !!"
else
  error "Some problem ..."
fi
if sudo systemctl stop ModemManager ; then
  ok "ModemManager Disabled !!"
else
  error "Some problem ..."
fi
##mount | grep securityfs
##mount securityfs -t securityfs /sys/kernel/security
if sed 's/.*/& lsm=apparmor/' /boot/cmdline.txt ; then
  ok "apparmor added into cmdline.txt file Succefully !!"
else
  error "Some problem ..."
fi

#########################################
## Installing HomeAssistant Supervised ##
cd ~ || error "Cannot find directory"
if curl -fsSL get.docker.com | sh ; then
 ok "Docker Installed Succefully !! "
else
 error "A DOCKER BIG PROBLEM !!!!"
fi
if curl -sL "https://raw.githubusercontent.com/Kanga-Who/home-assistant/master/supervised-installer.sh" | bash -s -- -m "$RPIBUILD"; then
 ok "HomeAssistant Supervised Installed Succefully !! "
else
 error "A HOMEASSISTANT BIG PROBLEM !!!!"
fi

##############################
## Configure GeekPi UPSPlus ##
if sed -i '/^dtparam=i2c_arm=on/a dtoverlay=i2c-rtc,ds1307' /boot/config.txt ; then
  ok "i2c added into cmdline.txt file Succefully !!"
else
  error "Some problem ..."
fi
cd ~ || error "Cannot find directory"
if curl -Lso- https://git.io/JLygb | bash ; then
 ok "UPSplus Installed Succefully !!"
else
 error "A BIG PROBLEM !!!!"
fi
# Shutdown countdown
i2cset -y 1 0x17 24 60
# Back-On AC detect
i2cset -y 1 0x17 25 1

################################################
## Installing and config Mosquitto MQQTBroker ##
if cat >>  /etc/mosquitto/conf.d/mosquitto.conf <<EOTF
allow_anonymous false
password_file /etc/mosquitto/conf.d/pwfile
port 1883
EOTF
then
 ok "Mosquito MQQT Broker Server Configured Succefully !!"
else
  error "Some problem ..."
fi

echo "Set Password for Mosquitto user $MYMQQTUSER: "
sudo mosquitto_passwd -c /etc/mosquitto/conf.d/pwfile $MYMQQTUSER
echo "Restarting Mosquitto ...."

if sudo service mosquitto restart
then
  ok "Mosquito MQQT Broker Installed and configured Succefully  !!"
else
  error "Some problem ..."
fi

echo "Add Mosquitto configuration into homeassistant configuration.yaml file..."
if cat >> /usr/share/hassio/homeassistant/configuration.yaml <<EOTF
# Local MQQT server
mqtt:
  discovery: true
  discovery_prefix: homeassistant
  broker: $MYIP
  port: 1883
  client_id: home-assistant-1
  keepalive: 60
  username: $MYMQQTUSER
  password: $MYMQQTPASS

EOTF
then
 ok "Mosquito MQQT Broker added to homeassistant configuration.yaml file Succefully !!"
else
  error "Some problem ..."
fi
########################################################
## Configuring MQQTBroker to UPSplus On HomeAssistant ##
cd ~ || error "Cannot find directory"
mkdir scripts logs
git clone https://github.com/frtz13/UPSPlus_mqtt.git
cp UPSPlus_mqtt/fanShutDownUps.py scripts/fanShutDownUps.py
cp UPSPlus_mqtt/fanShutDownUps.ini scripts/fanShutDownUps.ini
cp UPSPlus_mqtt/launcher.sh  scripts/launcher.sh
sed -i "s/BROKER=.*/BROKER=$MYIP/" scripts/fanShutDownUps.ini
sed -i "s/USERNAME = .*/USERNAME = $MYMQQTUSER/" scripts/fanShutDownUps.ini
sed -i "s/PASSWORD = .*/PASSWORD = $MYMQQTPASS/" scripts/fanShutDownUps.ini
if sed -i "s/\/home\/pi/\/$USER/" scripts/launcher.sh ; then
 ok "Mosquitto MQQT Broker installed Succefully !! "
else
 error "A @frtz13 pythin script BIG PROBLEM !!!!"
fi

############################################
## Adding sensors configuration.yaml file ##
if cat >> /usr/share/hassio/homeassistant/configuration.yaml <<EOTF
# UPSPro GeekPi Sensor list
binary_sensor:
  - platform: mqtt
    name: "UPS on Battery"
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["OnBattery"] }}'
    payload_on: "True"
    payload_off: "False"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"
  - platform: mqtt
    name: "Battery Charging"
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["BatteryCharging"] }}'
    payload_on: "True"
    payload_off: "False"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"
sensor:
  - platform: mqtt
    name: "UPS average battery current"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["BatteryCurrent_avg_mA"] }}'
    unit_of_measurement: "mA"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"
  - platform: mqtt
    name: "UPS Battery Voltage"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["BatteryVoltage_V"] }}'
    unit_of_measurement: "V"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"
  - platform: mqtt
    name: "Current Battery"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["BatteryCurrent_mA"] }}'
    unit_of_measurement: "mA"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"
  - platform: mqtt
    name: "Battery Power"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["BatteryPower_avg_mW"] }}'
    unit_of_measurement: "mW"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"
  - platform: mqtt
    name: "Battery Capacity"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["BatteryRemainingCapacity_percent"] }}'
    unit_of_measurement: "%"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"
  - platform: mqtt
    name: "Battery Temperature"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["BatteryTemperature_degC"] }}'
    unit_of_measurement: "Cº"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"
  - platform: mqtt
    name: "Output Voltage"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["OutputVoltage_V"] }}'
    unit_of_measurement: "V"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"
  - platform: mqtt
    name: "OutPut Voltage Min"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["OutputVoltage_mini_V"] }}'
    unit_of_measurement: "V"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"
  - platform: mqtt
    name: "Output Current"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["OutputCurrent_mA"] }}'
    unit_of_measurement: "mA"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"
  - platform: mqtt
    name: "Output Current avg"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["OutputCurrent_avg_mA"] }}'
    unit_of_measurement: "mA"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"
  - platform: mqtt
    name: "Output Power avg"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["OutputPower_avg_mW"] }}'
    unit_of_measurement: "mW"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"
  - platform: mqtt
    name: "Output Current Peak"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["OutputCurrent_peak_mA"] }}'
    unit_of_measurement: "mA"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"
EOTF
then
 ok "Added UPSplus sensors on HomeAssistant configuration.yaml file Succefully !! "
else
 error "A BIG PROBLEM !!!!"
fi

#######################
## Configure Crontab ##
crontab -l > mycron
echo "@reboot sh /$USER/scripts/launcher.sh >/$USER/logs/cronlog 2>&1" >> mycron
echo "0 5 * * 5 sudo apt -y update && sudo apt -y upgrade && sudo apt -y autoremove" >> mycron
if crontab mycron ; then
 ok "Set Crontab jobs Succefully !! "
else
 error "A BIG PROBLEM !!!!"
fi
rm mycron
#############
## The END ##
ok "Instalation and Configuration of Raspberry + UPSplus + HomeAssistant COMPLETED !!!"
read -n1 -s -r -p "Press any key to reboot..." && sudo reboot