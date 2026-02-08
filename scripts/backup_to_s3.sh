#!/bin/bash
# Upload backups to S3 with lifecycle management

aws s3 sync /backups/ s3://$AWS_S3_BUCKET/backups/ \
  --storage-class STANDARD_IA \
  --exclude "*" \
  --include "eaglespy_db_*.sql.gz"

# S3 Lifecycle Policy (apply via AWS Console or CLI):
# - Transition to Glacier after 90 days
# - Delete after 365 days
