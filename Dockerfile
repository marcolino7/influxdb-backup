FROM influxdb:latest
MAINTAINER Marcolino <marcolino@infinito.it>



# Copy backup script and add permission
COPY my-influx-backup.sh /usr/bin/my-influx-backup
RUN chmod 0755 /usr/bin/my-influx-backup

ENTRYPOINT ["/usr/bin/my-influx-backup"]
CMD ["cron", "0 1 * * *"]