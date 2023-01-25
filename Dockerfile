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

# Copy in built binaries
COPY --from=builder /build/powerdns-root /

# Copy configs
COPY supervisor /etc/supervisor
COPY powerdns /etc/powerdns

RUN set -eux; \
	true "PowerDNS requirements"; \
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
		\
        pwgen \
		supervisor \
		nginx \
		php-fpm \
		#php-mcrypt \
		php-mysqlnd \
		php81-pdo \
		php81-pdo_mysql \
		php81-gettext \
		php81-openssl \
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
 	true "Setup poweradmin"; \
	mkdir -p /var/www/html; \
	cd /var/www/html; \
	rm -rf /var/www/html/*; \
	wget https://github.com/poweradmin/poweradmin/archive/refs/tags/v${POWERADMIN_VER}.tar.gz; \
	tar -xf v${POWERADMIN_VER}.tar.gz && rm -f v${POWERADMIN_VER}.tar.gz; \
	mv poweradmin-${POWERADMIN_VER} poweradmin; \
	rm -R /var/www/html/poweradmin/install; \
	\
	mkdir /run/powerdns; \
	chmod 0750 /etc/powerdns; \
  	chmod 0640 /etc/powerdns/pdns.conf; \
  	chown -R root:powerdns /etc/powerdns; \
	chown -R powerdns:powerdns /run/powerdns

EXPOSE 53/TCP 53/UDP 8081/TCP 80/TCP
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]


	#&& git clone https://github.com/poweradmin/poweradmin.git . \
	#&& git checkout b27f28b2d586afb201904437605be988ee048c22 \


# RUN set -eux; \
# 	true "Setup configuration"; \
# 	mkdir -p /etc/powerdns/conf.d; \
# 	sed -ri "s!^#?\s*(disable-syslog)\s*=\s*\S*.*!\1 = yes!" /etc/powerdns/pdns.conf; \
# 	grep -E "^disable-syslog = yes$" /etc/powerdns/pdns.conf; \
# 	sed -ri "s!^#?\s*(log-timestamp)\s*=\s*\S*.*!\1 = yes!" /etc/powerdns/pdns.conf; \
# 	grep -E "^log-timestamp = yes$" /etc/powerdns/pdns.conf; \
# 	sed -ri "s!^#?\s*(include-dir)\s*=\s*\S*.*!\1 = /etc/powerdns/conf.d!" /etc/powerdns/pdns.conf; \
# 	grep -E "^include-dir = /etc/powerdns/conf\.d$" /etc/powerdns/pdns.conf; \
# 	sed -ri "s!^#?\s*(launch)\s*=\s*\S*.*!\1 =!" /etc/powerdns/pdns.conf; \
# 	grep -E "^launch =$" /etc/powerdns/pdns.conf; \
# 	sed -ri "s!^#?\s*(socket-dir)\s*=\s*\S*.*!\1 = /run/powerdns!" /etc/powerdns/pdns.conf; \
# 	grep -E "^socket-dir = /run/powerdns$" /etc/powerdns/pdns.conf; \
# 	sed -ri "s!^#?\s*(version-string)\s*=\s*\S*.*!\1 = anonymous!" /etc/powerdns/pdns.conf; \
# 	grep -E "^version-string = anonymous$" /etc/powerdns/pdns.conf; \
# 	chmod 0750 /etc/powerdns; \
# 	chmod 0640 /etc/powerdns/pdns.conf; \
# 	chown -R root:powerdns /etc/powerdns


# PowerDNS


# COPY usr/local/share/flexible-docker-containers/init.d/42-powerdns.sh /usr/local/share/flexible-docker-containers/init.d
# COPY usr/local/share/flexible-docker-containers/pre-init-tests.d/42-powerdns.sh /usr/local/share/flexible-docker-containers/pre-init-tests.d
# COPY usr/local/share/flexible-docker-containers/pre-init-tests.d/43-powerdns-mysql.sh /usr/local/share/flexible-docker-containers/pre-init-tests.d
# COPY usr/local/share/flexible-docker-containers/pre-init-tests.d/43-powerdns-postgres.sh /usr/local/share/flexible-docker-containers/pre-init-tests.d
# COPY usr/local/share/flexible-docker-containers/pre-init-tests.d/43-powerdns-zonefile.sh /usr/local/share/flexible-docker-containers/pre-init-tests.d
# COPY usr/local/share/flexible-docker-containers/tests.d/42-powerdns-mysql.sh /usr/local/share/flexible-docker-containers/tests.d
# COPY usr/local/share/flexible-docker-containers/tests.d/42-powerdns-postgres.sh /usr/local/share/flexible-docker-containers/tests.d
# COPY usr/local/share/flexible-docker-containers/tests.d/43-powerdns.sh /usr/local/share/flexible-docker-containers/tests.d
# COPY usr/local/share/flexible-docker-containers/tests.d/99-powerdns.sh /usr/local/share/flexible-docker-containers/tests.d
# COPY usr/local/share/flexible-docker-containers/healthcheck.d/42-powerdns.sh /usr/local/share/flexible-docker-containers/healthcheck.d
# RUN set -eux; \
# 	true "Flexible Docker Containers"; \
# 	if [ -n "$VERSION_INFO" ]; then echo "$VERSION_INFO" >> /.VERSION_INFO; fi; \
# 	true "Permissions"; \
# 	chown root:root \
# 		/etc/supervisor/conf.d/powerdns.conf; \
# 	chmod 0644 \
# 		/etc/supervisor/conf.d/powerdns.conf; \
# 	fdc set-perms


