#!/bin/bash
############################################################
## Dedicated Script to Community GeekPi and HomeAssistant ##
##     RaspberryPi + RaspbianOS + UPSplus + HA + MQTT     ##
##  by: hellresistor         2021-05         V0.5 Alpha   ##
############################################################
# shellcheck disable=SC1091

####################
## CHANGE IT ZONE ##
MYMQTTUSER="homeassistant"
MYMQTTPASS="Str0ngP455w0rd"
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

##############################
## Configure GeekPi UPSPlus ##
info "Configuring GeekPi UPSplus ..."
if sed -i '/^dtparam=i2c_arm=on/a dtoverlay=i2c-rtc,ds1307' /boot/config.txt ; then
  ok "i2c added into /boot/config.txt file Succefully !!"
else
  error "i2c NOT added into /boot/config.txt file ..."
fi
#cd ~ || error "Cannot find directory"
#if curl -Lso- https://git.io/JLygb | bash > /dev/null 2>&1 ; then
# ok "UPSplus Installed Succefully !!"
#else
# error "A BIG PROBLEM with UPSplus scrypt ..."
#fi

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

########################################################
## Configuring MQTTBroker to UPSplus On HomeAssistant ##
info "Configuring MQTTBroker to UPSplus On HomeAssistant ..."
cd /home/pi || error "Cannot find directory"
#cd ~ || error "Cannot find directory"
mkdir scripts logs
git clone https://github.com/frtz13/UPSPlus_mqtt.git > /dev/null 2>&1
cp UPSPlus_mqtt/fanShutDownUps.py scripts/fanShutDownUps.py
cp UPSPlus_mqtt/fanShutDownUps.ini scripts/fanShutDownUps.ini
cp UPSPlus_mqtt/launcher.sh  scripts/launcher.sh
sed -i "s/BROKER=.*/BROKER=$MYIP/" scripts/fanShutDownUps.ini || error "Unable to set BROKER into scripts/fanShutDownUps.ini"
sed -i "s/USERNAME = .*/USERNAME = $MYMQTTUSER/" scripts/fanShutDownUps.ini || error "Unable to set USERNAME into scripts/fanShutDownUps.ini"
sed -i "s/PASSWORD = .*/PASSWORD = $MYMQTTPASS/" scripts/fanShutDownUps.ini || error "Unable to set PASSWORD into scripts/fanShutDownUps.ini"
#sed -i "s/\/home\/pi/\/$USER/" scripts/launcher.sh || error "Unable to set right User Directory into scripts/fanShutDownUps.ini"
sudo chown -R pi scripts && sudo chown -R pi logs
if sudo -u pi -c 'python3 UPSPlus_mqtt/fanShutDownUps.py &'
then
 ok "Mosquitto MQTT Broker installed and Runnnig Succefully !! "
else
 error "A @frtz13 python script BIG PROBLEM !!!!"
fi

############################################
## Adding sensors configuration.yaml file ##
info "Adding sensors configuration.yaml file ..."
if cat >> /usr/share/hassio/homeassistant/configuration.yaml <<EOTF
sensor:
  - platform: mqtt
    name: CPU fan speed
    unit_of_measurement: "%"
    state_topic: "home/rpi/fanspeed"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"

  - platform: mqtt
    name: "UPS Battery Voltage"
    device_class: voltage
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["BatteryVoltage_V"] }}'
    unit_of_measurement: "V"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"

  - platform: mqtt
    name: "UPS Battery current"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["BatteryCurrent_mA"] }}'
    unit_of_measurement: "mA"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"

  - platform: mqtt
    name: "UPS average Battery current"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["BatteryCurrent_avg_mA"] }}'
    unit_of_measurement: "mA"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"

  - platform: mqtt
    name: "UPS average Battery power"
    device_class: power
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["BatteryPower_avg_mW"] }}'
    unit_of_measurement: "mW"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"

  - platform: mqtt
    name: "UPS Battery temperature"
    device_class: temperature
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["BatteryTemperature_degC"] }}'
    unit_of_measurement: "?C"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"

  - platform: mqtt
    name: "UPS Output Voltage"
    device_class: voltage
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["OutputVoltage_V"] }}'
    unit_of_measurement: "V"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"

  - platform: mqtt
    name: "UPS minimum Output Voltage"
    device_class: voltage
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["OutputVoltage_mini_V"] }}'
    unit_of_measurement: "V"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"

  - platform: mqtt
    name: "UPS Output current"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["OutputCurrent_mA"] }}'
    unit_of_measurement: "mA"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"

  - platform: mqtt
    name: "UPS average output current"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["OutputCurrent_avg_mA"] }}'
    unit_of_measurement: "mA"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"

  - platform: mqtt
    name: "UPS peak output current"
    device_class: current
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["OutputCurrent_peak_mA"] }}'
    unit_of_measurement: "mA"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"

  - platform: mqtt
    name: "UPS average output power"
    device_class: power
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["OutputPower_avg_mW"] }}'
    unit_of_measurement: "mW"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"

  - platform: mqtt
    name: "UPS Battery Remaining Capacity"
    device_class: energy
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["BatteryRemainingCapacity_percent"] }}'
    unit_of_measurement: "%"
    availability:
      - topic:  "home/rpi/LWT"
        payload_available: "online"
        payload_not_available: "offline"

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
    name: "UPS Battery Charging"
    state_topic: "home/rpi/ups"
    value_template: '{{ value_json["BatteryCharging"] }}'
    payload_on: "True"
    payload_off: "False"
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
sudo -u pi -c 'crontab -l > mycron'
#echo "@reboot sh /$USER/scripts/launcher.sh >/$USER/logs/cronlog 2>&1" >> mycron
sudo -u pi -c 'echo "@reboot sh /home/pi/scripts/launcher.sh >/home/pi/logs/cronlog 2>&1" >> mycron'
sudo -u pi -c 'echo "0 5 * * 5 sudo apt -y update && sudo apt -y upgrade && sudo apt -y autoremove" >> mycron'
if sudo -u pi -c 'crontab mycron' ; then
 ok "Set Crontab jobs Succefully !! "
else
 error "Some problem adding the Crontab jobs ..."
fi
sudo -u pi -c 'rm mycron'

#############
## The END ##
ok "Instalation and Configuration of Raspberry + UPSplus + HomeAssistant COMPLETED !!!"
apt-get -y autoremove
info "A reboot command should be executed on this System :) "
exit 0
