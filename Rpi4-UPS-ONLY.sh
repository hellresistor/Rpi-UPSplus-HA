#!/bin/bash
##########################################
## Dedicated Script to Community GeekPi ##
##  RaspberryPi + RaspbianOS + UPSplus  ##
## by: hellresistor 2021-05 V0.5 Alpha  ##
##########################################
# shellcheck disable=SC1091

###############
## Variables ##
MYDEPPACKAGES=(sudo git python3 python3-pip i2c-tools)
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
 ok "pi User Logged"
else
 error "$USER User NOT VALID. Use pi user"
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

##############################
## Configure GeekPi UPSPlus ##
info "Configuring GeekPi UPSplus ..."
if sed -i '/^dtparam=i2c_arm=on/a dtoverlay=i2c-rtc,ds1307' /boot/config.txt ; then
  ok "i2c added into /boot/config.txt file Succefully !!"
else
  error "i2c NOT added into /boot/config.txt file ..."
fi
cd ~ || error "Cannot find directory"
if curl -Lso- https://git.io/JLygb | sudo bash > /dev/null 2>&1 ; then
 ok "UPSplus Installed Succefully !!"
else
 error "A BIG PROBLEM with UPSplus scrypt ..."
fi

#############
## The END ##
ok "Instalation and Configuration of RaspberryOS + UPSplus COMPLETED !!!"
apt-get -y autoremove
info "A reboot command should be executed on this System :) "
exit 0
