FROM spacelis/ckan-docker-base
MAINTAINER CDRC
# --TAG: spacelis/ckan-docker-dev



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

#Install Cdrcmeta
RUN $CKAN_HOME/bin/gitpkg_install.sh spacelis/ckanext-cdrcmeta $CKAN_HOME/src
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/ckanext-cdrcmeta/

#Install Cdrc
RUN $CKAN_HOME/bin/gitpkg_install.sh spacelis/ckanext-cdrc $CKAN_HOME/src
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/ckanext-cdrc/

#Install dashboard
RUN $CKAN_HOME/bin/gitpkg_install.sh spacelis/ckanext-dashboard $CKAN_HOME/src
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/ckanext-dashboard/

#Install dashboard
RUN $CKAN_HOME/bin/gitpkg_install.sh spacelis/ckanext-viewhelpers $CKAN_HOME/src
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/ckanext-viewhelpers/

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
