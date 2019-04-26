#!/bin/bash

# 0. check env vars
export $(grep -v '^#' .env | xargs)

env_vars_array=(
  DB_NAME
  DB_PASS
  DB_USER
)

for e in "${env_vars_array[@]}"
do
  [[ -z $(echo ${!e}) ]] && echo "$e is empty, exiting" && exit 1 || echo "$e is set"
done

echo "all env vars set"

# 1. set up database if env is undefined

# 1.1 create db instance on AWS
# ./aws-create-db.sh # returns DB endpoint

# 1.2 create the appropriate database
# Q1="CREATE DATABASE IF NOT EXISTS $DB_NAME;"
# Q2="GRANT ALL ON *.* TO '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
# Q3="FLUSH PRIVILEGES;"
# SQL="${Q1}${Q2}${Q3}"
# mysql -u $DB_USER -p$DB_PASS -h $DB_ENDPOINT -e "$SQL"

# 1.3 add structure and schema
# docker run $DOCKER_IMAGE bundle exec rake db:structure:load jobs:work

# 2. execute app
# docker-compose up --build
# OR
# kubectl create -f ../kubernetes-compose.yml
