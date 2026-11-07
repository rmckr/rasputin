FROM debian:bookworm-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  libauthen-ntlm-perl \
  libcgi-pm-perl \
  libcrypt-openssl-rsa-perl \
  libdata-uniqid-perl \
  libencode-imaputf7-perl \
  libfile-copy-recursive-perl \
  libfile-tail-perl \
  libhttp-daemon-perl \
  libhttp-daemon-ssl-perl \
  libhttp-message-perl \
  libio-socket-inet6-perl \
  libio-socket-ssl-perl \
  libio-tee-perl \
  libhtml-parser-perl \
  libjson-webtoken-perl \
  libmail-imapclient-perl \
  libmodule-scandeps-perl \
  libnet-server-perl \
  libnet-dns-perl \
  libparse-recdescent-perl \
  libproc-processtable-perl \
  libreadonly-perl \
  libregexp-common-perl \
  libsys-meminfo-perl \
  libterm-readkey-perl \
  libtest-mockobject-perl \
  libunicode-string-perl \
  liburi-perl \
  libwww-perl \
  make \
  time \
  cpanminus \
  wget \
  procps \
  ca-certificates \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG SUPERCRONIC_VERSION=0.2.29

# Install supercronic
RUN wget -q "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-$(dpkg --print-architecture)" \
    -O /usr/local/bin/supercronic && \
    chmod +x /usr/local/bin/supercronic
ENV TZ=Europe/Berlin

# Install imapsync
RUN wget https://imapsync.lamiral.info/imapsync \
    -O /usr/local/bin/imapsync \
    && chmod +x /usr/local/bin/imapsync
# optional
RUN cpanm IO::Socket::SSL

COPY ./crontab /etc/crontab

# Maildir mount
RUN mkdir -p /srv/vmail
WORKDIR /srv/vmail

CMD ["supercronic", "/etc/crontab"]
