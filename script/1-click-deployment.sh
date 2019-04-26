#!/bin/bash

# 0. check env vars
export $(grep -v '^#' .env | xargs)

env_vars_array=(
  DB_NAME
  DB_PASS
  DB_USER
  SECRET_KEY
  SECRET_KEY_BASE
  S3_BUCKET_NAME
  S3_UPLOAD_BUCKET_NAME
  S3_REGION
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
  DOCKER_IMAGE
)

for e in "${env_vars_array[@]}"
do
  [[ -z $(echo ${!e}) ]] && echo "$e is empty" && missing_env_vars=1 || echo "$e is set"
done

if [[ "$missing_env_vars" == 1 ]]; then
  echo "critical vars not set, exiting"
  exit 1
else
  echo "all env vars set"
fi

# 1. set up database if endpoint env is undefined
if [[ -z "${DB_ENDPOINT}" ]]; then
  echo DB_ENDPOINT variable not found
  echo creating new database
  # 1.1. create db instance on AWS
  # ./aws-create-db.sh # returns DB endpoint
else
  echo "using existing $DB_ENDPOINT"
fi

# 2. check if database exists and react
RESULT=`mysqlshow -u $DB_USER -p$DB_PASS -h $DB_ENDPOINT $DB_NAME| grep -v Wildcard | grep -o $DB_NAME`
if [[ "$RESULT" != "$DB_NAME" ]]; then
  # 2.1. create the appropriate database
  echo "create database"
  Q1="CREATE DATABASE IF NOT EXISTS $DB_NAME;"
  Q2="GRANT ALL ON $DB_NAME.* TO '$DB_USER'@'$DB_ENDPOINT' IDENTIFIED BY '$DB_PASS';"
  Q3="FLUSH PRIVILEGES;"
  SQL="${Q1}${Q2}${Q3}"
  mysql -u $DB_USER -p$DB_PASS -h $DB_ENDPOINT -e "$SQL"
  echo "result of creating database, 0 is OK: $?"

  # 2.2. add structure and schema
  echo "applying database structure"
  docker run --env-file=./.env --env-file=./.env-worker $DOCKER_IMAGE bundle exec rake db:structure:load
  echo "result of applying database structure, 0 is OK: $?"
else
  echo "using existing database $DB_NAME"
fi


# 2. execute app
docker-compose up
# OR
# kubectl create -f ../kubernetes-compose.yml
