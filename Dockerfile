FROM alpine:3.6

# Inspired by wunderkraut/alpine-nginx-pagespeed (aka ilari/alpine-nginx-pagespeed:latest) with some extra modules.

RUN apk --no-cache add \
        ca-certificates \
        libuuid \
        apr \
        apr-util \
        libjpeg-turbo \
        icu \
        icu-libs \
        libressl \
        pcre \
        zlib

RUN set -x && \
    apk --no-cache add -t .build-deps \
        apache2-dev \
        apr-dev \
        apr-util-dev \
        build-base \
        curl \
        icu-dev \
        libjpeg-turbo-dev \
        linux-headers \
        gperf \
        libressl-dev \
        pcre-dev \
        python \
        zlib-dev && \

    # Build PageSpeed:
    # Check https://github.com/pagespeed/ngx_pagespeed/releases for the latest version
    PAGESPEED_VERSION=1.12.34.2 && \
    mkdir /tmp/ngx_pagespeed && \
    curl -L https://github.com/pagespeed/ngx_pagespeed/archive/v${PAGESPEED_VERSION}-stable.tar.gz | tar -zxC /tmp/ngx_pagespeed && \
    cd /tmp/ngx_pagespeed/* && \
    NPS_RELEASE_NUMBER=${NPS_VERSION/beta/} && \
    NPS_RELEASE_NUMBER=${NPS_VERSION/stable/} && \
    psol_url=https://dl.google.com/dl/page-speed/psol/${NPS_RELEASE_NUMBER}.tar.gz && \
    [ -e scripts/format_binary_url.sh ] && psol_url=$(scripts/format_binary_url.sh PSOL_BINARY_URL) && \
    # Extracts to ./psol/
    curl -L ${psol_url} | tar -xzv && \

    # Build Nginx with support for PageSpeed:
    # Check http://nginx.org/en/download.html for the latest version.
    NGINX_VERSION=1.12.1 && \
    mkdir /tmp/nginx && \
    curl -L http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar -zxC /tmp/nginx && \
    cd /tmp/nginx/* && \
    export CFLAGS='-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0' && \
    ./configure --add-module=/tmp/ngx_pagespeed/* && \
    make install --silent && \

    # Clean-up:
    cd && \
    apk del .build-deps && \
    rm -rf /tmp/* && \

    # forward request and error logs to docker log collector
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \

    # Make PageSpeed cache writable:
    mkdir -p /var/cache/ngx_pagespeed && \
    chmod -R o+wr /var/cache/ngx_pagespeed

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
