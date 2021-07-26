#!/bin/bash
##########################################
## Dedicated Script to Community GeekPi ##
##  RaspberryPi + RaspbianOS + UPSplus  ##
## by: hellresistor 2021-05 V0.5 Alpha  ##
##########################################
# shellcheck disable=SC1091

###############
## Variables ##
MYDEPPACKAGES=(sudo git python3 python3-pip i2c-tools python3-smbus)
MYPYTHONDEP=(RPi.GPIO smbus smbus2 pi-ina219)
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
if [[ "$USER" == "root" ]] ; then
 ok "$USER User Valid Login"
else
 error "$USER User NOT VALID. Use root"
fi
case "${ID,,}" in
 raspbian) ok "Raspbian System Detected !!" ;;
 debian) ok "Debian System Detected !!" ;;
 *) error "Operating System NOT VALID" ;;
esac
case "$(uname -m)" in
 aarch64) ok "ARCH $(uname -m) Detected !!" && RPIBOOTDIR="/boot/firmware/config.txt" ;;
  armv7l) ok "ARCH $(uname -m) Detected !!" && RPIBOOTDIR="/boot/config.txt" ;;
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
if sed -i '/^dtparam=i2c_arm=on/a dtoverlay=i2c-rtc,ds1307,addr=0x68\ndtoverlay=dwc2,dr_mode=host' "$RPIBOOTDIR" ; then
 ok "i2c added into $RPIBOOTDIR file Succefully !!"
else
 error "i2c NOT added into $RPIBOOTDIR file ... Add it manually:
  #I2C UPSplus board
  dtparam=i2c_arm=on
  dtoverlay=i2c-rtc,ds1307,addr=0x68
  dtoverlay=dwc2,dr_mode=host"
 error "And than reboot Rpi and execute script again "
fi

cat >> /etc/modules <<EOF
i2c-dev
rtc-ds1307
i2c-bcm2835
i2c-mux
i2c-smbus
dwc2
EOF
systemctl restart module-init-tools
systemctl status module-init-tools

sudo apt-get -y remove fake-hwclock || warn "fake-hwclock not exist..."
sudo update-rc.d -f fake-hwclock remove || warn "fake-hwclock not exist..."

sed -i '/if \[ -e \/run\/systemd\/system \] \; then/,+2 s/^/#/' /lib/udev/hwclock-set

if hwclock ; then
 ok "hwclock"
else
 warn "Fixing hwclock"
 mkdir  /usr/lib/systemd/scripts
cat > /usr/lib/systemd/scripts/rtc <<EOF
#!/bin/bash
echo ds1307 0x68 > /sys/class/i2c-adapter/i2c-3/new_device
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

sudo systemctl enable --now rtc
fi

cd ~ || error "Cannot find directory"
#if curl -Lso- https://git.io/JLygb | sudo bash > /dev/null 2>&1 ; then
# ok "UPSplus Installed Succefully !!"
#else
# error "A BIG PROBLEM with UPSplus scrypt ..."
#fi

#############
## The END ##
ok "Instalation and Configuration of RaspberryOS + UPSplus COMPLETED !!!"
info "A reboot command should be executed on this System :) "
exit 0
