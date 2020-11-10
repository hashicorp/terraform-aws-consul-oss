#!/usr/bin/env bash

# install package

curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt-get update
apt-get install -y consul=${consul_version}

echo "Configuring system time"
timedatectl set-timezone UTC

echo "Starting deployment from AMI: ${ami}"
INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
AVAILABILITY_ZONE=$(curl -silent http://169.254.169.254/latest/meta-data/placement/availability-zone)
LOCAL_IPV4=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4`

echo "Create folder structure for Consul"
mkdir -p ${consul_path}/{data,log}
chown -R consul:consul ${consul_path}/
chmod -R 640 ${consul_path}/

echo "Creat configuration for Consul"
cat << EOF > /etc/consul.d/consul.hcl
datacenter          = "${datacenter}"
server              = false
data_dir            = "${consul_path}/data/"
advertise_addr      = "$${LOCAL_IPV4}"
client_addr         = "0.0.0.0"
ui                  = true
encrypt             = "${gossip_key}"

# AWS cloud join
retry_join          = ["provider=aws tag_key=Environment-Name tag_value=${environment_name}"]
EOF

cat << EOF > /etc/consul.d/logging.hcl
log_level            = "INFO"
log_file             = "${consul_path}/log/"
enable_syslog        = ${syslog}
log_rotate_max_files = "${log_rotate_max_files}"

%{ if time_based_rotation }
log_rotate_duration  = "${log_rotate_duration}"
%{ endif }
%{ if sized_log_rotation }
log_rotate_bytes     = "${log_rotate_bytes}"
%{ endif }
EOF

chown -R consul:consul /etc/consul.d
chmod -R 640 /etc/consul.d/*

systemctl daemon-reload
systemctl enable consul
systemctl start consul
