#! /bin/bash

docker run -i --rm nbogojevic/freenom-dynamic $1 $2 $3 $4 -Update 

# Uncomment to collect verbose logs
# docker run -i --rm nbogojevic/freenom-dynamic $1 $2 $3 $4 -Update -Verbose >> /var/log/freenom.log 2>&1