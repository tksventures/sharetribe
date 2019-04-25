#!/bin/bash

aws rds create-db-instance \
--allocated-storage 20 --db-instance-class db.t3.medium \
--db-instance-identifier test-instance --engine mysql \
--master-username master --master-user-password secret99 \
--availability-zone=us-west-2d
# --enable-cloudwatch-logs-exports '["audit","error","general","slowquery"]' \