FROM python:3.8-bullseye

ENV http_proxy=http://proxy-iaa.ar.sa.vwg:8080
ENV https_proxy=http://proxy-iaa.ar.sa.vwg:8080
ENV no_proxy=192.168.0.0/16,127.0.0.1,localhost,10.0.0.0/8,*.vwg

###########################################
# Upgrade the packages
###########################################
# Download latest listing of available packages:
RUN apt-get -y update
# Upgrade already installed packages:
RUN apt-get -y upgrade
# Install a new package:

###########################################
# install tree package
###########################################
# Install a new package:
RUN apt-get -y install tree joe curl wget


#############################################
# install pipenv
############################################
ENV PIPENV_VENV_IN_PROJECT=1

# ENV PIPENV_VENV_IN_PROJECT=1 is important: it causes the resulting virtual environment to be created as /app/.venv. Without this the environment gets created somewhere surprising, such as /root/.local/share/virtualenvs/app-4PlAip0Q - which makes it much harder to write automation scripts later on.

RUN python -m pip install --upgrade pip

RUN pip install --no-cache-dir pipenv

RUN pip install --no-cache-dir jupyter

RUN pip install --no-cache-dir py4j

RUN pip install --no-cache-dir findspark

RUN pip install --no-cache-dir pyspark


#############################################
# install java and spark and hadoop
# Java is required for scala and scala is required for Spark
############################################


# VERSIONS
ENV SPARK_VERSION=3.5.0 \
HADOOP_VERSION=3.3 \
JAVA_VERSION=11

RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    "openjdk-${JAVA_VERSION}-jre-headless" \
    ca-certificates-java  \
    curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# What is --jre-headless?
# Minimal Java runtime - needed for executing non GUI Java programs


RUN java --version


COPY spark-3.5.0-bin-hadoop3.tgz /apache-spark.tgz

# DOWNLOAD SPARK AND INSTALL
RUN mkdir -p /home/spark \
    && tar -xf apache-spark.tgz -C /home/spark --strip-components=1 \
    && rm apache-spark.tgz


# SET SPARK ENV VARIABLES
ENV SPARK_HOME="/home/spark"
ENV PATH="${SPARK_HOME}/bin/:${PATH}"
ENV PYSPARK_PYTHON=/usr/bin/python3
ENV PYSPARK_DRIVER_PYTHON='jupyter'
ENV PYSPARK_DRIVER_PYTHON_OPTS='notebook --no-browser --port=4041'


# Fix Spark installation for Java 11 and Apache Arrow library
# see: https://github.com/apache/spark/pull/27356, https://spark.apache.org/docs/latest/#downloading
RUN cp -p "${SPARK_HOME}/conf/spark-defaults.conf.template" "${SPARK_HOME}/conf/spark-defaults.conf" && \
    echo 'spark.driver.extraJavaOptions -Dio.netty.tryReflectionSetAccessible=true' >> "${SPARK_HOME}/conf/spark-defaults.conf" && \
    echo 'spark.executor.extraJavaOptions -Dio.netty.tryReflectionSetAccessible=true' >> "${SPARK_HOME}/conf/spark-defaults.conf"

############################################
# create group and user
############################################

ARG UNAME=sam
ARG UID=1000
ARG GID=1000


RUN cat /etc/passwd

# create group
RUN groupadd -g $GID $UNAME

# create a user with userid 1000 and gid 1000
RUN useradd -u $UID -g $GID -m -s /bin/bash $UNAME
# -m creates home directory

# change permissions of /home/sam to 1000:100
RUN chown $UID:$GID /home/sam
RUN mkdir /home/sam/app
RUN chown $UID:$GID /home/sam/app
RUN mkdir /home/sam/app/spark_events
RUN chown $UID:$GID /home/sam/app/spark_events

RUN mkdir /opt/spark 
RUN mkdir /opt/spark/work 
RUN chown $UID:$GID /opt/spark/work

###########################################
# add sudo
###########################################

RUN apt-get update --yes
RUN apt-get -y install sudo
RUN apt-get -y install vim
RUN cat /etc/sudoers
RUN echo "$UNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
RUN cat /etc/sudoers

#############################
# spark history server
############################

# ALLOW spark history server (mount sparks_events folder locally to /home/sam/app/spark_events)

RUN echo 'spark.eventLog.enabled true' >> "${SPARK_HOME}/conf/spark-defaults.conf" && \
    echo 'spark.eventLog.dir file:///home/sam/app/spark_events' >> "${SPARK_HOME}/conf/spark-defaults.conf" && \
    echo 'spark.history.fs.logDirectory file:///home/sam/app/spark_events' >> "${SPARK_HOME}/conf/spark-defaults.conf"

RUN mkdir /home/spark/logs
RUN chown $UID:$GID /home/spark/logs

###########################################
# change working dir and user
###########################################

USER $UNAME

RUN mkdir -p /home/$UNAME/app
WORKDIR /home/$UNAME/app


#CMD ["sh", "-c", "tail -f /dev/null"]
#CMD ["jupyter", "notebook", "--ip=0.0.0.0", "--port=4041", "--no-browser", "--allow-root", "--NotebookApp.token=''" ,"--NotebookApp.password=''" ]
# Start Spark History Server in the background
CMD ["sh", "-c", "$SPARK_HOME/sbin/start-history-server.sh && jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password=''"]