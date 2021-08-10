# Rpi-UPSplus-HA
 A Script to help people to Install HomeAssistant Supervised on a Raspberry OS with Raspberry Pi 4 and GeekPi UPSplus

*Scripts:*
 - RPI-HA-UPSplus-V2.sh
 - RPI4-UPSplus-HA-Prep.sh (*deprecated*)
 - Rpi4-HA-MQTT-ONLY.sh
 - Rpi4-UPS-ONLY.sh

*Hardware Used:*
 - 1x Raspberry Pi 4 Model B 4GB
 - 1x GeekPi UPSplus Raspberry 
 - 2x Lion Cells 18650 3.7V
 - 1x microSD Card 64GB
 - 1x Fast Charger HIGH Quality (Original RPI4 Power Charger 3.5Amp)

*Software Used:*
 - Debian OS 
 - HomeAssistant Supervised
 - Mosquitto MQQT Broker Localserver
 - @geeekpi UPSplus python script
 - @frtz13 UPSplus Reporter python script
 - @ironsheep RPI Reporter Mqqt daemon


# How Use RPI4-UPSplus-HA-Prep.sh or Rpi4-UPS-ONLY.sh ?
Follow this steps:
 - Use BelenaEtcher or RaspberryPi Imager to write microSD card
 - GoTo 'config.txt' file and Add/Uncomment this line: 'dtparam=i2c_arm=on'
 - Assemble the Raspberry with SDCard and than GeekPi UPSplus (follow the instructions)
 - Do the First Pop-Up Raspberry configuration (raspi-config)
 - Execute Script: RPI4-UPSplus-HA-Prep.sh

# Lazy Lines
    git clone https://github.com/hellresistor/Rpi-UPSplus-HA.git && bash Rpi-UPSplus-HA/RPI4-UPSplus-HA-Prep.sh


# Other Links NOT MISSING!
 - https://raspi.debian.net/verified/20210718_raspi_4_buster.img.xz
 - https://www.raspberrypi.org/software/
 - https://github.com/Kanga-Who/home-assistant
 - https://wiki.52pi.com/index.php/UPS_Plus_SKU:_EP-0136#UPS_Plus
 - https://github.com/balena-io/etcher/releases
 - https://github.com/frtz13/UPSPlus_mqtt.git
 - https://github.com/ArjenR49/UPS-Plus.git
 - https://github.com/ironsheep/RPi-Reporter-MQTT2HA-Daemon.git
 

# Help improoving :)
Donate Bitcoin: 1292xDndXSxZgRkq1jZJfUTRdcGeictoUv

Donate Bitcanna: B73RRFVtndfPRNSgSQg34yqz4e9eWyKRSv

Donate Others: just ask ;)
