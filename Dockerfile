FROM spacelis/ckan-docker-base
# FROM phusion/baseimage:0.9.10
# MAINTAINER Open Knowledge
# --TAG: spacelis/ckan-docker-dev
#
# # Disable SSH
# RUN rm -rf /etc/service/sshd /etc/my_init.d/00_regen_ssh_host_keys.sh
#
# ENV HOME /root
# ENV CKAN_HOME /usr/lib/ckan/default
# ENV CKAN_CONFIG /etc/ckan/default
# ENV CKAN_DATA /var/lib/ckan
# ENV CKAN_ERROR_EMAIL_FROM ckan@example.org
# ENV CKAN_ERROR_EMAIL ckan@example.org
# ENV CKAN_ADMIN_USER ckan
# ENV CKAN_ADMIN_PASS ckan
#
# ENV CKAN_DATASTORE_READPASS datastore
# ENV CKAN_DATASTORE_WRITEPASS datastore
# ENV CKAN_DATASTORE_DB datastore
# ENV CKAN_DATASTORE_READER ds_reader
# ENV CKAN_DATASTORE_WRITER ds_writer
#
# # Install required packages
# RUN apt-get -q -y update
# RUN DEBIAN_FRONTEND=noninteractive apt-get -q -y install \
#         python-minimal \
#         python-dev \
#         python-virtualenv \
#         libevent-dev \
#         libpq-dev \
#         nginx-light \
#         apache2 \
#         libapache2-mod-wsgi \
#         libxml2-dev \
#         libxslt1-dev \
#         postfix \
#         postgresql-client \
#         expect \
#         expect-dev \
#         build-essential

# Prepare virtualenv
# RUN virtualenv $CKAN_HOME
# RUN mkdir -p $CKAN_HOME $CKAN_CONFIG $CKAN_DATA
# RUN chown www-data:www-data $CKAN_DATA

# Install CKAN
# ADD ./requirements.txt $CKAN_HOME/src/ckan/requirements.txt
# RUN $CKAN_HOME/bin/pip install -r $CKAN_HOME/src/ckan/requirements.txt
RUN git clone https://github.com/spacelis/ckan.git $CKAN_HOME/src/ckan/
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/ckan/
RUN ln -s $CKAN_HOME/src/ckan/ckan/config/who.ini $CKAN_CONFIG/who.ini
ADD ./apache.wsgi $CKAN_CONFIG/apache.wsgi
ADD ./addsysadmin.exp $CKAN_CONFIG/addsysadmin.exp

# Install CKAN service provider
RUN git clone https://github.com/spacelis/ckan-service-provider.git $CKAN_HOME/src/ckan-service-provider
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/ckan-service-provider

# Install datapusher
RUN git clone https://github.com/spacelis/ckan-datapusher-service.git $CKAN_HOME/src/datapusher
# RUN $CKAN_HOME/bin/pip install -r $CKAN_HOME/src/datapusher/requirements.txt
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/datapusher/
RUN cp $CKAN_HOME/src/datapusher/deployment/datapusher.wsgi $CKAN_CONFIG/datapusher.wsgi
RUN cp $CKAN_HOME/src/datapusher/deployment/datapusher_settings.py $CKAN_CONFIG/datapusher_settings.py

#Install Cdrcmeta
RUN git clone https://github.com/spacelis/ckanext-cdrcmeta.git $CKAN_HOME/src/ckanext-cdrcmeta
# RUN $CKAN_HOME/bin/pip install -r $CKAN_HOME/src/datapusher/requirements.txt
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/ckanext-cdrcmeta/

# Configure apache
ADD ./apache.conf /etc/apache2/sites-available/ckan.conf
RUN cp $CKAN_HOME/src/datapusher/deployment/datapusher.conf /etc/apache2/sites-available/datapusher.conf
RUN echo "Listen 8080" > /etc/apache2/ports.conf
RUN echo "Listen 8800" >> /etc/apache2/ports.conf
RUN echo "StartServers 1" >> /etc/apache2/apache2.conf
RUN echo "ServerLimit 1" >> /etc/apache2/apache2.conf
RUN a2ensite ckan
RUN a2ensite datapusher
RUN a2dissite 000-default

# Configure nginx
ADD ./nginx.conf /etc/nginx/nginx.conf
RUN mkdir /var/cache/nginx

# Configure postfix
ADD ./main.cf /etc/postfix/main.cf

# Configure runit
ADD ./my_init.d /etc/my_init.d
ADD ./svc /etc/service
CMD ["/sbin/my_init"]

VOLUME ["/var/lib/ckan"]
VOLUME ["/var/log"]
EXPOSE 80

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
