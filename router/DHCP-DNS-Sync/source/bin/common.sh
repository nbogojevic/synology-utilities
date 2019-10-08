SettingsFile=$SYNOPKG_PKGDEST/etc/dhcp-dns-sync.conf

if [ -r $SettingsFile ]; then
  . $SettingsFile
else
  date_echo "FATAL: $SettingsFile file not found or not readable"
  exit 3
fi

date_echo(){
    datestamp=$(date +%F_%T)
    echo "${datestamp} - $*"
}

