FROM mongo

LABEL org.opencontainers.image.source=https://github.com/zckv/MongoDB-ReplicaSet-on-K8s

COPY /startup-mongo.sh /

CMD ["/startup-mongo.sh"]
