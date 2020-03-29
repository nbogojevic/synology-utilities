# Synology Utilities
Various utilities to manage Synology NAS and routers

# NAS/DSM

`update-docker-images.sh` checks if running containers have newer version of images and if so, pulls new images and updates containers (stops, cleans and restarts containers using DSM Docker API). Script only checks for newer versions of images with same name and tag. Script reads configuration from update-docker-images.conf either from current directory or from HOME directory of the user running script. As script uses docker CLI, it must be run as `root` user.

`switch-fan-to-low-speed.sh` activates low speed for Synology NAS fan. Can be used with scheduled tasks to activate quiet mode when needed.

`switch-fan-to-high-speed.sh` activates high speed for Synology NAS fan. Can be used with scheduled tasks to activate cooling mode when needed.

`synology-freenom.sh` can be used as DDNS module for Synology DSM. To use it, append following at the end of the file 
`/etc.defaults/ddns_provider.conf`

```ini
[Freenom]
        modulepath=/path-to-your-git-repository/synology-freenom.sh
        queryurl=https://my.freenom.com/
```

# Router/SRM

DHCP-DNS-Sync allows synchronizing DNS Server with DHCP leases given out by Router.
