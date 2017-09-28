FROM php:7-fpm-alpine

ENV NGINX_VERSION 1.10.2

ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 8.5.0

# install necessary prerequisites
RUN apk --no-cache add supervisor zlib-dev icu-dev autoconf g++ make pcre-dev

RUN docker-php-ext-install opcache \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install intl \
    && docker-php-ext-install mbstring \
    && pecl install xdebug \
    && pecl install apcu-5.1.8 \
    && docker-php-ext-enable apcu

# install nginx
RUN GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 \
	&& CONFIG="\
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--modules-path=/usr/lib/nginx/modules \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--pid-path=/var/run/nginx.pid \
		--lock-path=/var/run/nginx.lock \
		--http-client-body-temp-path=/var/cache/nginx/client_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
		--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
		--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
		--user=nginx \
		--group=nginx \
		--with-http_ssl_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_mp4_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_random_index_module \
		--with-http_secure_link_module \
		--with-http_stub_status_module \
		--with-http_auth_request_module \
		--with-http_xslt_module=dynamic \
		--with-http_image_filter_module=dynamic \
		--with-http_geoip_module=dynamic \
		--with-http_perl_module=dynamic \
		--with-threads \
		--with-stream \
		--with-stream_ssl_module \
		--with-http_slice_module \
		--with-mail \
		--with-mail_ssl_module \
		--with-file-aio \
		--with-http_v2_module \
		--with-ipv6 \
	" \
    && addgroup -S nginx \
    && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& apk add --no-cache --virtual .build-deps \
		gcc \
		libc-dev \
		make \
		openssl-dev \
		pcre-dev \
		zlib-dev \
		linux-headers \
		curl \
		gnupg \
		libxslt-dev \
		gd-dev \
		geoip-dev \
		perl-dev \
	&& curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
	&& curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEYS" \
	&& gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
	&& rm -r "$GNUPGHOME" nginx.tar.gz.asc \
	&& mkdir -p /usr/src \
	&& tar -zxC /usr/src -f nginx.tar.gz \
	&& rm nginx.tar.gz \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& ./configure $CONFIG --with-debug \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& mv objs/nginx objs/nginx-debug \
	&& mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
	&& mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
	&& mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
	&& mv objs/ngx_http_perl_module.so objs/ngx_http_perl_module-debug.so \
	&& ./configure $CONFIG \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& install -m644 html/index.html /usr/share/nginx/html/ \
	&& install -m644 html/50x.html /usr/share/nginx/html/ \
	&& install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
	&& install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
	&& install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
	&& install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
	&& install -m755 objs/ngx_http_perl_module-debug.so /usr/lib/nginx/modules/ngx_http_perl_module-debug.so \
	&& ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	&& rm -rf /usr/src/nginx-$NGINX_VERSION \
	\
	# Bring in gettext so we can get `envsubst`, then throw
	# the rest away. To do this, we need to install `gettext`
	# then move `envsubst` out of the way so `gettext` can
	# be deleted completely, then move `envsubst` back.
	&& apk add --no-cache --virtual .gettext gettext \
	&& mv /usr/bin/envsubst /tmp/ \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --no-cache --virtual .nginx-rundeps $runDeps \
	&& apk del .build-deps \
	&& apk del .gettext \
	&& mv /tmp/envsubst /usr/local/bin/ \
	\
	# forward request and error logs to docker log collector
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

RUN   apk update \
   &&   apk add ca-certificates wget \
   &&   update-ca-certificates

# install gd image manipulation library
RUN apk add --no-cache freetype-dev libjpeg-turbo-dev libpng-dev \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install gd exif

# install wkhtmltox
# RUN wget -q https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.3/wkhtmltox-0.12.3_linux-generic-amd64.tar.xz \
#     && tar -xf wkhtmltox-0.12.3_linux-generic-amd64.tar.xz \
#     && ls -la \
#     && mv wkhtmltox/ /opt/ \
#     && rm -rf wkhtmltox-0.12.3_linux-generic-amd64.tar.xz

# RUN apk add --no-cache \
#             xvfb \
#             # Additionnal dependencies for better rendering
#             ttf-freefont \
#             fontconfig \
#             dbus \
#     && \
#
#     # Install wkhtmltopdf from `testing` repository
#     apk add qt5-qtbase-dev \
#             wkhtmltopdf \
#             --no-cache \
#             --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ \
#             --allow-untrusted \
#     && \
#
#     # Wrapper for xvfb
#     mv /usr/bin/wkhtmltopdf /usr/bin/wkhtmltopdf-origin && \
#     echo $'#!/usr/bin/env sh\n\
# Xvfb :0 -screen 0 1024x768x24 -ac +extension GLX +render -noreset & \n\
# DISPLAY=:0.0 wkhtmltopdf-origin $@ \n\
# killall Xvfb\
# ' > /usr/bin/wkhtmltopdf && \
#     chmod +x /usr/bin/wkhtmltopdf

RUN apk add --update --no-cache \
    libgcc libstdc++ libx11 glib libxrender libxext libintl \
    libcrypto1.0 libssl1.0 \
    ttf-dejavu ttf-droid ttf-freefont ttf-liberation ttf-ubuntu-font-family

# on alpine static compiled patched qt headless wkhtmltopdf (47.2 MB)
# compilation takes 4 hours on EC2 m1.large in 2016 thats why binary
COPY wkhtmltopdf /usr/local/bin/

# install git and composer
RUN apk add --no-cache git  \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# install node
RUN apk add --no-cache --update nodejs

# RUN addgroup -g 1000 node \
#   && adduser -u 1000 -G node -s /bin/sh -D node \
#   && apk add --no-cache \
#       libstdc++ \
#   && apk add --no-cache --virtual .build-deps \
#       binutils-gold \
#       curl \
#       g++ \
#       gcc \
#       gnupg \
#       libgcc \
#       linux-headers \
#       make \
#       python \
# # gpg keys listed at https://github.com/nodejs/node#release-team
# && for key in \
#   9554F04D7259F04124DE6B476D5A82AC7E37093B \
#   94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
#   FD3A5288F042B6850C66B31F09FE44734EB7990E \
#   71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
#   DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
#   B9AE9905FFD7803F25714661B63B535A4C206CA9 \
#   C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
#   56730D5401028683275BD23C23EFEFE93C4CFFFE \
# ; do \
#   gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
#   gpg --keyserver keyserver.pgp.com --recv-keys "$key" || \
#   gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" ; \
# done \
#   && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
#   && curl -SLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
#   && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
#   && grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
#   && tar -xf "node-v$NODE_VERSION.tar.xz" \
#   && cd "node-v$NODE_VERSION" \
#   && ./configure \
#   && make -j$(getconf _NPROCESSORS_ONLN) \
#   && make install \
#   && apk del .build-deps \
#   && cd .. \
#   && rm -Rf "node-v$NODE_VERSION" \
#   && rm "node-v$NODE_VERSION.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt
#
# ENV YARN_VERSION 1.0.2
#
# RUN apk add --no-cache --virtual .build-deps-yarn curl gnupg tar \
# && for key in \
#   6A010C5166006599AA17F08146C2130DFD2497F5 \
# ; do \
#   gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
#   gpg --keyserver keyserver.pgp.com --recv-keys "$key" || \
#   gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" ; \
# done \
# && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
# && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
# && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
# && mkdir -p /opt/yarn \
# && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/yarn --strip-components=1 \
# && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn \
# && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarnpkg \
# && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
# && apk del .build-deps-yarn

RUN set -x \
  && npm install --silent -g bower

# copy configuration files
COPY entrypoint.sh /entrypoint.sh
COPY php.mango.ini /usr/local/etc/php/php.ini
COPY supervisord.conf /etc/supervisord.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

WORKDIR /app

EXPOSE 80 443 9000

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/bin/supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]
