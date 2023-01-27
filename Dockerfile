FROM alpine:3.17.1 as builder

ENV POWERDNS_VER=4.7.3

# Install libs we need
RUN set -eux; \
	true "Installing build dependencies"; \
	apk add --no-cache \
		build-base \
		\
		boost-dev curl curl-dev geoip-dev krb5-dev openssl-dev \
		libsodium-dev lua-dev mariadb-connector-c-dev \
		protobuf-dev yaml-cpp-dev zeromq-dev mariadb-dev luajit-dev \
        libmaxminddb-dev

# Download packages
RUN set -eux; \
	mkdir -p build; \
	cd build; \
	wget "https://downloads.powerdns.com/releases/pdns-${POWERDNS_VER}.tar.bz2"; \
	tar -jxf "pdns-${POWERDNS_VER}.tar.bz2"


# Build and install PowerDNS
RUN set -eux; \
	cd build; \
	cd "pdns-${POWERDNS_VER}"; \
# Compiler flags
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
		--with-dynmodules="bind geoip gmysql lua2 pipe remote" \
		--with-libsodium \
		--enable-tools \
		--enable-ixfrdist \
		--enable-dns-over-tls \
		--disable-dependency-tracking \
		--disable-silent-rules \
		--enable-reproducible \
		--enable-unit-tests \
		--with-service-user=powerdns \
		--with-service-group=powerdns \
		--enable-remotebackend-zeromq; \
	make V=1 -j$(nproc) -l8 CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS"; \
	\
	pkgdir=/build/powerdns-root; \
	make DESTDIR="$pkgdir" install; \
	\
# Move some things around
	mv "$pkgdir"/etc/powerdns/pdns.conf-dist "$pkgdir"/etc/powerdns/pdns.conf; \
	mv "$pkgdir"/etc/powerdns/ixfrdist.example.yml "$pkgdir"/usr/share/doc/pdns/; \
# Remove cruft
	find "$pkgdir" -type f -name "*.a" -o -name "*.la" | xargs rm -fv; \
	rm -rfv \
		"$pkgdir"/usr/include \
		"$pkgdir"/usr/share/man


RUN set -eux; \
	cd build/powerdns-root; \
	scanelf --recursive --nobanner --osabi --etype "ET_DYN,ET_EXEC" .  | awk '{print $3}' | xargs \
		strip \
			--remove-section=.comment \
			--remove-section=.note \
			-R .gnu.lto_* -R .gnu.debuglto_* \
			-N __gnu_lto_slim -N __gnu_lto_v1 \
			--strip-unneeded

#
# Build final image
#
FROM alpine:3.17.1

ENV POWERADMIN_VER=3.4.2

ENV TZ=Europe/Moscow
ENV LANG ru_RU.UTF-8
ENV LANGUAGE ru_RU.UTF-8
ENV LC_ALL ru_RU.UTF-8
ENV MUSL_LOCPATH /usr/share/i18n/locales/musl

RUN set -eux; \
	true "PowerDNS and PowerAdmin requirements"; \
	apk add --no-cache \
		boost-libs \
		geoip \
		libcurl \
		libmaxminddb-libs \
		luajit \
		mariadb-client \
		mariadb-connector-c \
		yaml-cpp \
		zeromq \
		openssl \
		\
        pwgen \
		supervisor \
		nginx \
		php81 \
		php81-fpm \
		#php-mcrypt \
		php81-intl \
		php81-iconv \
		php81-mysqlnd \
		php81-pdo \
		php81-pdo_mysql \
		php81-gettext \
		php81-openssl \
		php81-session \
		php81-tokenizer \
		php81-mbstring \
		php81-xml \
		composer \
		musl musl-utils musl-locales tzdata \
		; \
	true "Setup user and group"; \
	addgroup -S powerdns 2>/dev/null; \
	adduser -S -D -h /var/lib/powerdns -s /sbin/nologin -G powerdns -g powerdns powerdns 2>/dev/null; \
	\
	true "Tools"; \
	apk add --no-cache \
		bind-tools \
		; \
	true "Cleanup"; \
	rm -f /var/cache/apk/*

RUN set -eux; \
	mkdir -p /var/www/html; \
	cd /var/www/html; \
	wget https://github.com/poweradmin/poweradmin/archive/refs/tags/v${POWERADMIN_VER}.tar.gz; \
	tar -xf v${POWERADMIN_VER}.tar.gz && rm -f v${POWERADMIN_VER}.tar.gz; \
	mv poweradmin-${POWERADMIN_VER} poweradmin; \
	rm -rf /var/www/html/poweradmin/install/

COPY --from=builder /build/powerdns-root /
COPY supervisor /etc/supervisor
COPY powerdns /etc/powerdns
COPY entrypoint /usr/bin
COPY nginx /etc/nginx
COPY php81 /etc/php81
COPY poweradmin /var/www/html/poweradmin/inc

RUN set -eux; \
	chmod 0750 /etc/powerdns; \
  	chmod 0640 /etc/powerdns/pdns.conf; \
  	chown -R root:powerdns /etc/powerdns; \
	chown -R nginx:nginx /var/www/html; \
	chmod +x /usr/bin/entrypoint; \
	cp /usr/share/zoneinfo/${TZ} /etc/localtime

EXPOSE 53 8081 80
EXPOSE 53/UDP

ENTRYPOINT [ "entrypoint" ]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
