#!/bin/sh

set -e

echo "Setting Env. Variabiles"
: ${DATABASE:?"DATABASE env variable is required"}
export DATETIME=$(date "+%Y%m%d%H%M%S")
export BACKUP_PATH=${BACKUP_PATH:-/var/lib/influxdb/backup/}
export BACKUP_ARCHIVE_PATH=${BACKUP_ARCHIVE_PATH:-${BACKUP_PATH}/backup-${DATETIME}.tgz}
export DATABASE_HOST=${DATABASE_HOST:-localhost}
export DATABASE_PORT=${DATABASE_PORT:-8088}
export DATABASE_META_DIR=${DATABASE_META_DIR:-/var/lib/influxdb/meta}
export DATABASE_DATA_DIR=${DATABASE_DATA_DIR:-/var/lib/influxdb/data}


# Add this script to the crontab and start crond
cron() {
  echo "Starting backup cron job with frequency '$1'"
  echo "$1 $0 backup" > /var/spool/cron/crontabs
  crond -f
}

# Dump the database to a file and push it to S3
backup() {
  # Dump database to directory
  echo "Backing up $DATABASE to $BACKUP_PATH"
  if [ -d $BACKUP_PATH ]; then
    rm -rf $BACKUP_PATH
  fi
  mkdir -p $BACKUP_PATH
  influxd backup -database $DATABASE -host $DATABASE_HOST:$DATABASE_PORT $BACKUP_PATH
  if [ $? -ne 0 ]; then
    echo "Failed to backup $DATABASE to $BACKUP_PATH"
    exit 1
  fi

  # Compress backup directory
  if [ -e $BACKUP_ARCHIVE_PATH ]; then
    rm -rf $BACKUP_ARCHIVE_PATH
  fi
  tar -cvzf $BACKUP_ARCHIVE_PATH $BACKUP_PATH

  # Copy Database to backup Directory
  #cp $BACKUP_ARCHIVE_PATH /var/lib/influxdb/__backup

  echo "Done"
}

# Pull down the latest backup from S3 and restore it to the database
restore() {
  # Remove old backup file
  if [ -d $BACKUP_PATH ]; then
    echo "Removing out of date backup"
    rm -rf $BACKUP_PATH
  fi
  if [ -e $BACKUP_ARCHIVE_PATH ]; then
    echo "Removing out of date backup"
    rm -rf $BACKUP_ARCHIVE_PATH
  fi
  # Get backup file Filesysteysm
  echo "Downloading latest backup from S3"
  if ls $BACKUP_ARCHIVE_PATH; then
    echo "File Exist"
  else
    echo "Failed to download latest backup"
    exit 1
  fi

  # Extract archive
  tar -xvzf $BACKUP_ARCHIVE_PATH -C /

  # Restore database from backup file
  echo "Running restore"
  if influxd restore -database $DATABASE -datadir $DATABASE_DATA_DIR -metadir $DATABASE_META_DIR $BACKUP_PATH ; then
    echo "Successfully restored"
  else
    echo "Restore failed"
    exit 1
  fi
  echo "Done"

}

# Handle command line arguments
case "$1" in
  "cron")
    cron "$2"
    ;;
  "backup")
    backup
    ;;
  "restore")
    restore
    ;;
  *)
    echo "Invalid command '$@'"
    echo "Usage: $0 {backup|restore|cron <pattern>}"
esac