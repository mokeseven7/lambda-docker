#Lambda base image Amazon linux
FROM public.ecr.aws/lambda/provided as builder 

# Set desired PHP Version
ARG PHP_VERSION="8.2.2"
ARG PHP_PREFIX="/opt/php8/"
ARG PHP_BINDIR="/opt/php8/bin/"
ARG PHP_BINPATH="/opt/php8/bin/php"


RUN yum clean all && \
    yum install -y autoconf \
                bison \
                bzip2-devel \
                gcc \
                gcc-c++ \
                git \
                gzip \
                libcurl-devel \
                libxml2-devel \
                make \
                openssl-devel \
                tar \
                unzip \
                zip \
                re2c \
                sqlite-devel \
                oniguruma-devel 

# Download the PHP source, compile, and install both PHP and Composer
RUN curl -sL https://github.com/php/php-src/archive/php-${PHP_VERSION}.tar.gz | tar -xvz && \
    cd php-src-php-${PHP_VERSION} && \
    ./buildconf --force && \
    ./configure --prefix=/opt/php8/ \
        --with-openssl \ 
        --with-curl \
        --with-zlib \
        --without-pear \
        --enable-bcmath \
        --with-bz2 \
        --enable-mbstring \
        --with-mysqli && \
        make -j 5 && \
        make install && \
        $PHP_BINDIR -v && \
        curl -sS https://getcomposer.org/installer | $PHP_BINPATH -- --install-dir=$PHP_BINDIR --filename=composer

# Prepare runtime files
RUN mkdir -p /lambda-php-runtime/bin && \
    cp $PHP_BINDIR /lambda-php-runtime/bin/php

COPY runtime/bootstrap /lambda-php-runtime/
RUN chmod 0755 /lambda-php-runtime/bootstrap

# Install Guzzle, prepare vendor files
RUN mkdir /lambda-php-vendor && \
    cd /lambda-php-vendor && \
    $PHP_BINDIR /opt/php-8-bin/bin/composer require guzzlehttp/guzzle


###### Create runtime image ######
FROM public.ecr.aws/lambda/provided as runtime
# Layer 1: PHP Binaries
COPY --from=builder $PHP_PREFIX /var/lang
# Layer 2: Runtime Interface Client
COPY --from=builder /lambda-php-runtime /var/runtime
# Layer 3: Vendor
COPY --from=builder /lambda-php-vendor/vendor /opt/vendor

COPY src/ /var/task/

CMD [ "authorizer" ]