#!/bin/bash

echo Configure OPENDKIM

cat >> /etc/supervisord.conf <<EOF
[program:opendkim]
command=/opt/opendkim.sh
EOF

cat >> /opt/opendkim.sh <<EOF
#!/bin/bash
SOCKET="inet:12301@localhost"
/usr/sbin/opendkim -f -x /etc/opendkim.conf
EOF
chmod +x /opt/opendkim.sh

# /etc/postfix/main.cf
postconf -e milter_protocol=2
postconf -e milter_default_action=accept
postconf -e smtpd_milters=inet:localhost:12301
postconf -e non_smtpd_milters=inet:localhost:12301

cat >> /etc/opendkim.conf <<EOF
AutoRestart             Yes
AutoRestartRate         10/1h
UMask                   002
Syslog                  yes
SyslogSuccess           Yes
LogWhy                  Yes
Canonicalization        relaxed/simple
ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable
Mode                    sv
PidFile                 /var/run/opendkim/opendkim.pid
SignatureAlgorithm      rsa-sha256
UserID                  opendkim:opendkim
Socket                  inet:12301@localhost
EOF

cat >> /etc/opendkim/TrustedHosts <<EOF
127.0.0.1
localhost
192.168.0.1/24
EOF

mkdir /etc/opendkim/_domainkeys
chown -R opendkim:opendkim /etc/opendkim/_domainkeys
chmod 500 /etc/opendkim/_domainkeys

cp /etc/opendkim/domainkeys/* /etc/opendkim/_domainkeys/

regex="\/([^.\/]+)\.(.+)\.private$"
for f in $(find /etc/opendkim/_domainkeys -iname "*.private")
    do
        if [[ $f =~ $regex ]];then
            _selector="${BASH_REMATCH[1]}"
            _domain="${BASH_REMATCH[2]}"

            echo "ADD KEY" $f

            cat >> /etc/opendkim/TrustedHosts <<EOF
*.$_domain
EOF
            cat >> /etc/opendkim/KeyTable <<EOF
$_selector._domainkey.$_domain $_domain:$_selector:$f
EOF
            cat >> /etc/opendkim/SigningTable <<EOF
*@$_domain $_selector._domainkey.$_domain
EOF

          chmod 400 $f
          chown opendkim:opendkim $f
        else
            echo "filename" $f "is malformed (<selector>.<domain>.private)"
        fi
    done
