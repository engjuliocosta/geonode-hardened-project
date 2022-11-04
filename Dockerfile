ARG DEBIAN_VERSION=bullseye
ARG PYTHON_VERSION=3.8

ARG GEONODE_HOME=/var/lib/geonode
ARG GEONODE_UID=830
ARG GEONODE_GID=${GEONODE_UID}

# Multi-Stage build with Virtualenv
FROM python:${PYTHON_VERSION}-${DEBIAN_VERSION} AS BUILDER

ARG GEONODE_HOME

WORKDIR ${GEONODE_HOME}

# Install apt dependencies
RUN apt-get -y update && \
    apt-get install -y \
        # builders
        devscripts \
        build-essential \
        debhelper \
        pkg-kde-tools \
        sharutils \
        # devels
        libgdal-dev \
        libpq-dev \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev \
        libjpeg-dev \
        libmemcached-dev \
        libffi-dev \
        # geonode-ldap 
        libldap2-dev \
        libsasl2-dev && \
    apt-get -y autoremove && \
    rm -rf /var/lib/apt/lists/*

# copy only requirements
COPY src/requirements.txt .

# configure virtualenv
RUN python -m venv --symlinks venv && \
    . venv/bin/activate && \
    echo "Using Python: $(which python)" && sleep 10 && \
    # upgrade basics
    python -m pip install --upgrade --no-cache \
        wheel && \
    # extra deps
    python -m pip install --no-cache \
        pygdal==$(gdal-config --version).* \
        flower==0.9.4 && \
    python -m pip install --no-cache \
        pylibmc \
        sherlock && \
    # geonode base (requirements.txt)
    python -m pip install --upgrade --no-cache -r requirements.txt && \
    # geonode contribs (installed after geonode, because geonode-ldap was installing the latest geonode version, then downgrade to requirements' version)
    python -m pip install --no-cache \
        "git+https://github.com/GeoNode/geonode-contribs.git#egg=geonode-logstash&subdirectory=geonode-logstash" && \
    python -m pip install --no-cache \
        "git+https://github.com/GeoNode/geonode-contribs.git#egg=geonode-ldap&subdirectory=ldap" && \
    deactivate

ARG DEBIAN_VERSION
ARG PYTHON_VERSION

# Release version
FROM python:${PYTHON_VERSION}-slim-${DEBIAN_VERSION} AS RELEASE

ARG GEONODE_HOME
ARG GEONODE_UID
ARG GEONODE_GID

LABEL maintainer="NDS CPRM"

ENV GEONODE_HOME=${GEONODE_HOME} \
    GEONODE_LOG=/var/log/geonode

RUN apt-get -y update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        # libs
        libgdal28 \
        libmemcached11 \
        libsqlite3-mod-spatialite \
        libxml2 \
        libxslt1.1 \
        # utils - cowsay for fun ;)
        cowsay \
        cron \
        curl \
        # firefox-esr && \
        geoip-bin \
        gettext \
        git \
        # gosu \
        memcached \
        postgresql-client-13  \
        spatialite-bin \
        sqlite3 \
        zip \
        # geonode-ldap
        libldap-2.4-2 \
        libsasl2-2 && \
    ln -s /usr/games/cowsay /usr/bin/cowsay && \
    apt-get -y autoremove && \
    rm -rf /var/lib/apt/lists/*

# Create a geonode user and put shell to load the geonode virtualenv
RUN groupadd -g ${GEONODE_UID} geonode && \
    useradd -g ${GEONODE_GID} -u ${GEONODE_UID} -m -d ${GEONODE_HOME} \
        -s /usr/sbin/nologin geonode && \
    # geonode dirs (logs, statics)
    mkdir -p /mnt/volumes/statics ${GEONODE_LOG} && \
    ln -s /mnt/volumes/statics ${GEONODE_HOME}/statics && \
    ln -s ${GEONODE_LOG} ${GEONODE_HOME}/logs && \    
    # add geonode virtualenv to root and geonode user
    printf "\n# GeoNode VirtualEnv\nalias activate='source %s/venv/bin/activate'\n" ${GEONODE_HOME} | tee -a ~/.bashrc >> ${GEONODE_HOME}/.bashrc && \ 
    echo "printf \"Welcome to GeoNode! Type \'activate\' on shell to initialize the VirtualEnv\" | cowsay -f tux" | tee -a ~/.bashrc >> ${GEONODE_HOME}/.bashrc && \
    # grant content to user geonode
    chown -R geonode:geonode ${GEONODE_HOME}/statics ${GEONODE_HOME}/.bashrc ${GEONODE_LOG} ${GEONODE_HOME}/logs

# Copy virtualenv made in BUILDER
COPY --from=BUILDER ${GEONODE_HOME}/venv ${GEONODE_HOME}/venv

# Copy geonode_project source code
COPY src ${GEONODE_HOME}/app/

WORKDIR ${GEONODE_HOME}/app

# Install GeoNode Project on RELEASE
RUN . ${GEONODE_HOME}/venv/bin/activate && \
    python -m pip install --upgrade --no-cache -e . && \
    deactivate

# Configure GeoNode project
RUN chmod +x celery.sh celery-cmd uwsgi-cmd && \
    ln -s $(pwd)/celery.sh /usr/bin/celery-commands && \
    ln -s $(pwd)/celery-cmd /usr/bin/celery-cmd && \
    ln -s $(pwd)/uwsgi-cmd /usr/bin/uwsgi-cmd && \
    # configure other scripts
    chmod +x wait-for-databases.sh tasks.py entrypoint.sh && \
    ln -s $(pwd)/wait-for-databases.sh /usr/bin/wait-for-databases && \
    ln -s $(pwd)/entrypoint.sh /entrypoint.sh && \
    # cron jobs
    mv monitoring-cron /etc/cron.d/monitoring-cron && \
    chmod 0644 /etc/cron.d/monitoring-cron && \
    crontab /etc/cron.d/monitoring-cron && \
    touch /var/log/cron.log

# Export ports
EXPOSE 8000

# We provide no command or entrypoint as this image can be used to serve the django project or run celery tasks
# ENTRYPOINT [ "/entrypoint.sh" ]
