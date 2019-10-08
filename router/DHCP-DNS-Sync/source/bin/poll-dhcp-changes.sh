#!/bin/ash

. $(dirname $0)/common.sh

while true; do
   ATIME=`stat /etc/dhcpd/dhcpd-leases.log | grep Modify`
   
   if [[ "$ATIME" != "$LTIME" ]]; then
     find $LogPath -name $LogFileName -type f -size +100k -exec rm {} \;
     date_echo "dhcp leases changed - reloading DNS" >> $LogFile
     $BinPath/dhcp-dns-sync.sh >> $LogFile 2>&1 
     LTIME=$ATIME
   fi
   sleep $PollInterval
done