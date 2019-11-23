FROM ubuntu:bionic
MAINTAINER Christoph Kappestein <christoph.kappestein@apioo.de>
LABEL version="1.0"

# env
ENV FUSIO_PROJECT_KEY="42eec18ffdbffc9fda6110dcc705d6ce" \
    FUSIO_HOST="acme.com" \
    FUSIO_ENV="prod" \
    FUSIO_DB_NAME="fusio" \
    FUSIO_DB_USER="fusio" \
    FUSIO_DB_PW="61ad6c605975" \
    FUSIO_DB_HOST="localhost" \
    FUSIO_BACKEND_USER="demo" \
    FUSIO_BACKEND_EMAIL="demo@fusio-project.org" \
    FUSIO_BACKEND_PW="75dafcb12c4f" \
    PROVIDER_FACEBOOK_KEY="" \
    PROVIDER_FACEBOOK_SECRET="" \
    PROVIDER_GOOGLE_KEY="" \
    PROVIDER_GOOGLE_SECRET="" \
    PROVIDER_GITHUB_KEY="" \
    PROVIDER_GITHUB_SECRET="" \
    RECAPTCHA_KEY="" \
    RECAPTCHA_SECRET="" \
    FUSIO_MEMCACHE_HOST="localhost" \
    FUSIO_MEMCACHE_PORT="11211" \
    FUSIO_VERSION="1.8.0" \
    COMPOSER_VERSION="1.5.2" \
    COMPOSER_SHA1="6dc307027b69892191dca036dcc64bb02dd74ab2"

# install default packages
RUN apt-get update -y 

RUN DEBIAN_FRONTEND=noninteractive apt-get -y install curl wget git unzip apache2 memcached libapache2-mod-php7.2 php7.2 mysql-client php7.2-dev

# install php7 extensions
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install php7.2-mysql php7.2-pgsql php7.2-sqlite3 php7.2-simplexml php7.2-dom php7.2-bcmath php7.2-curl php7.2-zip php7.2-mbstring php7.2-intl php7.2-xml php7.2-curl php7.2-gd php7.2-soap php-memcached php-mongodb

# install mysql drivers
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - 
RUN echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/18.04/prod bionic main" | tee /etc/apt/sources.list.d/mssql-release.list 
RUN apt-get update
RUN ACCEPT_EULA=Y apt-get -y install msodbcsql17 unixodbc-dev && \
    chmod 777 /etc/odbc.ini
RUN pecl install sqlsrv && \
    pecl install pdo_sqlsrv && \
    printf "; priority=20\nextension=sqlsrv.so\n" > /etc/php/7.2/mods-available/sqlsrv.ini && \
    printf "; priority=30\nextension=pdo_sqlsrv.so\n" > /etc/php/7.2/mods-available/pdo_sqlsrv.ini && \
    ACCEPT_EULA=Y apt-get install mssql-tools && \
    apt-get install unixodbc-dev && \
    #   cp /etc/php/7.2/mods-available/sqlsrv.ini /etc/php/7.2/cli/conf.d/10-sqlsrv.ini && \
    #   cp /etc/php/7.2/mods-available/pdo_sqlsrv.ini /etc/php/7.2/cli/conf.d/20-pdo_sqlsrv.ini
    #    sed -i "\$aextension=sqlsrv.so" /etc/php/7.2/mods-available/pdo.ini && \
    #    sed -i "\$aextension=pdo_sqlsrv.so" /etc/php/7.2/mods-available/pdo.ini && \
    #    cp  /etc/php/7.2/mods-available/pdo.ini /usr/share/php7.2-common/common/pdo.ini
    phpenmod sqlsrv pdo_sqlsrv && \
    chmod 766 /etc/passwd

# install composer
RUN wget -O /usr/bin/composer https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar && \
    echo "${COMPOSER_SHA1} */usr/bin/composer" | sha1sum -c - 
RUN chmod +x /usr/bin/composer




# install fusio
# RUN wget -O /var/www/html/fusio.zip "https://github.com/apioo/fusio/archive/${FUSIO_VERSION}.zip"

RUN wget -O /var/www/html/fusio.zip "https://github.com/apioo/fusio/releases/download/v${FUSIO_VERSION}/fusio_${FUSIO_VERSION}.zip" && \
    cd /var/www/html && unzip fusio.zip -d fusio && \
    #cd /var/www/html && mv fusio-${FUSIO_VERSION} fusio && \
    cd /var/www/html/fusio && /usr/bin/composer install

COPY ./fusio/resources /var/www/html/fusio/resources
COPY ./fusio/src /var/www/html/fusio/src
COPY ./fusio/.env /var/www/html/fusio/.env
COPY ./fusio/.fusio.yml /var/www/html/fusio/.fusio.yml
COPY ./fusio/configuration.php /var/www/html/fusio/configuration.php
COPY ./fusio/container.php /var/www/html/fusio/container.php
#RUN chown -R www-data: /var/www/html/fusio
RUN chown 777 /var/www/html/fusio && \
    chmod +x /var/www/html/fusio/bin/fusio

# remove install file
RUN rm /var/www/html/fusio/public/install.php && \
    rm /var/www/html/fusio/public/.htaccess

# apache config
COPY ./etc/apache2/apache2.conf /etc/apache2/apache2.conf
COPY ./etc/apache2/ports.conf /etc/apache2/ports.conf
COPY ./etc/apache2/conf-available/other-vhosts-access-log.conf /etc/apache2/conf-available/other-vhosts-access-log.conf
RUN touch /etc/apache2/sites-available/000-fusio.conf && \
    chmod a+rwx /etc/apache2/sites-available/000-fusio.conf && \
    mkdir -p /run/apache2/ && \
    chmod a+rwx /run/apache2/

# php config
COPY ./etc/php/99-custom.ini /etc/php/7.2/apache2/conf.d/99-custom.ini
COPY ./etc/php/99-custom.ini /etc/php/7.2/cli/conf.d/99-custom.ini


# install additional connectors
RUN cd /var/www/html/fusio && /usr/bin/composer require fusio/adapter-amqp && \
    cd /var/www/html/fusio && /usr/bin/composer require fusio/adapter-beanstalk && \
    cd /var/www/html/fusio && /usr/bin/composer require fusio/adapter-elasticsearch && \
    cd /var/www/html/fusio && /usr/bin/composer require fusio/adapter-memcache && \
    cd /var/www/html/fusio && /usr/bin/composer require fusio/adapter-mongodb && \
    cd /var/www/html/fusio && /usr/bin/composer require fusio/adapter-redis && \
    cd /var/www/html/fusio && /usr/bin/composer require fusio/adapter-smtp && \
    cd /var/www/html/fusio && /usr/bin/composer require fusio/adapter-soap

# apache config
RUN a2enmod rewrite && \
    a2dissite 000-default && \
    a2ensite 000-fusio

# install cron
RUN touch /etc/cron.d/fusio && \
    chmod a+rwx /etc/cron.d/fusio 

# mount volumes
VOLUME /var/www/html/fusio/cache
VOLUME /var/www/html/fusio/public

# start memcache
RUN service memcached start

# add entrypoint
COPY ./docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/docker-entrypoint.sh"]