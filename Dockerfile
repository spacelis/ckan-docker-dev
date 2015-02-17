FROM spacelis/ckan-docker-base
MAINTAINER CDRC
# --TAG: spacelis/ckan-docker-dev



# Install CKAN
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
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/datapusher/
RUN cp $CKAN_HOME/src/datapusher/deployment/datapusher.wsgi $CKAN_CONFIG/datapusher.wsgi
RUN cp $CKAN_HOME/src/datapusher/deployment/datapusher_settings.py $CKAN_CONFIG/datapusher_settings.py

#Install Cdrcmeta
RUN git clone https://github.com/spacelis/ckanext-cdrcmeta.git $CKAN_HOME/src/ckanext-cdrcmeta
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
