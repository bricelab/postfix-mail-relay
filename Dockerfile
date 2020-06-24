FROM ubuntu:latest

EXPOSE 25/tcp 465/tcp 587/tcp

VOLUME /var/log/postfix
VOLUME /var/spool/postfix

ENV MAILNAME mail.example.com
ENV MY_NETWORKS 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.0/8
ENV MY_DESTINATION localhost.localdomain, localhost
ENV ROOT_ALIAS admin@example.com
ENV USERNAME usernanme
ENV PASSWORD password

ENV DEBIAN_FRONTEND noninteractive

# apt-utils seems missing and warnings are shown, so we install it.
RUN apt-get update -q -q && \
 apt-get install --yes --force-yes apt-utils tzdata locales file sudo gnupg && \
 echo 'Africa/Porto-Novo' > /etc/timezone && \
 rm /etc/localtime && \
 dpkg-reconfigure tzdata && \
 apt-get upgrade --yes --force-yes && \
 rm -f /etc/cron.weekly/fstrim && \
 apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache ~/.npm

RUN apt-get update -q -q && \
 apt-get install --yes --force-yes runit && \
 apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache ~/.npm

COPY ./runsvdir-start /usr/local/sbin/runsvdir-start

# /etc/aliases should be available at postfix installation.
COPY ./etc/aliases /etc/aliases

RUN echo postfix postfix/main_mailer_type string "'Internet Site'" | debconf-set-selections && \
 echo postfix postfix/mynetworks string "127.0.0.0/8" | debconf-set-selections && \
 echo postfix postfix/mailname string temporary.example.com | debconf-set-selections && \
 apt-get update -q -q && \
 apt-get --yes --force-yes install postfix && \
 apt-get --yes --force-yes --no-install-recommends install rsyslog && \
 apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache ~/.npm

# We disable IPv6 for now, IPv6 is available in Docker even if the host does not have IPv6 connectivity.
RUN \
 postconf -e mydestination="localhost.localdomain, localhost" && \
 postconf -e smtpd_banner='$myhostname ESMTP $mail_name' && \
 postconf -# myhostname && \
 postconf -e inet_protocols=ipv4 && \
 sed -i 's/\/var\/log\/mail/\/var\/log\/postfix\/mail/' /etc/rsyslog.d/50-default.conf

RUN \
 echo '[mail.isp.example] username:password' > /etc/postfix/sasl_passwd && \
 postmap /etc/postfix/sasl_passwd && \
 chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db && \
 # specify SMTP relay host
 postconf -e relayhost="[mail.isp.example]" && \
 # enable SASL authentication
 postconf -e smtp_sasl_auth_enable="yes" && \
 # disallow methods that allow anonymous authentication.
 postconf -e smtp_sasl_security_options="noanonymous" && \
 # where to find sasl_passwd
 postconf -e smtp_sasl_password_maps="hash:/etc/postfix/sasl_passwd" && \
 # Enable STARTTLS encryption
 postconf -e smtp_use_tls="yes" && \
# where to find CA certificates
 postconf -e smtp_tls_CAfile="/etc/ssl/certs/ca-certificates.crt"

COPY ./etc /etc

#COPY ./ssl/csrconfig.txt /etc/ssl/csrconfig.txt

#COPY ./ssl/certconfig.txt /etc/ssl/certconfig.txt

ENTRYPOINT ["/usr/local/sbin/runsvdir-start"]