#!/bin/sh


DhcpDomain=`cat /etc/dhcpd/dhcpd.conf | awk '
BEGIN { FS="[\t =,]"; }
$1 == "domain" { DOMAIN=$2 }
END { print DOMAIN }
'`

DhcpIpStart=`cat /etc/dhcpd/dhcpd.conf | awk '
BEGIN { FS="[\t =,]"; }
$1 == "dhcp-range" && $2 == "set:lbr00" { IP_START = $3;}
END { print IP_START }
'`

DhcpIpMask=`cat /etc/dhcpd/dhcpd.conf | awk '
BEGIN { FS="[\t =,]"; }
$1 == "dhcp-range" && $2 == "set:lbr00" { MASK = $5}
END { print MASK }
'`


DhcpIpForReverse4=$((`echo $DhcpIpStart | cut -d\. -f4` &  `echo $DhcpIpMask | cut -d\. -f4`))
DhcpIpForReverse3=$((`echo $DhcpIpStart | cut -d\. -f3` &  `echo $DhcpIpMask | cut -d\. -f3`))
DhcpIpForReverse2=$((`echo $DhcpIpStart | cut -d\. -f2` &  `echo $DhcpIpMask | cut -d\. -f2`))
DhcpIpForReverse1=$((`echo $DhcpIpStart | cut -d\. -f1` &  `echo $DhcpIpMask | cut -d\. -f1`))
HasAddress="0"
ReverseIp=""
if [[ $DhcpIpForReverse4 != "0" ]]; then
	ReverseIp="$DhcpIpForReverse4."
	HasAddress="1"
fi
if [[ $HasAddress == "1" || $DhcpIpForReverse3 != "0" ]]; then
	ReverseIp="${ReverseIp}$DhcpIpForReverse3."
	HasAddress="1"
fi
if [[ $HasAddress == "1" || $DhcpIpForReverse2 != "0" ]]; then
	ReverseIp="${ReverseIp}$DhcpIpForReverse2."
	HasAddress=1
fi
if [[ $HasAddress == "1" || $DhcpIpForReverse1 != "0" ]]; then
	ReverseIp="${ReverseIp}$DhcpIpForReverse1"
fi

cat > $SYNOPKG_TEMP_LOGFILE <<EOF
[{
    "step_title": "Configure DHCP DNS Sync",
    "items": [{
        "type": "textfield",
        "desc": "Polling settings",
        "subitems": [{
            "key": "WZ_POLL_INTERVAL",
            "desc": "Polling interval in seconds",
            "defaultValue": "30",
            "validator": {
                "allowBlank": false,
                "minLength": 1,
                "maxLength": 4,
                "regex": {
                    "expr": "/[1-9][0-9]?[0-9]?[0-9]?/i",
                    "errorText": "Value must be number between 1 and 9999."
                }
            }
        }]
    },{
        "type": "textfield",
        "desc": "DNS Settings",
        "subitems": [{
            "key": "WZ_DOMAIN",
            "desc": "Forward DNS zone",
            "defaultValue": "$DhcpDomain",
            "validator": {
                "minLength": 2,
                "maxLength": 60,
                "regex": {
                    "expr": "/^((?!-))((xn--)?[a-z0-9][a-z0-9\\\\-_]{0,61}[a-z0-9]{0,1}\\\\.)?((xn--)?([a-z0-9\\\\-]{1,61}|[a-z0-9\\\\-]{1,30}\\\\.))?[a-z]{2,}\$/i",
                    "errorText": "Value must be base valid forward DNS zone (e.g. example.com)."
                }
            }
        },{
            "key": "WZ_REVERSE",
            "desc": "Reverse DNS zone",
            "defaultValue": "${ReverseIp}.in-addr.arpa",
            "validator": {
                "regex": {
                    "expr": "/^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\\\.){0,3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).in-addr.arpa\$/i",
                    "errorText": "Value must be base valid reverse DNS zone (e.g. 1.162.198.in-addr.arpa)."
                }
            }
        }]
    }]
}]
EOF

exit 0