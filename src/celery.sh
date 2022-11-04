#!/bin/bash

if [[ -z $VIRTUAL_ENV ]]
then
    source ${GEONODE_HOME}/venv/bin/activate 
fi

# TODO: check default celery.log
nohup celery -A geonode.celery_app:app beat -l DEBUG -f ${GEONODE_LOG}/celery.log &>/dev/null &
nohup celery -A geonode.celery_app:app worker --without-gossip --without-mingle -Ofair -B -E -s django_celery_beat.schedulers:DatabaseScheduler --loglevel=INFO --concurrency=2 -n worker1@%h -f ${GEONODE_LOG}/celery.log &>/dev/null &
nohup celery -A geonode.celery_app:app flower --auto_refresh=True --debug=False --broker=${BROKER_URL} --basic_auth=${ADMIN_USERNAME}:${ADMIN_PASSWORD} --address=0.0.0.0 --port=5555 &>/dev/null &