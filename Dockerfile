FROM alpine:3.11

MAINTAINER jn.germon@meuhmeuhconcept.com

# Install packages
RUN apk update && \
    apk add \
    bash \
    supervisor \
    postfix \
    opendkim \
    rsyslog \
    cyrus-sasl && \
    apk del --no-cache && \
    rm -rf /var/cache/apk/*

# Add installation file
ADD assets/install.sh /opt/install.sh

# Run
CMD /opt/install.sh;/usr/bin/supervisord -c /etc/supervisord.conf
