#!/bin/bash

if [ -z "$ID" ]; then
    # set ID to master per default
    export ID="0"
fi

if [ -z "$RS_NAME" ]; then
    export RS_NAME="mongo_rs"
fi

if [ -z "$PORT" ]; then
    # set PORT to default
    export PORT="27017"
fi

if [ -z "$IP" ]; then
    # Should work fine in almost every case
    export IP="$(hostname -i)"
fi

# create folder for db
mkdir -p "/data/db/rs-$ID"

echo "Starting mongo on $IP:$PORT"
echo "ID $ID in replSet $RS_NAME"

mongo_initiate_rs_conf()
{
	slave_id=1
	members=""
	echo "SLAVES are $SLAVES"
	for slave in ${SLAVES//,/ } ;
	do
		# Mongo can't use more than 7 members with priority / descision power
		if [[ $slave_id -lt 6 ]] ; 
		then 
			members="{_id : $slave_id, host : '$slave', priority : 0.5}, $members"
		else
			members="{_id : $slave_id, host : '$slave'}, $members"
		fi
		slave_id=$((slave_id+1))
	done

	sleep 5
	echo "SENDING CONFIG"
    # Send ReplicaSet config to Mongod using mongosh
    mongosh --eval "rsname = '$RS_NAME'" --shell << EOL
cfg = {
    _id: rsname,
    members:
	[
		$members
	    {_id : 0, host : '$IP:$PORT', priority : 2}
    ]
}
rs.initiate(cfg)
EOL
}

config_master()
{
    # Configure master node
    echo "Configuration of Master node"
    echo "Slaves are: \"$SLAVES\""

	# Config first try
	mongo_initiate_rs_conf

	retryCount=0
	echo "Checking MongoDB status:"
	while [[ "$(mongosh --quiet --eval 'rs.status().ok')" != 1 ]]; do
		if [ $retryCount -gt 30 ]; then
			echo "Retry count > 30, breaking out of while loop now..."
			break
		fi
		echo "MongoDB not ready for Replica Set configuration, retrying in 5 seconds..."
		echo "Current rs status: $(mongosh --quiet --eval 'rs.status().ok')"
		mongo_initiate_rs_conf
		retryCount=$((retryCount+1))
	done

	echo "Replica Set configuration successful..."
}

if [ "$ID" == "0" ]; then
    config_master &
fi

mongod --quiet --replSet "$RS_NAME" --port "$PORT" --bind_ip localhost,"$IP" --dbpath "/data/db/rs-$ID" --oplogSize 128
