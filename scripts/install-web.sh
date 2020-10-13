#!/bin/bash
CONCOURSEURL=$1
PSQLUSER=$2
PSQLPASSWORD=$3
PSQLNAME=$4
PSQLFQDN=$5
CONCOURSEUSER=$6
CONCOURSEPW=$7
APPGWIP=$8

# Download Concourse
wget -O concourse.tgz "$CONCOURSEURL"
tar xvzf concourse.tgz -C /usr/local
mkdir /etc/concourse
ssh-keygen -t rsa -q -N '' -f /etc/concourse/tsa_host_key
ssh-keygen -t rsa -q -N '' -f /etc/concourse/worker_key
ssh-keygen -t rsa -q -N '' -f /etc/concourse/session_signing_key
cp /etc/concourse/worker_key.pub /etc/concourse/authorized_worker_keys

apt update -y
apt install -y postgresql-client
PGPASSWORD=$PSQLPASSWORD psql -h $PSQLFQDN -U $PSQLUSER@$PSQLNAME -d postgres -w -c "CREATE DATABASE concourse;"
cat > /etc/concourse/web_environment << EOF    
    CONCOURSE_ADD_LOCAL_USER=$CONCOURSEUSER:$CONCOURSEPW
    CONCOURSE_SESSION_SIGNING_KEY=/etc/concourse/session_signing_key
    CONCOURSE_TSA_HOST_KEY=/etc/concourse/tsa_host_key
    CONCOURSE_TSA_AUTHORIZED_KEYS=/etc/concourse/authorized_worker_keys
    CONCOURSE_POSTGRES_HOST=$PSQLFQDN
    CONCOURSE_POSTGRES_USER=$PSQLUSER@$PSQLNAME
    CONCOURSE_POSTGRES_PASSWORD=$PSQLPASSWORD
    CONCOURSE_POSTGRES_DATABASE=concourse
    CONCOURSE_MAIN_TEAM_LOCAL_USER=admin
    CONCOURSE_POSTGRES_SSLMODE=require
    CONCOURSE_EXTERNAL_URL=http://$APPGWIP
EOF
mkdir /var/lib/concourse
adduser --system --group concourse
chown -R concourse:concourse /etc/concourse /var/lib/concourse
chmod 600 /etc/concourse/*_environment

cat > /etc/systemd/system/concourse-web.service << EOF
[Unit]
Description=Concourse CI web process (ATC and TSA)

[Service]
User=concourse
Restart=on-failure
EnvironmentFile=/etc/concourse/web_environment
ExecStart=/usr/local/concourse/bin/concourse web

[Install]
WantedBy=multi-user.target
EOF

systemctl start concourse-web
systemctl enable concourse-web

echo "###START-TSA-PUBLIC-KEY###"
cat /etc/concourse/tsa_host_key.pub
echo "###END-TSA-PUBLIC-KEY###"
echo "###START-TSAWORKER-PRIVATE-KEY###"
cat /etc/concourse/worker_key
echo "###END-TSAWORKER-PRIVATE-KEY###"