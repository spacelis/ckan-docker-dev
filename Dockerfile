FROM spacelis/ckan-docker-base
MAINTAINER CDRC
# --TAG: spacelis/ckan-docker-dev

ENV CKAN_HOME /usr/lib/ckan/default
ENV CKAN_CONFIG /etc/ckan/default
ENV CKAN_DATA /var/lib/ckan
ENV CKAN_ERROR_EMAIL_FROM ckan@example.org
ENV CKAN_ERROR_EMAIL ckan@example.org
ENV CKAN_ADMIN_USER ckan
ENV CKAN_ADMIN_PASS ckan

ENV CKAN_DATASTORE_READPASS datastore
ENV CKAN_DATASTORE_WRITEPASS datastore
ENV CKAN_DATASTORE_DB datastore
ENV CKAN_DATASTORE_READER ds_reader
ENV CKAN_DATASTORE_WRITER ds_writer

ENV CKAN_DATAPUSHER_DB datapusher
ENV CKAN_DATAPUSHER_PASS datapusher
ENV CKAN_DATAPUSHER datapusher

# Prepare virtualenv
RUN virtualenv $CKAN_HOME
RUN mkdir -p $CKAN_HOME $CKAN_CONFIG $CKAN_DATA
RUN chown www-data:www-data $CKAN_DATA

ADD ./gitpkg_install.sh $CKAN_HOME/bin/gitpkg_install.sh
RUN mkdir -p $CKAN_HOME/src
# Install CKAN
RUN $CKAN_HOME/bin/gitpkg_install.sh spacelis/ckan $CKAN_HOME/src
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/ckan/
RUN ln -s $CKAN_HOME/src/ckan/ckan/config/who.ini $CKAN_CONFIG/who.ini
ADD ./apache.wsgi $CKAN_CONFIG/apache.wsgi
ADD ./addsysadmin.exp $CKAN_CONFIG/addsysadmin.exp

# Install CKAN service provider
RUN $CKAN_HOME/bin/gitpkg_install.sh spacelis/ckan-service-provider $CKAN_HOME/src
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/ckan-service-provider

# Install datapusher
RUN $CKAN_HOME/bin/gitpkg_install.sh spacelis/ckan-datapusher-service $CKAN_HOME/src
RUN cp $CKAN_HOME/src/ckan-datapusher-service/deployment/datapusher.wsgi $CKAN_CONFIG/datapusher.wsgi
RUN cp $CKAN_HOME/src/ckan-datapusher-service/deployment/datapusher_settings.py $CKAN_CONFIG/datapusher_settings.py

#Install Cdrc
RUN $CKAN_HOME/bin/gitpkg_install.sh spacelis/ckan-ckanext-cdrc $CKAN_HOME/src
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/ckan-ckanext-cdrc/

#Install dashboard
RUN $CKAN_HOME/bin/gitpkg_install.sh spacelis/ckan-ckanext-dashboard $CKAN_HOME/src
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/ckan-ckanext-dashboard/

#Install dashboard
RUN $CKAN_HOME/bin/gitpkg_install.sh spacelis/ckan-ckanext-viewhelpers $CKAN_HOME/src
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/ckan-ckanext-viewhelpers/

#Install dashboard
RUN $CKAN_HOME/bin/gitpkg_install.sh spacelis/ckan-ckanext-scheming $CKAN_HOME/src
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/ckan-ckanext-scheming/

# Configure apache
ADD ./apache.conf /etc/apache2/sites-available/ckan.conf
RUN cp $CKAN_HOME/src/ckan-datapusher-service/deployment/datapusher.conf /etc/apache2/sites-available/ckan-datapusher-service.conf
RUN echo "Listen 8080" > /etc/apache2/ports.conf
RUN echo "Listen 8800" >> /etc/apache2/ports.conf
RUN echo "StartServers 1" >> /etc/apache2/apache2.conf
RUN echo "ServerLimit 1" >> /etc/apache2/apache2.conf
RUN a2ensite ckan
RUN a2ensite ckan-datapusher-service
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
