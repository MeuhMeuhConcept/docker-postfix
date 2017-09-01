#!/bin/bash
set -e

#judgement
if [[ ! -e /etc/supervisord.conf ]]; then
  echo "/etc/supervisord.conf file not found"
  exit 0
fi

#supervisor
cat > /etc/supervisord.conf <<EOF
[supervisord]
nodaemon=true

[program:postfix]
command=/opt/postfix.sh

[program:rsyslog]
command=/usr/sbin/rsyslogd -n
EOF

############
#  postfix
############
cat >> /opt/postfix.sh <<EOF
#!/bin/bash
/usr/sbin/postfix start
touch /var/log/mail.log
tail -f /var/log/mail.log
EOF
chmod +x /opt/postfix.sh
postconf -F '*/*/chroot = n'

############
# SASL SUPPORT FOR CLIENTS
# The following options set parameters needed by Postfix to enable
# Cyrus-SASL support for authentication of mail clients.
############
# /etc/postfix/main.cf
postconf -e smtpd_sasl_auth_enable=yes
postconf -e broken_sasl_auth_clients=yes
postconf -e smtpd_recipient_restrictions=permit_sasl_authenticated,reject_unauth_destination
# smtpd.conf
cat >> /usr/lib/sasl2/smtpd.conf <<EOF
pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM
EOF
# sasldb2
echo $smtp_user | tr , \\n > /tmp/passwd
regex="(.*)@(.*):(.*)"
sasl_ok=0
while read -r _line; do
    if [[ $_line =~ $regex ]]; then
        _user="${BASH_REMATCH[1]}"
        _domain="${BASH_REMATCH[2]}"
        _pwd="${BASH_REMATCH[3]}"
        echo "ADD USER" $_user "FOR" $_domain
        echo $_pwd | saslpasswd2 -p -c -u $_domain $_user
        sasl_ok=1
    fi
done < /tmp/passwd
if [[ $sasl_ok = 1 ]]; then
  chown postfix:postfix /etc/sasldb2
fi

############
# Enable TLS
############
if [[ -n "$(find /etc/postfix/certs -iname *.crt)" && -n "$(find /etc/postfix/certs -iname *.key)" ]]; then
  . "$(dirname $0)/configure-tls.sh"
fi

#############
#  opendkim
#############

if [[ -n "$(find /etc/opendkim/domainkeys -iname *.private)" ]]; then
  . "$(dirname $0)/configure-opendkim.sh"
fi

#############
#  Run
#############

/usr/bin/supervisord -c /etc/supervisord.conf
