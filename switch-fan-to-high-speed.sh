#! /bin/sh
#
# Switch synology to high speed
sed -i s/fan_config_type_internal=\"low\"/fan_config_type_internal=\"high\"/g /etc/synoinfo.conf
# Load changes
scemd
