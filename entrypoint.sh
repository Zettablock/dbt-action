#!/bin/bash

set -o pipefail


echo "dbt project folder set as: \"${INPUT_DBT_PROJECT_FOLDER}\""
cd ${INPUT_DBT_PROJECT_FOLDER}

if [ -n "${DBT_BIGQUERY_TOKEN}" ]
then
  echo trying to parse bigquery token
  $(echo ${DBT_BIGQUERY_TOKEN} | base64 -d > ./creds.json 2>/dev/null)
  if [ $? -eq 0 ]
  then
    echo success parsing base64 encoded token
  elif $(echo ${DBT_BIGQUERY_TOKEN} > ./creds.json)
  then
    echo success parsing plain token
  else
    echo cannot parse bigquery token
    exit 1
  fi
elif [ -n "${DBT_USER}" ] && [ -n "$DBT_PASSWORD" ]
then
 echo trying to use user/password
 sed -i "s/_user_/${DBT_USER}/g" ./profiles.yml
 sed -i "s/_password_/${DBT_PASSWORD}/g" ./profiles.yml
elif [ -n "${DBT_TOKEN}" ]
then
 echo trying to use DBT_TOKEN/databricks
 sed -i "s/_token_/${DBT_TOKEN}/g" ./datab.yml
else
  echo no tokens or credentials supplied
fi

DBT_ACTION_LOG_FILE=${DBT_ACTION_LOG_FILE:="dbt_console_output.txt"}
DBT_ACTION_LOG_PATH="${INPUT_DBT_PROJECT_FOLDER}/${DBT_ACTION_LOG_FILE}"
echo "DBT_ACTION_LOG_PATH=${DBT_ACTION_LOG_PATH}" >> $GITHUB_ENV
echo "saving console output in \"${DBT_ACTION_LOG_PATH}\""
# final_state=0
result=$(git diff --name-status origin/main origin/${PR_BRANCH}  |grep -v zettablock_data_mart|grep -v macros|grep -v trino|grep 'sql$'|grep -v '^D'|cut  -f2 |cut -d'/' -f2-)
if [[ $? != 0 ]]; then
    echo "Check delta files failed."
elif [[ $result ]]; then
    tasks=( $(git diff --name-status origin/main origin/${PR_BRANCH}  |grep -v zettablock_data_mart|grep -v macros|grep -v trino|grep 'sql$'|grep -v '^D'|cut  -f2 |cut -d'/' -f2-) )
    for item in "${tasks[@]}"
    do
        echo "commands: dbt run --target dev --profiles-dir ./dryrun_profile --project-dir ./zettablock --select $item --vars '{\"external_s3_location\":\"s3://my-897033522173-us-east-1-spark/demo/$(openssl rand -hex 8)\"}'"
        dbt run --target dev --profiles-dir ./dryrun_profile --project-dir ./zettablock --select $item --vars '{"external_s3_location":"s3://my-897033522173-us-east-1-spark/demo/$(openssl rand -hex 8)"}'
        if [ $? -ne 0 ]
            then
                echo "exception."
                exit 255
        fi
    done
else
    echo "No active change found."
fi

trino_result=$(git diff --name-status origin/main origin/${PR_BRANCH}  |grep -v zettablock_data_mart|grep -v macros|grep trino|grep 'sql$'|grep -v '^D'|cut  -f2 |cut -d'/' -f2-)
if [[ $? != 0 ]]; then
    echo "Check trino delta files failed."
elif [[ $trino_result ]]; then
    tasks=( $(git diff --name-status origin/main origin/${PR_BRANCH}  |grep -v zettablock_data_mart|grep -v macros|grep trino|grep 'sql$'|grep -v '^D'|cut  -f2 |cut -d'/' -f2-) )
    for item in "${tasks[@]}"
    do
        echo "commands: dbt run --target dev --profiles-dir ./trino_profile --project-dir ./zettablock --select $item --vars '{\"external_s3_location\":\"s3://my-897033522173-us-east-1-spark/demo/$(openssl rand -hex 8)\", , \"TRINO_USER\":$TRINO_HOST, \"TRINO_PASSWORD\":$TRINO_PASSWORD, \"TRINO_HOST\":$TRINO_HOST}'"
        dbt run --target dev --profiles-dir ./trino_profile --project-dir ./zettablock --select $item --vars '{"external_s3_location":"s3://my-897033522173-us-east-1-spark/demo/$(openssl rand -hex 8)", "TRINO_USER":$TRINO_HOST, "TRINO_PASSWORD":$TRINO_PASSWORD, "TRINO_HOST":$TRINO_HOST}' 
        if [ $? -ne 0 ]
            then
                echo "exception."
                exit 255
        fi
    done
else
    echo "No active change found."
fi
