# Synology Utilities
Various utilities to manage Synology NAS and routers

# NAS/DSM

`update-docker-images.sh` checks if running containers have newer version of images and if so, pulls new images and updates containers (stops, cleans and restarts containers using DSM Docker API). Script only checks for newer versions of images with same name and tag. Script reads configuration from `update-docker-images.conf` either from current directory or from HOME directory of the user running script. As script uses docker CLI, it must be run as `root` user.

Following environment variables can be used to configure script:

```bash
# Name of the host to administer (should be local machine)
SYNOLOGY_HOST=${SYNOLOGY_HOST:-http://localhost:5000}
# The admin username
SYNOLOGY_USER=${SYNOLOGY_USER:-admin}
# The admin password
SYNOLOGY_PASSWORD=${SYNOLOGY_PASSWORD:-password}
# Should old docker images be deleted (yes or no)
DOCKER_PRUNE=${DOCKER_PRUNE:-no}
# Images to check/update, separated by new lines
IMAGES_TO_PULL=${IMAGES_TO_PULL:-}
```

`switch-fan-to-low-speed.sh` activates low speed for Synology NAS fan. Can be used with scheduled tasks to activate quiet mode when needed.

`switch-fan-to-high-speed.sh` activates high speed for Synology NAS fan. Can be used with scheduled tasks to activate cooling mode when needed.

`synology-freenom.sh` can be used as DDNS module for Synology DSM. To use it, append following at the end of the file 
`/etc.defaults/ddns_provider.conf`

```ini
[Freenom]
        modulepath=/path-to-your-git-repository/synology-freenom.sh
        queryurl=https://my.freenom.com/
```

You can add it to the DDNS configuration in Control Panel > External Access. Enter Freenom credentials. In the host field, either enter `all` to update all your domains, or enter specific domain you want to update.

# Router/SRM

DHCP-DNS-Sync allows synchronizing DNS Server with DHCP leases given out by Router.
