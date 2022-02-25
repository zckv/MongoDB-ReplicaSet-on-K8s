# MongoDB ReplicaSet On K8s

This project containers all necessary files to launch a MongoDB ReplicaSet with 3 Mongo instances on a K8s cluster.

Here are some files you can find in this project:

- **Helm chart** (for easy launching on K8s)
- **Dockerfile** (based on official MongoDB image version 4.2.3, with custom startup scripts)
- **Custom startup scripts** (for copying into Docker image)
- **K8s manifest** (for those of you who wants to build on top of the current resources definition)
  
For more information on how this replicaset is formed, please refer to this [article](https://medium.com/swlh/how-to-setup-mongodb-replica-set-on-kubernetes-in-minutes-5c1e7fd5b5f3).

****

## Configuring Persistent Volume

This Helm Chart is developed on the CERN cloud. It uses by default the `geneva-cephfs-testing` storage class. 

If you want to deploy on another cloud provider, or use another StorageClass, you will need to change the storageClass updating `values.yaml` (`./helm-chart/values.yaml`).

****

## Launching MongoDB ReplicaSet

Using Helm, you can launch the application with the the following command, but first you need to create a namespace for the monitoring tools:

```bash
kubectl create namespace monitoring
```

Before installing helm please change the monitoring configuration files accoridingly. Specifically the `job_name` for mongodb-exporter in `helm-chart/files/prometheus-secrets/prometheus.yaml` should be changed to be able to enable monitoring.
The `remote_write` section should also be uncommented to enable pushing metrics to the central cms monitoring portal.

```bash
helm install mongodb --set db.auth.password='xxx' --set db.auth.keyfile="$(openssl rand -base64 756)" --set db.rsname='rsName' --set db.nodeHostname='something-node-0.cern.ch' . 
```
The db.auth.password argument is the password for both the `usersAdmin` and `clusterAdmin` users.
The db.auth.keyfile is the keyfile that mongo needs to enable authentication. The `openssl rand -base64 756` command generates a random file.
The db.rsname is the name of the replica set. This is an optional argument, by default the name of the replicaset is `cms-rs`.
The db.nodeHostname is the hostname of a k8s node. This is used to configure the replicaset using the node hostname and the ports 32001, 32002 and 32003.

You should see the deploy confirmation message similar to below:

```plain
NAME: mongo
LAST DEPLOYED: Wed Oct 13 09:21:42 2021
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

Give this deployment aronud 2-3 minutes to initiate, it will do the following:

- Schedule Pods to Node
- Start `Persistent Volume` and attach Pod to `Persistent Volume` via `Persistent Volume Claim`
- Pull image from DockerHub
- Start Containers
- Start `Mongod` and initiate `ReplicaSet`
- Create `usersAdmin` and `clusterAdmin` users
- Deploy `prometheus`, `prometheus-adapter`, `kube-eagle` and `mongodb-exporter` tools for monitoring

****

## Verifying Launch Status

You can verify the K8s resources status with the this command:

```bash
kubectl get all -n default # -n is the namespace
```

Example Output - In the processing of launching:

```plain
NAME                             READY   STATUS              RESTARTS   AGE
pod/mongodb-0-9b8c6f869-pnfqk    0/1     ContainerCreating   0          1s
pod/mongodb-1-658f95995d-j26zp   0/1     ContainerCreating   0          1s
pod/mongodb-2-6cbb444455-jj6w9   0/1     ContainerCreating   0          1s

NAME                        TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)     AGE
service/kubernetes          ClusterIP   10.0.0.1       <none>        443/TCP     30m
service/mongodb-0-service   NodePort    10.254.108.76    <none>        27017:32001/TCP   1s
service/mongodb-1-service   NodePort    10.254.186.152   <none>        27017:32002/TCP   1s
service/mongodb-2-service   NodePort    10.254.140.157   <none>        27017:32003/TCP   1s
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/mongodb-0   0/1     1            0           1s
deployment.apps/mongodb-1   0/1     1            0           1s
deployment.apps/mongodb-2   0/1     1            0           1s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/mongodb-0-9b8c6f869    1         1         0       1s
replicaset.apps/mongodb-1-658f95995d   1         1         0       1s
replicaset.apps/mongodb-2-6cbb444455   1         1         0       1s
```

Example Output - Launching completed:

```plain
NAME                             READY   STATUS              RESTARTS   AGE
pod/mongodb-0-9b8c6f869-pnfqk    1/1     Running             1          20s
pod/mongodb-1-658f95995d-j26zp   1/1     Running             1          20s
pod/mongodb-2-6cbb444455-jj6w9   1/1     Running             1          20s

NAME                        TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)     AGE
service/kubernetes          ClusterIP   10.0.0.1       <none>        443/TCP     30m
service/mongodb-0-service   NodePort    10.254.108.76    <none>        27017:32001/TCP   20s
service/mongodb-1-service   NodePort    10.254.186.152   <none>        27017:32002/TCP   20s
service/mongodb-2-service   NodePort    10.254.140.157   <none>        27017:32003/TCP   20s
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/mongodb-0   1/1     1            1           20s
deployment.apps/mongodb-1   1/1     1            1           20s
deployment.apps/mongodb-2   1/1     1            1           20s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/mongodb-0-9b8c6f869    1         1         1       20s
replicaset.apps/mongodb-1-658f95995d   1         1         1       20s
replicaset.apps/mongodb-2-6cbb444455   1         1         1       20s
```

You can verify the monitoring status with the this command:

```bash
kubectl get all -n monitoring
```

You can check the MongoDB ReplicaSet status by via Mongo Shell:

```bash
kubectl exec -it -n default <pod-name> mongo -u clusterAdmin -p password
# <pod-name> is the name of pod, for example it could be pod/mongodb-0-7d44df6f6-h49jx
```

Once you get into Mongo Shell, you will see the following:

```plain
rsName:PRIMARY>
```

Congratulations! You have just formed your own MongoDB ReplicaSet, any data written onto the Primary instance will now be replicated onto secondary instances. If the primary instance were to stop, one of the secondary instances will take over the primary instance's role.

You can view the replica configuration in the Mongo Shell by:

```bash
rsName:PRIMARY> rs.config()
```

****

## Using MongoDB ReplicaSet

Now that you've started MongoDB, you may connect your clients to it with Mongo Connect String URI.

The installation is using NodePort services on the ports 32001, 32002 and 32003:
```bash
 mongo mongodb://mongo-cms-fcmki4ox2hnr-node-0.cern.ch:32001,mongo-cms-fcmki4ox2hnr-node-0.cern.ch:32002,mongo-cms-fcmki4ox2hnr-node-0.cern.ch:32003/admin?replicaSet=rs0 -u clusterAdmin
```

You can also use the loadbalancing service created with helm. If a hostname is added to the lodbalancer (using the `openstack loadbalancer set --description` command) then mongodb can be acessed in this hostname:

```bash
mongodb://mongodb-cms.cern.ch:27017/?replicaSet=cms-db -u clusterAdmin
```

## Backups

### Taking backups
Backups of the DB can be taken using the openstack snapshot capability.
Essentially we take a snapshot of the volume attached to the PRIMARY replica of MongoDB (due to weighted election this is in most cases `mongodb-0`)

To take a backup (force flag must be used to take snapshot of in-use volume): 
```bash
openstack volume snapshot create --volume $VOLUME_NAME $SNAPSHOT NAME
```

To list all snapshots and make sure snapshot is created:

```bash
openstack volume snapshot list
```

### Restoring backups

#### To existing cluster

In order to restore from a snapshot to an existing cluster we need to:

1. Create a new volume based on a snapshot:

```bash
openstack volume create --description "restored from snapshot 3c8bb939-ca1c-4dbb-9837-5870be2c9cd3" --snapshot 27de5435-8d49-42bd-b8d9-5902d4466858 restored-dev-volume
```

2. Remove two of the three nodes from the replicaset:

Connect to mongodb and run:
```bash
rs.status() //To get the hostnames of the nodes
rs.remove('hostname1')
rs.remove('hostname2')
```

3. Tweak the deployment of mongodb-0 pod to use the new volume:

replace:

```bash
- name: {{.Values.db.instance0.pvName}}
    persistentVolumeClaim:
        claimName: {{.Values.db.instance0.pvName}}
```
with:
```bash
- name: {{.Values.db.instance0.pvName}}
    cinder:
        volumeID: $ID_OF_RESTORED_VOLUME
```

4. Re-deploy the mongodb-0 pod. Exec in it and connect to mongo with the clusterAdmin user:

```bash
kubectl exec -it $POD_NAME -- bash
mongo -u clusterAdmin
```

5. Force the current node (and the only one in the replica set) as primary:

```bash
cfg = {
    "_id" : "cms-db",
    "version" : 14,
    "members" : [
        {
            "_id" : 0,
            "host" : "mongodb-dev-valj3pvr5lkl-node-0.cern.ch:32001"
        }
    ]
}
rs.reconfig(cfg, {force: true})
```

6. Delete the two old deployment for pod-1 and pod-2 and delete the volumes they were using. We need fresh volumes so that replication will get the data from the snapshot in them.

```bash
kubectl delete deployment mongodb-1
kubectl delete deployment mongodb-2
kubectl delete pvc pvc-1, pvc-2
openstack volume delete vol1, vol2
```

7. Redeploy deployments for pod-1 and pod-2 and wait until all pods are up an running.

8. Connect to mongodb with `clusterAdmin` user and add again the two nodes to the replicaset:

```bash
cfg = {
    "_id" : "cms-db",
    "version" : 15,
    "members" : [
        {
            "_id" : 0,
            "host" : "mongodb-dev-valj3pvr5lkl-node-0.cern.ch:32001"
        },
        {
            "_id" : 1,
            "host" : "mongodb-dev-valj3pvr5lkl-node-0.cern.ch:32002"
        },
        {
            "_id" : 2,
            "host" : "mongodb-dev-valj3pvr5lkl-node-0.cern.ch:32003"
        }
    ]
}
rs.reconfig(cfg)
```
#### To a new cluster

TBC


## Debuging

In case you have created a cluster with monitoring enabled you need to delete some of the default monitoring resources so that helm can install and manage them:

```
kubectl delete ClusterRole prometheus-adapter-server-resources
kubectl delete ClusterRole prometheus-adapter-resource-reader
kubectl delete ClusterRoleBinding prometheus-adapter:system:auth-delegator
kubectl delete ClusterRoleBinding prometheus-adapter-resource-reader
kubectl delete ClusterRoleBinding prometheus-adapter-hpa-controlle
kubectl delete APIService v1beta1.custom.metrics.k8s.io
```

In case you need a pod with mongo cli to debug connection to the DB you can spawn one using:

```bash
kubectl run mongosh --image=mongo --restart=Never
```