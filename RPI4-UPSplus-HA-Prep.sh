#!/bin/bash
############################################################
## Dedicated Script to Community GeekPi and HomeAssistant ##
##                                                        ##
## by: hellresistor        2021-05          V0.3          ##
############################################################

####################
## CHANGE IT ZONE ##
MYMQQTUSER="homeassistant"
MYMQQTPASS="Str0ngP455w0rd"
RPIBUILD="raspberrypi4"

###############
## Variables ##
MYIP=$(ifconfig eth0 | awk '{ print $2}' | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
MYDEPPACKAGES=(sudo git curl network-manager software-properties-common apt-transport-https apparmor-utils ca-certificates dbus jq python3 python3-pip i2c-tools mosquitto mosquitto-clients)
MYPYTHONDEP=(RPi.GPIO smbus smbus2 pi-ina219 paho-mqtt requests)
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
apt-get -y update && apt-get -y upgrade
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
 error "A HOMEASSISTANT INSTALLATION BIG PROBLEM !!!!"
fi

##############################
## Configure GeekPi UPSPlus ##
info "Configuring GeekPi UPSplus ..."
if sed -i '/^dtparam=i2c_arm=on/a dtoverlay=i2c-rtc,ds1307' /boot/config.txt ; then
  ok "i2c added into /boot/config.txt file Succefully !!"
else
  error "i2c NOT added into /boot/config.txt file ..."
fi
cd ~ || error "Cannot find directory"
if curl -Lso- https://git.io/JLygb | bash ; then
 ok "UPSplus Installed Succefully !!"
else
 error "A BIG PROBLEM with UPSplus scrypt ..."
fi

################################################
## Installing and config Mosquitto MQQTBroker ##
info "Installing and configuring Mosquitto MQQTBroker Server ..."
if cat >>  /etc/mosquitto/conf.d/mosquitto.conf <<EOTF
allow_anonymous false
password_file /etc/mosquitto/conf.d/pwfile
port 1883
EOTF
then
 ok "Mosquito MQQT Broker Server Configured Succefully !!"
else
  error "Mosquito MQQT Broker Server NOT Configured ..."
fi

info "Set Password for Mosquitto user $MYMQQTUSER: "
sudo mosquitto_passwd -c /etc/mosquitto/conf.d/pwfile $MYMQQTUSER

if sudo service mosquitto restart
then
  ok "Mosquito MQQT Broker Restarted Succefully  !!"
else
  error "Some problem with Mosquito MQQT Broker Service ..."
fi

info "Add Mosquitto configuration into homeassistant configuration.yaml file..."
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
  error "Some problem adding Mosquito MQQT Broker into HomeAssistant configuration.yaml file ..."
fi
########################################################
## Configuring MQQTBroker to UPSplus On HomeAssistant ##
info "Configuring MQQTBroker to UPSplus On HomeAssistant ..."
cd ~ || error "Cannot find directory"
mkdir scripts logs
git clone https://github.com/frtz13/UPSPlus_mqtt.git
cp UPSPlus_mqtt/fanShutDownUps.py scripts/fanShutDownUps.py
cp UPSPlus_mqtt/fanShutDownUps.ini scripts/fanShutDownUps.ini
cp UPSPlus_mqtt/launcher.sh  scripts/launcher.sh
sed -i "s/BROKER=.*/BROKER=$MYIP/" scripts/fanShutDownUps.ini || error "Unable to set BROKER into scripts/fanShutDownUps.ini"
sed -i "s/USERNAME = .*/USERNAME = $MYMQQTUSER/" scripts/fanShutDownUps.ini || error "Unable to set USERNAME into scripts/fanShutDownUps.ini"
sed -i "s/PASSWORD = .*/PASSWORD = $MYMQQTPASS/" scripts/fanShutDownUps.ini || error "Unable to set PASSWORD into scripts/fanShutDownUps.ini"
sed -i "s/\/home\/pi/\/$USER/" scripts/launcher.sh || error "Unable to set right User Directory into scripts/fanShutDownUps.ini"
if python3 UPSPlus_mqtt/fanShutDownUps.py &
then
 ok "Mosquitto MQQT Broker installed and Runnnig Succefully !! "
else
 error "A @frtz13 pythin script BIG PROBLEM !!!!"
fi

############################################
## Adding sensors configuration.yaml file ##
info "Adding sensors configuration.yaml file ..."
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
 ok "Added UPSplus sensors on HomeAssistant configuration.yaml file Succefully !!!"
else
 error "Some problem adding UPSplus sensors into HomeAssistant configuration.yaml file ..."
fi

#######################
## Configure Crontab ##
info "Configuring Crontab jobs ..."
crontab -l > mycron
echo "@reboot sh /$USER/scripts/launcher.sh >/$USER/logs/cronlog 2>&1" >> mycron
echo "0 5 * * 5 sudo apt -y update && sudo apt -y upgrade && sudo apt -y autoremove" >> mycron
if crontab mycron ; then
 ok "Set Crontab jobs Succefully !! "
else
 error "Some problem adding the Crontab jobs ..."
fi
rm mycron
#############
## The END ##
ok "Instalation and Configuration of Raspberry + UPSplus + HomeAssistant COMPLETED !!!"
ok "Now Wait a little bit (5minutes) the homeassistant are preparing" && sleep 5
ok "Complete the HomeAssistant Wizard Accessing:"
ok "http://$MYIP:8123" && sleep 2
echo 
warn "If unable open http://$MYIP:8123 , just wait little more !!!" && sleep 5
info "After HomeAssistant Wizard Completed, a reboot command should be executed on Raspberry System :) "
apt-get -y autoremove
