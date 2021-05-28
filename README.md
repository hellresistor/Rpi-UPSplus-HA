# Rpi-UPSplus-HA
 A Script to help people to Install HomeAssistant Supervised on a Raspberry OS with Raspberry Pi 4 and GeekPi UPSplus

*Hardware Used:*
 - 1x Raspberry Pi 4 Model B
 - 1x GeekPi UPSplus Raspberry 
 - 2x Lion Cells 18650 3.7V
 - 1x microSD Card 64GB
 - 1x Fast Charger HIGH Quality (Original RPI4 

*Software Used:*
 - Raspberry OS 
 - HomeAssistant Supervised
 - Mosquitto MQQT Broker Localserver
 - GeekPi UPSplus python script
 - frtz13 python script

# How Use it ?
Follow this steps:
 - Use BelenaEtcher or RaspberryPi Imager to write microSD card
 - GoTo 'config.txt' file and Add/Uncomment this line: 'dtparam=i2c_arm=on'
 - Assemble the Raspberry with SDCard and than GeekPi UPSplus (follow the instructions)
 - Do the First Pop-Up Raspberry configuration (raspi-config)
 - Execute Script: RPI4-UPSplus-HA-Prep.sh

# Lazy Lines
    git clone https://github.com/hellresistor/Rpi-UPSplus-HA.git && bash Rpi-UPSplus-HA/RPI4-UPSplus-HA-Prep.sh


# Other Links NOT MISSING!
 - https://wiki.52pi.com/index.php/UPS_Plus_SKU:_EP-0136#UPS_Plus
 - https://github.com/balena-io/etcher/releases
 - https://github.com/frtz13/UPSPlus_mqtt.git
 

# Help improoving :)
Donate Bitcoin: 13Gr4JiWQBnhCs6AdUNapdfHVu3tG9G6zL

Donate Bitcanna: B73RRFVtndfPRNSgSQg34yqz4e9eWyKRSv

Donate Others: just ask ;)
