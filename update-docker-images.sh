#! /bin/sh

# Load configuration
if [ -f "$HOME/update-docker-images.conf" ]; then
	source "$HOME/update-docker-images.conf"
fi
if [ -f "./update-docker-images.conf" ]; then
	source "./update-docker-images.conf"
fi

# Set default values
SYNOLOGY_HOST=${SYNOLOGY_HOST:-http://localhost:5000}
SYNOLOGY_USER=${SYNOLOGY_USER:-admin}
SYNOLOGY_PASSWORD=${SYNOLOGY_PASSWORD:-password}
DOCKER_PRUNE=${DOCKER_PRUNE:-no}

# Get session from Synology DSM
echo "Logging in to $SYNOLOGY_HOST as user $SYNOLOGY_USER"
SESSION_ID=`curl --silent "$SYNOLOGY_HOST/webapi/auth.cgi?api=SYNO.API.Auth&version=2&method=login&account=$SYNOLOGY_USER&passwd=$SYNOLOGY_PASSWORD&format=cookie&session=Docker" | jq --raw-output .data.sid`

# Ger running containers
echo "Retreiving running containers"
CONTAINERS=`curl --silent $SYNOLOGY_HOST/webapi/entry.cgi -b id=$SESSION_ID -d "stop_when_error=true&mode=%22sequential%22&compound=%5B%7B%22api%22%3A%22SYNO.Docker.Container%22%2C%22method%22%3A%22list%22%2C%22version%22%3A1%2C%22limit%22%3A-1%2C%22offset%22%3A0%7D%2C%7B%22api%22%3A%22SYNO.Docker.Container.Resource%22%2C%22method%22%3A%22get%22%2C%22version%22%3A1%7D%5D&api=SYNO.Entry.Request&method=request&version=1"`
# Extract images that should be updated
IMAGES_TO_PULL=`echo $CONTAINERS | jq --raw-output .data.result[0].data.containers[].image`

IFS=$'\n'
UPDATED_IMAGES=""
for IMAGE in $IMAGES_TO_PULL
do
	# Pull each image
	echo "Pulling $IMAGE"
	# If new image has been downloaded add it to list of images to update
	docker pull $IMAGE | tee /dev/tty | grep "Status: Downloaded" > /dev/null && UPDATED_IMAGES="$UPDATED_IMAGES$IMAGE\n"
done

UPDATED_IMAGES=`echo -e "$UPDATED_IMAGES"`

# If environment variable RECYCLE_CONTAINERS is set to all, recycle all running containers
if [ "$RECYCLE_CONTAINERS" == "all" ]; then
	UPDATED_IMAGES="$IMAGES_TO_PULL"
# If environment variable RECYCLE_CONTAINERS is set to none, do not recycle containers
elif [ "$RECYCLE_CONTAINERS" == "none" ]; then
	UPDATED_IMAGES=""
fi

EVERYTHING_OK="yes"
for IMAGE in $UPDATED_IMAGES
do
	CONTAINER_NAME=`echo "$CONTAINERS" | jq --raw-output --arg IMAGE "$IMAGE" '.data.result[0].data.containers[] | select(.["image"] | contains($IMAGE)) | .name'`
	echo "Stopping $CONTAINER_NAME"
	OPERATION_FAILED="no"
	# Stop container
	if curl --silent $SYNOLOGY_HOST/webapi/entry.cgi -b "id=$SESSION_ID" -d "name=%22$CONTAINER_NAME%22&api=SYNO.Docker.Container&method=stop&version=1" | jq '.success == true' > /dev/null; then
		echo "Cleaning $CONTAINER_NAME"	
		# Clean container contents
		curl --silent $SYNOLOGY_HOST/webapi/entry.cgi -b "id=$SESSION_ID" -d "name=%22$CONTAINER_NAME%22&force=false&preserve_profile=true&api=SYNO.Docker.Container&method=delete&version=1" | jq '.success == true' > /dev/null || (echo "Unable to clean container $CONTAINER_NAME" >&2 && OPERATION_FAILED="yes")
		# Restart new container with old configuration
		echo "Restarting $CONTAINER_NAME"	
		curl --silent $SYNOLOGY_HOST/webapi/entry.cgi -b "id=$SESSION_ID" -d "name=%22$CONTAINER_NAME%22&api=SYNO.Docker.Container&method=start&version=1" | jq '.success == true' > /dev/null || (echo "Unable to restart $CONTAINER_NAME" >&2 && OPERATION_FAILED="yes")
	else
		OPERATION_FAILED="yes"
		EVERYTHING_OK="no"
		echo "Unable to stop container $CONTAINER_NAME" >&2
	fi

	if [ "$OPERATION_FAILED" == "yes" ]; then
		echo "Error while to upgrade $CONTAINER_NAME with new $IMAGE" >&2
	else
		# If a container has been successfuly recycled, add prune
		echo "Finished upgrading $CONTAINER_NAME with new $IMAGE"
	fi
done

if [ "$EVERYTHING_OK" == "yes" ]; then
	# Prune docker unused images
	if [ "$DOCKER_PRUNE" == "yes" ]; then
		echo "Cleaning unused images."
		docker image prune --force
	fi
	echo "Finished." >&2
	exit 0
else
	echo "There were errors." >&2
	exit 1
fi
