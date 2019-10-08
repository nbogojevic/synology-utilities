#!/bin/ash

. $(dirname $0)/common.sh

NetworkInterfaces=",`ip -o link show | awk -F': ' '{printf $2","}'`"

date_echo "Network interfaces:"
date_echo $NetworkInterfaces

DNSServerRootDir=/var/packages/DNSServer/target
ZonePath=$DNSServerRootDir/named/etc/zone/master
DHCPAssigned=/etc/dhcpd/dhcpd.conf

# An address may not have been assigned yet so verify
# the leases log file exists before assigning.
DHCPLeases=/etc/dhcpd/dhcpd-leases.log
[ -f $DHCPLeases ] && DHCPAssigned="$DHCPAssigned $DHCPLeases"

DHCPStatic=/etc/dhcpd/dhcpd-static-static.conf
# this file may not exist if you haven't configured anything in the dhcp static reservations list (mac addr -> ip addr)
[ -f $DHCPStatic ] && DHCPAssigned="$DHCPAssigned $DHCPStatic"

DHCPLeaseFile=/etc/dhcpd/dhcpd.conf.leases
[ -f $DHCPLeaseFile ] && DHCPAssigned="$DHCPAssigned $DHCPLeaseFile"


##########################################################################
# Back up the forward and reverse master files
# Two options: a) One backup which is overwritten each time 
# or b) file is backed up once each day... but only the first use and
# retained for one year.
#
if ! mkdir -p ${BackupPath}; then
  date_echo "Error: cannot create backup directory"
  exit 3
fi

tmpPrefix=$BackupPath/DNS_Backup_$(date +%m%d)
date_echo "Backing up DNS files to $tmpPrefix.*"
[ -f $tmpPrefix.$ForwardMasterFile ] && date_echo "INFO: Forward master already backed up for today." || cp -a $ZonePath/$ForwardMasterFile $tmpPrefix.$ForwardMasterFile
[ -f $tmpPrefix.$ReverseMasterFile ] && date_echo "INFO: Reverse master already backed up for today." || cp -a $ZonePath/$ReverseMasterFile $tmpPrefix.$ReverseMasterFile

# Declare reusable functions.  Logic is pretty much the same for forward and reverse files.
printPartialDNSFile () {
   # Pass in the DNS file to process (forward or reverse master)
   # Print everything except for PTR and A records.
   # The only exception are "ns.domain" records.  We keep those.
   #Assumptions:
   # PTR and A records should be removed unless they contain "ns.<NetworkDomain>."
   awk '
    {
        if ($5 != ";dynamic") {
            PrintThis=1;
        } else{
            PrintThis=0;
        }
    }
    (PrintThis == 1) {print $0 }
   ' $1
}

printDhcpAsRecords () {
# Pass in "A" for A records and "PTR" for PTR records.
# Process the DHCP static and dynamic records
# Logic is the same for PTR and A records.  Just a different print output.
# Sorts and remove duplicates. Filters records you don't want.
    awk -v NetworkDomain=$NetworkDomain -v RecordType=$1  -v StaticRecords=$2 -v adapters=$NetworkInterfaces '
        BEGIN {
           # Set awks field separator
           FS="[\t =,]";
        }
        {IP=""} # clear out variables
        # Leases start with numbers. Do not use if column 4 is an interface
        $1 ~ /^[0-9]/ {  if(NF>4 || index(adapters, "," $4 "," ) == 0) { IP=$3; NAME=$4; RENEW=86400 } } 
        # Static assignments start with dhcp-host
        $1 == "dhcp-host" {IP=$4; NAME=$3; RENEW=$5}
        # If we have an IP and a NAME (and if name is not a placeholder)
        (IP != "" && NAME!="*" && NAME!="") {
           split(IP,arr,".");
           ReverseIP = arr[4] "." arr[3] "." arr[2] "." arr[1];
           if(RecordType == "PTR" && index(StaticRecords, ReverseIP ".in-addr.arpa.," ) > 0) {IP="";}
           if(RecordType == "A" && index(StaticRecords, NAME "." NetworkDomain ".," ) > 0) {IP="";}
           # Remove invalid characters according to rfc952
           gsub(/([^a-zA-Z0-9-]*|^[-]*|[-]*$)/,"",NAME)
           # Print the last number in the IP address so we can sort the addresses
           # Add a tab character so that "cut" sees two fields... it will print the second
           # field and remove the first which is the last number in the IP address.
           if(IP != "" && NAME!="*" && NAME!="") {
               if (RecordType == "PTR") {print 1000 + arr[4] "\t" ReverseIP ".in-addr.arpa.\t" RENEW "\tPTR\t" NAME "." NetworkDomain ".\t;dynamic"}
               if (RecordType == "A") print 2000 + arr[4] "\t" NAME "." NetworkDomain ".\t" RENEW "\tA\t" IP "\t;dynamic"
           }
        }
    ' $DHCPAssigned| sort | cut -f 2- | uniq


}

incrementSerial () {
# serial number must be incremented in SOA record when DNS changes are made so that slaves will recognize a change
  ser=$(sed -e '1,/.*SOA/d' $1 | sed -e '2,$d' -e 's/;.*//' )  #isolate DNS serial from first line following SOA
  comments=$(sed -e '1,/.*SOA/d' $1 | sed -e '2,$d' | sed -n '/;/p' |sed -e 's/.*;//' )  #preserve any comments, if any exist
  bumpedserial=$(( $ser +1 ))

  sed -n '1,/.*SOA/p' $1
  echo -e "\t$bumpedserial ;$comments"
  sed -e '1,/.*SOA/d' $1 | sed -n '2,$p'


}
##########################################################################
# FORWARD MASTER FILE FIRST - (Logic is the same for both)
# Print everything except for PTR and A records.
# The only exception are "ns.domain" records.  We keep those.
#Assumptions:
# PTR and A records should be removed unless they contain "ns.<NetworkDomain>."
date_echo "Regenerating forward master file $ForwardMasterFile"
PARTIAL="$(printPartialDNSFile $ZonePath/$ForwardMasterFile)"
date_echo "forward master file static DNS addresses:"
echo "$PARTIAL"
echo
STATIC=$(echo "$PARTIAL"|awk '{if(NF>3 && NF<6) print $1}'| tr '\n' ',')
echo "$PARTIAL"  > $BackupPath/$ForwardMasterFile.new
date_echo "adding these DHCP leases to DNS forward master file:"
printDhcpAsRecords "A" $STATIC
echo
printDhcpAsRecords "A" $STATIC >> $BackupPath/$ForwardMasterFile.new

incrementSerial $BackupPath/$ForwardMasterFile.new > $BackupPath/$ForwardMasterFile.bumped

##########################################################################
# REVERSE MASTER FILE - (Logic is the same for both)
# Print everything except for PTR and A records.
# The only exception are "ns.domain" records.  We keep those.
#Assumptions:
# PTR and A records should be removed unless they contain "ns.<NetworkDomain>."
date_echo "Regenerating reverse master file $ReverseMasterFile"
PARTIAL="$(printPartialDNSFile $ZonePath/$ReverseMasterFile)"
STATIC=$(echo "$PARTIAL"|awk '{if(NF>3 && NF<6) print $1}'| tr '\n' ',')
date_echo "Reverse master file static DNS addresses:"
echo "$PARTIAL"
echo
echo "$PARTIAL" > $BackupPath/$ReverseMasterFile.new
date_echo "adding these DHCP leases to DNS reverse master file: "
printDhcpAsRecords "PTR" $STATIC
echo
printDhcpAsRecords "PTR" $STATIC >> $BackupPath/$ReverseMasterFile.new
incrementSerial $BackupPath/$ReverseMasterFile.new > $BackupPath/$ReverseMasterFile.bumped


##########################################################################
# Ensure the owner/group and modes are set at default
# then overwrite the original files
date_echo "Overwriting with updated files: $ForwardMasterFile $ReverseMasterFile"
if ! chown nobody:nobody $BackupPath/$ForwardMasterFile.bumped $BackupPath/$ReverseMasterFile.bumped ; then
  date_echo "Error:  Cannot change file ownership"
  date_echo ""
  date_echo "Try running this script as root for correct permissions"
  exit 4
fi
chmod 644 $BackupPath/$ForwardMasterFile.bumped $BackupPath/$ReverseMasterFile.bumped
#cp -a $BackupPath/$ForwardMasterFile.new $ZonePath/$ForwardMasterFile 
#cp -a $BackupPath/$ReverseMasterFile.new $ZonePath/$ReverseMasterFile 

mv -f $BackupPath/$ForwardMasterFile.bumped $ZonePath/$ForwardMasterFile
mv -f $BackupPath/$ReverseMasterFile.bumped $ZonePath/$ReverseMasterFile

##########################################################################
# Reload the server config after modifications
$DNSServerRootDir/script/reload.sh

date_echo "$0 complete."
exit 0