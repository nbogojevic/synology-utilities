#! /bin/sh
#
# Switch synology to low speed
sed -i s/fan_config_type_internal=\"high\"/fan_config_type_internal=\"low\"/g /etc/synoinfo.conf
# Load changes
scemd
