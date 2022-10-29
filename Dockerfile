ARG DBT_VERSION=v1.2.1
FROM mwhitaker/dbt_all:${DBT_VERSION}

RUN pip install dbt-athena-adapter==1.0.1

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
