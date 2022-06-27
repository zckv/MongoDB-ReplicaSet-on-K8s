#!/bin/bash

export OS_PROJECT_NAME="CMS Web"
export OS_PROJECT_DOMAIN_ID="default"
source /sec/cmsweb-openrc.sh
openstack coe cluster list
openstack volume snapshot create --volume $VOLUME_NAME $SNAPSHOT_NAME