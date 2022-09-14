ARG GEOSERVER_VERSION=2.19.6
ARG GEOSERVER_DATA_DIR="/geoserver_data/data"

FROM debian:bullseye AS BUILDER

ARG GEOSERVER_VERSION
ARG GEOSERVER_DATA_DIR

#
# Add missing wget & unzip
#
RUN apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        unzip \
        wget \
    && rm -rf /var/lib/apt/lists/*

# GeoServer will be in /tmp/geoserver
WORKDIR /tmp

#
# Download and install GeoServer
#
RUN wget --no-check-certificate --progress=bar:force:noscroll https://artifacts.geonode.org/geoserver/${GEOSERVER_VERSION}/geoserver.war -O geoserver.war \
    && unzip -q geoserver.war -d geoserver \
    && rm geoserver.war

# added by simonelanucara https://github.com/simonelanucara
# Optionally add JAI, ImageIO and Marlin Render for improved Geoserver performance
RUN wget --no-check-certificate https://repo1.maven.org/maven2/org/postgis/postgis-jdbc/1.3.3/postgis-jdbc-1.3.3.jar \
        -O geoserver/WEB-INF/lib/postgis-jdbc-1.3.3.jar && \
    wget --no-check-certificate https://maven.geo-solutions.it/org/hibernatespatial/hibernate-spatial-postgis/1.1.3.2/hibernate-spatial-postgis-1.1.3.2.jar \
        -O geoserver/WEB-INF/lib/hibernate-spatial-postgis-1.1.3.2.jar && \
    rm geoserver/WEB-INF/lib/hibernate-spatial-h2-geodb-1.1.3.2.jar 


# Force a static tag (dockerfile best practice)
FROM tomcat:9-jre8-openjdk-slim-bullseye
LABEL GeoNode Development Team

#
# Set GeoServer version and data directory
#
ARG GEOSERVER_VERSION
ARG GEOSERVER_DATA_DIR
ENV GEOSERVER_VERSION=${GEOSERVER_VERSION}
ENV GEOSERVER_DATA_DIR=${GEOSERVER_DATA_DIR}

#
# Copy GeoServer from BUILDER stage
#
RUN mkdir -p $GEOSERVER_DATA_DIR

VOLUME $GEOSERVER_DATA_DIR

COPY --from=BUILDER /tmp/geoserver /usr/local/tomcat/webapps/geoserver

###########docker host###############
# Set DOCKERHOST variable if DOCKER_HOST exists
ARG DOCKERHOST=${DOCKERHOST}
# for debugging
RUN echo -n #1===>DOCKERHOST=${DOCKERHOST}
#
ENV DOCKERHOST ${DOCKERHOST}
# for debugging
RUN echo -n #2===>DOCKERHOST=${DOCKERHOST}

###########docker host ip#############
# Set GEONODE_HOST_IP address if it exists
ARG GEONODE_HOST_IP=${GEONODE_HOST_IP}
# for debugging
RUN echo -n #1===>GEONODE_HOST_IP=${GEONODE_HOST_IP}
#
ENV GEONODE_HOST_IP ${GEONODE_HOST_IP}
# for debugging
RUN echo -n #2===>GEONODE_HOST_IP=${GEONODE_HOST_IP}
# If empty set DOCKER_HOST_IP to GEONODE_HOST_IP
ENV DOCKER_HOST_IP=${DOCKER_HOST_IP:-${GEONODE_HOST_IP}}
# for debugging
RUN echo -n #1===>DOCKER_HOST_IP=${DOCKER_HOST_IP}
# Trying to set the value of DOCKER_HOST_IP from DOCKER_HOST
RUN if ! [ -z ${DOCKER_HOST_IP} ]; \
    then echo export DOCKER_HOST_IP=${DOCKERHOST} | \
    sed 's/tcp:\/\/\([^:]*\).*/\1/' >> /root/.bashrc; \
    else echo "DOCKER_HOST_IP is already set!"; fi
# for debugging
RUN echo -n #2===>DOCKER_HOST_IP=${DOCKER_HOST_IP}

# Set WEBSERVER public port
ARG PUBLIC_PORT=${PUBLIC_PORT}
# for debugging
RUN echo -n #1===>PUBLIC_PORT=${PUBLIC_PORT}
#
ENV PUBLIC_PORT=${PUBLIC_PORT}
# for debugging
RUN echo -n #2===>PUBLIC_PORT=${PUBLIC_PORT}

# set nginx base url for geoserver
RUN echo export NGINX_BASE_URL=http://${NGINX_HOST}:${NGINX_PORT}/ | \
    sed 's/tcp:\/\/\([^:]*\).*/\1/' >> /root/.bashrc

# copy the script and perform the run of scripts from entrypoint.sh
RUN mkdir -p /usr/local/tomcat/tmp
WORKDIR /usr/local/tomcat/tmp
COPY set_geoserver_auth.sh .
COPY setup_auth.sh .
COPY requirements.txt .
COPY get_dockerhost_ip.py .
COPY get_nginxhost_ip.py .
COPY entrypoint.sh .
COPY ./templates /templates
COPY multidump.sh .
COPY multidump-alt.sh .

RUN apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        curl \
        less \
        procps \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        python3 \
        python3-pip \
        python3-dev \
    && pip3 install pip==9.0.3 \
    && pip3 install -r requirements.txt \
    && pip3 install j2cli \
    && chmod +x \
        set_geoserver_auth.sh \
        setup_auth.sh \
        get_dockerhost_ip.py \
        entrypoint.sh \
        get_nginxhost_ip.py \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_OPTS="-Djava.awt.headless=true -XX:+UnlockDiagnosticVMOptions -XX:+LogVMOutput -XX:LogFile=/var/log/jvm.log -XX:MaxPermSize=512m -XX:PermSize=256m -Xms512m -Xmx2048m -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:ParallelGCThreads=4 -Dfile.encoding=UTF8 -Djavax.servlet.request.encoding=UTF-8 -Djavax.servlet.response.encoding=UTF-8 -Duser.timezone=GMT -Dorg.geotools.shapefile.datetime=false -DGEOSERVER_CSRF_DISABLED=true -DPRINT_BASE_URL=http://geoserver:8080/geoserver/pdf -Xbootclasspath/a:/usr/local/tomcat/webapps/geoserver/WEB-INF/lib/marlin-0.9.3.jar -Dsun.java2d.renderer=org.marlin.pisces.MarlinRenderingEngine"

CMD ["./entrypoint.sh"]
