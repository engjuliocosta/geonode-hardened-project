#!/bin/bash
if [[ -z $VIRTUAL_ENV ]]
then
    source ./venv/bin/activate 
fi

. $HOME/.override_env
python manage.py $@
