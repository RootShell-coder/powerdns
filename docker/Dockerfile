# ---------------------------------------------------------------------------------------
FROM alpine:3.22 AS pdns_authoritive

ENV POWERDNS_VER=4.9.9

RUN set -eux; \
  apk add --no-cache \
  build-base \
  autoconf \
  automake \
  libtool \
  pkgconf \
  \
  boost-dev curl-dev geoip-dev krb5-dev openssl-dev \
  libsodium-dev lua-dev mariadb-connector-c-dev \
  protobuf-dev yaml-cpp-dev zeromq-dev mariadb-dev postgresql-dev \
  luajit-dev libmaxminddb-dev; \
  rm -f /var/cache/apk/*

RUN set -eux; \
  mkdir -p build; \
  cd build; \
  wget "https://downloads.powerdns.com/releases/pdns-${POWERDNS_VER}.tar.bz2"; \
  tar -jxf "pdns-${POWERDNS_VER}.tar.bz2"; \
  rm "pdns-${POWERDNS_VER}.tar.bz2"

RUN set -eux; \
  cd build; \
  cd "pdns-${POWERDNS_VER}"; \
  autoreconf -vi; \
  export CFLAGS="-march=x86-64 -mtune=generic -Os -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -fstack-clash-protection -fcf-protection -flto=auto"; \
  export CXXFLAGS="-Wp,-D_GLIBCXX_ASSERTIONS"; \
  export LDFLAGS="-Wl,-Os,--sort-common,--as-needed,-z,relro,-z,now -flto=auto"; \
  \
  ./configure \
    --prefix=/usr \
    --sysconfdir="/etc/powerdns" \
    --sbindir=/usr/sbin \
    --mandir=/usr/share/man \
    --infodir=/usr/share/info \
    --localstatedir=/var \
    --libdir="/usr/lib/powerdns" \
    --disable-static \
    --with-modules="" \
    --with-dynmodules="bind geoip gmysql gpgsql lua2 pipe remote" \
    --with-libsodium \
    --enable-tools \
    --enable-ixfrdist \
    --enable-dns-over-tls \
    --disable-dependency-tracking \
    --disable-silent-rules \
    --enable-reproducible \
    --with-service-user=powerdns \
    --with-service-group=powerdns \
    --enable-remotebackend-zeromq; \
  make V=1 -j$(nproc) -l8 CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS"; \
  pkgdir=/build/powerdns-root; \
  make DESTDIR="$pkgdir" install; \
  find "$pkgdir" -type f -name "*.a" -o -name "*.la" | xargs rm -fv; \
  mv "$pkgdir"/etc/powerdns/pdns.conf-dist "$pkgdir"/etc/powerdns/pdns.example.conf;

RUN set -eux; \
  cd build/powerdns-root; \
  scanelf --recursive --nobanner --osabi --etype "ET_DYN,ET_EXEC" .  | awk '{print $3}' | xargs \
  strip \
  --remove-section=.comment \
  --remove-section=.note \
  -R .gnu.lto_* -R .gnu.debuglto_* \
  -N __gnu_lto_slim -N __gnu_lto_v1 \
  --strip-unneeded

# ---------------------------------------------------------------------------------------
FROM debian AS poweradmin

ENV POWERADMIN_VER=4.0.4

RUN set -eux; \
  apt-get update && apt-get install -y wget; \
  mkdir -p /var/www/html; \
  cd /var/www/html; \
  wget https://github.com/poweradmin/poweradmin/archive/refs/tags/v${POWERADMIN_VER}.tar.gz; \
  tar -xf v${POWERADMIN_VER}.tar.gz && rm -f v${POWERADMIN_VER}.tar.gz; \
  mv poweradmin-${POWERADMIN_VER} poweradmin;

# ---------------------------------------------------------------------------------------
FROM alpine:3.22

RUN apk update && \
    apk add --no-cache \
    php83 php83-cli php83-fpm php83-intl php83-gettext php83-openssl \
    php83-pdo php83-xml php83-simplexml php83-pdo_mysql php83-pdo_pgsql \
    php83-pdo_sqlite php83-ldap php83-json php83-mbstring php83-dom \
    php83-session php83-curl php83-gd php83-opcache php83-fileinfo \
    php83-iconv php83-phar php83-ctype php83-posix php83-zip php83-zlib \
    php83-tokenizer nginx wget libsodium luajit mariadb-connector-c; \
    rm -f /var/cache/apk/*

ADD https://github.com/just-containers/s6-overlay/releases/download/v3.1.6.2/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v3.1.6.2/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz
RUN rm -rf /tmp/*

COPY --from=pdns_authoritive /build/powerdns-root /
COPY --from=poweradmin /var/www/html /var/www/html
COPY ./nginx /etc/nginx
COPY ./entrypoint /usr/bin

RUN mkdir -p /etc/services.d/pdns /etc/services.d/nginx /etc/services.d/php-fpm && \
    printf '%s\n' \
    '#!/bin/sh' \
    'exec pdns_server' \
    > /etc/services.d/pdns/run && chmod +x /etc/services.d/pdns/run && \
    printf '%s\n' \
    '#!/bin/sh' \
    'exec nginx -g "daemon off;"' \
    > /etc/services.d/nginx/run && chmod +x /etc/services.d/nginx/run && \
    printf '%s\n' \
    '#!/bin/sh' \
    'exec php-fpm --nodaemonize --fpm-config /etc/php/php-fpm.d/www.conf' \
    > /etc/services.d/php-fpm/run && chmod +x /etc/services.d/php-fpm/run

RUN ln -sf /usr/bin/php83 /usr/bin/php && \
    ln -sf /usr/sbin/php-fpm83 /usr/sbin/php-fpm && \
    ln -sf /etc/php83 /etc/php && \
    chmod +x /usr/bin/entrypoint

RUN mkdir -p /var/log/php83 /run/php

RUN printf '%s\n' \
    '[www]' \
    'user = nobody' \
    'group = nobody' \
    'listen = 0.0.0.0:9000' \
    'listen.owner = nobody' \
    'listen.group = nogroup' \
    'listen.mode = 0660' \
    'pm = dynamic' \
    'pm.max_children = 5' \
    'pm.start_servers = 2' \
    'pm.min_spare_servers = 1' \
    'pm.max_spare_servers = 3' \
    'pm.max_requests = 500' \
    'chdir = /var/www/html' \
    'catch_workers_output = yes' \
    > /etc/php/php-fpm.d/www.conf

RUN printf '%s\n' \
    'memory_limit = 256M' \
    'upload_max_filesize = 32M' \
    'post_max_size = 33M' \
    'max_execution_time = 30' \
    'max_input_time = 60' \
    'display_errors = Off' \
    'log_errors = On' \
    'error_log = /var/log/php83/error.log' \
    'expose_php = Off' \
    '' \
    '; Session' \
    'session.save_path = "/tmp"' \
    '' \
    '; OPcache' \
    'opcache.enable=1' \
    'opcache.memory_consumption=128' \
    'opcache.max_accelerated_files=4000' \
    'opcache.revalidate_freq=60' \
    > /etc/php/conf.d/99-custom.ini

RUN printf '%s\n' \
    'launch=gmysql' \
    'gmysql-host=mariadb' \
    'gmysql-user=pdns_user' \
    'gmysql-password=pdns_pass' \
    'gmysql-dbname=pdns_db' \
    > /etc/powerdns/pdns.conf

VOLUME ["/etc/nginx/", "/etc/powerdns/", "/var/www/html/poweradmin/"]

WORKDIR /var/www/html
EXPOSE 53 80
ENTRYPOINT ["entrypoint"]
