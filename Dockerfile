FROM php:7.4-apache-buster

RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y git

RUN git clone https://github.com/pixelfed/pixelfed.git /pixelfed 

# Use the default production configuration
RUN cp /pixelfed/contrib/docker/php.production.ini "$PHP_INI_DIR/php.ini"

# Install Composer
ENV COMPOSER_VERSION=1.10.11 \
    COMPOSER_HOME=/var/www/.composer \
    COMPOSER_MEMORY_LIMIT=-1 \
    PATH="~/.composer/vendor/bin:./vendor/bin:${PATH}"
ARG DEBIAN_FRONTEND=noninteractive
WORKDIR /var/www/
RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
  && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
  && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
  && php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION} && rm -rf /tmp/composer-setup.php \
  && apt-get update \
  && apt-get upgrade -y \
#  && apt-get install -y --no-install-recommends apt-utils \
  && apt-get install -y --no-install-recommends \
## Standard
      locales \
      locales-all \
      git \
      gosu \
      zip \
      unzip \ 
      libzip-dev \ 
      libcurl4-openssl-dev \
## Image Optimization
      optipng \
      pngquant \
      jpegoptim \
      gifsicle \
## Image Processing
      libjpeg62-turbo-dev \
      libpng-dev \
      libmagickwand-dev \
# Required for GD
      libxpm4 \
      libxpm-dev \
      libwebp6 \
      libwebp-dev \
## Video Processing
      ffmpeg \
## Database
#      libpq-dev \
#      libsqlite3-dev \
      mariadb-client \
# Locales Update
  && sed -i '/en_US/s/^#//g' /etc/locale.gen \
  && locale-gen \
  && update-locale \
# Install PHP extensions
  && docker-php-source extract \
#PHP Imagemagick extensions
  && pecl install imagick \
  && docker-php-ext-enable imagick \
# PHP GD extensions
  && docker-php-ext-configure gd \
      --with-freetype \
      --with-jpeg \
      --with-webp \
      --with-xpm \
  && docker-php-ext-install -j$(nproc) gd \
#PHP Redis extensions
  && pecl install redis \
  && docker-php-ext-enable redis \
#PHP Database extensions
  && docker-php-ext-install pdo_mysql \
#pdo_pgsql pdo_sqlite \
#PHP extensions (dependencies)
  && docker-php-ext-configure intl \
  && docker-php-ext-install -j$(nproc) intl bcmath zip pcntl exif curl \
#APACHE Bootstrap
  && a2enmod rewrite remoteip \
 && {\
     echo RemoteIPHeader X-Real-IP ;\
     echo RemoteIPTrustedProxy 10.0.0.0/8 ;\
     echo RemoteIPTrustedProxy 172.16.0.0/12 ;\
     echo RemoteIPTrustedProxy 192.168.0.0/16 ;\
     echo SetEnvIf X-Forwarded-Proto "https" HTTPS=on ;\
    } > /etc/apache2/conf-available/remoteip.conf \
 && a2enconf remoteip \
#Cleanup
  && docker-php-source delete \
  && apt-get autoremove --purge -y \
  && apt-get clean \
  && rm -rf /var/cache/apt \
  && rm -rf /var/lib/apt/lists/

RUN cp -arv /pixelfed/* /var/www/

RUN composer self-update --1
# for detail why storage is copied this way, pls refer to https://github.com/pixelfed/pixelfed/pull/2137#discussion_r434468862
RUN cp -r storage storage.skel \
  && composer global require hirak/prestissimo --prefer-dist --no-interaction --no-ansi --no-suggest \
  && composer install --prefer-dist --no-interaction --no-ansi --optimize-autoloader \
  && composer update --prefer-dist --no-interaction --no-ansi \
  && composer global remove hirak/prestissimo --no-interaction --no-ansi \
  && rm -rf html && ln -s public html
VOLUME /var/www/storage /var/www/bootstrap

CMD ["/var/www/contrib/docker/start.apache.sh"]
