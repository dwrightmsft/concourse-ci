#!/bin/bash
SCRIPTOUTPUT=$1
CONCOURSEURL=$2
WEBIP=$3


# Download Concourse
wget -O concourse.tgz "$CONCOURSEURL"
tar xvzf concourse.tgz -C /usr/local
mkdir /etc/concourse

parted --script /dev/disk/azure/scsi1/lun0 mklabel gpt mkpart primary ext4 1MiB 100%
partprobe
mkfs.ext4 /dev/disk/azure/scsi1/lun0-part1
echo "/dev/disk/azure/scsi1/lun0-part1  /opt    ext4    defaults    0 2" >> /etc/fstab
mount -a
mkdir -p /opt/concourse/worker

cat > /etc/concourse/worker_environment << EOF
CONCOURSE_WORK_DIR=/opt/concourse/worker
CONCOURSE_TSA_HOST=$WEBIP:2222
CONCOURSE_TSA_PUBLIC_KEY=/etc/concourse/tsa_host_key.pub
CONCOURSE_TSA_WORKER_PRIVATE_KEY=/etc/concourse/worker_key
EOF

echo "$SCRIPTOUTPUT" | base64 -d > script.out
sed -n '/^###START-TSAWORKER-PRIVATE-KEY###$/,/^###END-TSAWORKER-PRIVATE-KEY###$/p' script.out | sed '1d;$d' > /etc/concourse/worker_key
sed -n '/^###START-TSA-PUBLIC-KEY###$/,/^###END-TSA-PUBLIC-KEY###$/p' script.out | sed '1d;$d' > /etc/concourse/tsa_host_key.pub

cat  > /etc/systemd/system/concourse-worker.service << EOF
[Unit]
Description=Concourse CI worker process

[Service]
User=root
Restart=on-failure
EnvironmentFile=/etc/concourse/worker_environment
ExecStart=/usr/local/concourse/bin/concourse worker

[Install]
WantedBy=multi-user.target
EOF

apt update -y
apt install -y resolvconf
echo -e "nameserver 168.63.129.16" > /etc/resolvconf/resolv.conf.d/head
service resolvconf restart

systemctl start concourse-worker
systemctl enable concourse-worker

