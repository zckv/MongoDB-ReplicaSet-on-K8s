#!/bin/bash

source /etc/cmsweb-openrc.sh
export OS_PROJECT_NAME="CMS Web"
openstack volume snapshot create --volume $VOLUME_NAME $SNAPSHOT_NAME