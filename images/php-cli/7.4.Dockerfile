ARG IMAGE_REPO
FROM ${IMAGE_REPO:-lagoon}/php-7.4-fpm

LABEL org.opencontainers.image.authors="The Lagoon Authors" maintainer="The Lagoon Authors"
LABEL org.opencontainers.image.source="https://github.com/uselagoon/lagoon-images" repository="https://github.com/uselagoon/lagoon-images"

ENV LAGOON=cli

# Defining Versions - Composer
# @see https://getcomposer.org/download/
ENV COMPOSER_VERSION=1.10.22 \
  COMPOSER_HASH_SHA256=6127ae192d3b56cd6758c7c72fe2ac6868ecc835dae1451a004aca10ab1e0700

RUN apk add --no-cache git \
        unzip \
        gzip  \
        bash \
        openssh-client \
        rsync \
        patch \
        procps \
        coreutils \
        mariadb-client \
        postgresql-client \
        mongodb-tools \
        openssh-sftp-server \
        findutils \
        nodejs-current \
        npm \
        yarn \
    && ln -s /usr/lib/ssh/sftp-server /usr/local/bin/sftp-server \
    && rm -rf /var/cache/apk/* \
    && curl -L -o /usr/local/bin/composer https://github.com/composer/composer/releases/download/${COMPOSER_VERSION}/composer.phar \
    && echo "$COMPOSER_HASH_SHA256  /usr/local/bin/composer" | sha256sum -c \
    && chmod +x /usr/local/bin/composer \
    && php -d memory_limit=-1 /usr/local/bin/composer global require hirak/prestissimo \
    && mkdir -p /home/.ssh \
    && fix-permissions /home/

# Adding Composer vendor bin path to $PATH.
ENV PATH="/home/.composer/vendor/bin:${PATH}"
# We not only use "export $PATH" as this could be overwritten again
# like it happens in /etc/profile of alpine Images.
COPY entrypoints /lagoon/entrypoints/

# Remove warning about running as root in composer
ENV COMPOSER_ALLOW_SUPERUSER=1

# Making sure the path is not only added during entrypoint, but also when creating a new shell
RUN echo "source /lagoon/entrypoints/90-composer-path.sh" >> /home/.bashrc
# Make sure shells are not running forever
RUN echo "source /lagoon/entrypoints/80-shell-timeout.sh" >> /home/.bashrc
# Make sure xdebug is automatically enabled also for cli scripts
RUN echo "source /lagoon/entrypoints/61-php-xdebug-cli-env.sh" >> /home/.bashrc
# helper functions
RUN echo "source /lagoon/entrypoints/55-cli-helpers.sh" >> /home/.bashrc

# Copy mariadb-client configuration.
COPY mariadb-client.cnf /etc/my.cnf.d/
RUN fix-permissions /etc/my.cnf.d/

# SSH Key and Agent Setup
COPY ssh_config /etc/ssh/ssh_config
COPY id_ed25519_lagoon_cli.key /home/.ssh/lagoon_cli.key
RUN chmod 400 /home/.ssh/lagoon_cli.key
ENV SSH_AUTH_SOCK=/tmp/ssh-agent

ENTRYPOINT ["/sbin/tini", "--", "/lagoon/entrypoints.sh"]
CMD ["/bin/docker-sleep"]
