#x735 Powering on /reboot /shutdown from hardware
#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

    sed -e '/shutdown/ s/^#*/#/' -i /etc/rc.local

    echo '#!/bin/bash

SHUTDOWN=4
REBOOTPULSEMINIMUM=200
REBOOTPULSEMAXIMUM=600
echo "$SHUTDOWN" > /sys/class/gpio/export
echo "in" > /sys/class/gpio/gpio$SHUTDOWN/direction
BOOT=17
echo "$BOOT" > /sys/class/gpio/export
echo "out" > /sys/class/gpio/gpio$BOOT/direction
echo "1" > /sys/class/gpio/gpio$BOOT/value

echo "x735 Shutting down..."

while [ 1 ]; do
  shutdownSignal=$(cat /sys/class/gpio/gpio$SHUTDOWN/value)
  if [ $shutdownSignal = 0 ]; then
    /bin/sleep 0.2
  else
    pulseStart=$(date +%s%N | cut -b1-13)
    while [ $shutdownSignal = 1 ]; do
      /bin/sleep 0.02
      if [ $(($(date +%s%N | cut -b1-13)-$pulseStart)) -gt $REBOOTPULSEMAXIMUM ]; then
        echo "x735 Shutting down", SHUTDOWN, ", halting RPI ..."
        sudo poweroff
        exit
      fi
      shutdownSignal=$(cat /sys/class/gpio/gpio$SHUTDOWN/value)
    done
    if [ $(($(date +%s%N | cut -b1-13)-$pulseStart)) -gt $REBOOTPULSEMINIMUM ]; then
      echo "x735 Rebooting", SHUTDOWN, ", recycling RPI ..."
      sudo reboot
      exit
    fi
  fi
done' > /etc/x735pwr.sh
chmod +x /etc/x735pwr.sh
sed -i '$ i /etc/x735pwr.sh &' /etc/rc.local


#x735 full shutdown through Software
#!/bin/bash

    sed -e '/button/ s/^#*/#/' -i /etc/rc.local

    echo '#!/bin/bash

BUTTON=18
echo "$BUTTON" > /sys/class/gpio/export;
echo "out" > /sys/class/gpio/gpio$BUTTON/direction
echo "1" > /sys/class/gpio/gpio$BUTTON/value

SLEEP=${1:-4}

re='^[0-9\.]+$'
if ! [[ $SLEEP =~ $re ]] ; then
   echo "error: sleep time not a number" >&2; exit 1
fi

echo "x735 Shutting down..."
/bin/sleep $SLEEP

#restore GPIO 18
echo "0" > /sys/class/gpio/gpio$BUTTON/value
' > /usr/local/sbin/x735shutdown.sh
chmod +x /usr/local/sbin/x735shutdown.sh


#Automatically run above poweroff script on shutdown
echo '[Unit]
Description=Before Shutting Down
After=reboot.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/bin/true
ExecStop=/usr/local/sbin/x735shutdown.sh

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/before_shutdown.service
systemctl daemon-reload
systemctl enable before_shutdown.service
systemctl start before_shutdown.service

