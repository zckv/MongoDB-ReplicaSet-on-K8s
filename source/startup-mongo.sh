#!/bin/bash

if [ -z "$MONGODB_ID" ]; then
    # set MONGODB_ID to master per default
    export MONGODB_ID="0"
fi

if [ -z "$MONGODB_RS" ]; then
    export MONGODB_RS="mongo_rs"
fi

if [ -z "$POD_X_PORT" ]; then
    # set POD_X_PORT to default
    export POD_X_PORT="27017"
fi

if [ -z "$POD_X_IP" ]; then
    # Should work fine in almost every case
    export POD_X_IP="$(hostname -i)"
fi

# create folder for db
mkdir -p "/data/db/rs-$MONGODB_ID"

echo "Starting mongo on $POD_X_IP:$POD_X_PORT"
echo "ID $MONGODB_ID in replSet $MONGODB_RS"

mongo_initiate_rs_conf()
{
    # Send ReplicaSet config to Mongod using mongosh
    mongosh --eval "mongodb = ['$POD_X_IP:$POD_X_PORT', '$POD_1_IP:$POD_1_PORT', '$POD_2_IP:$POD_2_PORT'], rsname = '$MONGODB_RS'" --shell << EOL
cfg = {
    _id: rsname,
    members:
	[
	    {_id : 0, host : mongodb[0], priority : 1},
            {_id : 1, host : mongodb[1], priority : 0.9},
            {_id : 2, host : mongodb[2], priority : 0.5}
        ]
    }
rs.initiate(cfg)
EOL
}

config_master()
{
    # Configure master node
    echo "Configuration to Master Mode"
    echo "POD_1_IP=$POD_1_IP"
    echo "POD_1_PORT=$POD_1_PORT"
    echo "POD_2_IP=$POD_2_IP"
    echo "POD_2_PORT=$POD_2_PORT"

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
		sleep 5
		mongo_initiate_rs_conf
		retryCount=$((retryCount+1))
	done

	echo "Replica Set configuration successful..."
}

if [ "$MONGODB_ID" == "0" ]; then
    config_master &
fi

mongod --quiet --replSet "$MONGODB_RS" --port "$POD_X_PORT" --bind_ip localhost,"$POD_X_IP" --dbpath "/data/db/rs-$MONGODB_ID" --oplogSize 128
