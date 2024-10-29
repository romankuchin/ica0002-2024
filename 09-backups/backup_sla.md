# Backup SLA

## Coverage

We back up services that satisfy at least one of these criteria:
 - are primary source of truth for particular data
 - contain customer and/or client data
 - are not feasible (or very costly) to restore by other means

Services that are backed up:
 - _____
 - _____
 - _____


## Schedule

_____ backups are created every _____; it takes up to _____ to create and store the backup.

_____ backups are created every _____; it takes up to _____ to create and store the backup.

_____ backups are created every _____; it takes up to _____ to create and store the backup.

All backups are started automatically by _____.

Backup RPO (recovery point objective) is:
 - _____ for _____
 - _____ for _____
 - _____ for _____


## Storage

_____ and _____ backups are uploaded to the backup server.

_____ is mirrored to the internal Git server.

Backup data from both servers will be synchronized to encrypted AWS S3 bucket in future (work in progress).


## Retention

_____ backups are stored for _____; _____ versions (recovery points) are available to restore.

_____ backups are stored for _____; _____ versions are available to restore.

_____ backups are stored for _____; _____ versions are available to restore.


## Usability checks

_____ backups are verified every _____ by _____.

_____ backups are verified every _____ by _____.

_____ backups are verified every _____ by _____.


## Restore process

Service is recovered from the backup in case of an incident, and when service cannot be restored in any other way.

RTO (recovery time objective) is:
 - _____ for _____
 - _____ for _____
 - _____ for _____

Detailed backup restore procedure is documented in the [backup_restore.md](./backup_restore.md).
