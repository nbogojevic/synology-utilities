DHCP DNS Sync synchronizes DNS server with DHCP lease information. With this package your Synology Router will correctly forward and reverse resolve hosts on your local network.

## Why do I need this?

You are running Synology Router DNS and DHCP services and you want dynamic DHCP reservations to update DNS accordingly.

# DHCP and DNS in Synology Router

Synology Router has an embedded DHCP server dynamically assings IP addresses to devices on your network. It also serves as simplified DNS server. On the other
hand you can install DNS package which adds full featured DNS server. However, DHCP server and DNS package don't talk to each other.

If LAN managed by Synology Router contains devices or servers that you want to access browser or other network programs, it would be helpful if one could use DNS names instead of IP addresses.

This project contains code to build a synology package that can be installed on Synology Routers and which provides update of DNS server by date comming from DHCP allocated IP addresses.

# Building the project

Project can be built using `package.sh` script from projet root.

```
$ ./package.sh [<destination-dir>]
```

This script will generate `DHCP-DNS-Sync.spk` either in `destination-dir` if it was provided or in project root directory.

# Installing the package

From package center of your Synology Router, choose Manual Install. Go to directory where the package has been built and choose the package.

You will be prompted to accept the license and to modify detected forward and reverse domain name zones. The script will log it's activity and you can see it by clicking `View Log` link in package manager.

### Credits

Derived from https://github.com/gclayburg/synology-diskstation-scripts

The script originated from Tim Smith here:

http://forum.synology.com/enu/viewtopic.php?f=233&t=88517

Original docs:

https://www.youtube.com/watch?v=T22xytAWq3A&list=UUp8GcSEeUnLY8d6RAT6Y3Mg
