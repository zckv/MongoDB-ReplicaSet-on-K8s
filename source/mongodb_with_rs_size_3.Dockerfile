FROM mongo

COPY /startup-mongo.sh /

CMD ["/startup-mongo.sh"]
