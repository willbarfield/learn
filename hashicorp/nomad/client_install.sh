#!/bin/bash

# Install dependencies
echo "Installing Dependencies"
sudo yum update -y
sudo yum install -y jq
sudo yum install -y yum-utils

# Install Docker
sudo amazon-linux-extras install docker -y
sudo service docker start

# Download and Install Nomad via Package Manager
echo "Installing Nomad via Package Manager"
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install nomad

# Write a Client Configuration File
echo "Writing the Nomad configuration file"
sudo su
rm -f /etc/nomad.d/nomad.hcl
sudo cat << EOF > /etc/nomad.d/nomad.hcl
# Basic Starter Configuration Used for Nomad Course Demonstrations
# This is NOT a Secure Complete Nomad Client Configuration

name = "nomad_client_a"

# Directory to store agent state
data_dir = "/etc/nomad.d/data"

# Address the Nomad agent should bing to for networking
# 0.0.0.0 is the default and results in using the default private network interface
# Any configurations under the addresses parameter will take precedence over this value
bind_addr = "0.0.0.0"

advertise {
  # Defaults to the first private IP address.
  http = "10.0.102.108" # must be reachable by Nomad CLI clients
  rpc  = "10.0.102.108" # must be reachable by Nomad client nodes
  serf = "10.0.102.108" # must be reachable by Nomad server nodes
}

ports {
  http = 4646
  rpc  = 4647
  serf = 4648
}

# TLS configurations
tls {
  http = false
  rpc  = false

  ca_file   = "/etc/certs/ca.crt"
  cert_file = "/etc/certs/nomad.crt"
  key_file  = "/etc/certs/nomad.key"
}

# Specify the datacenter the agent is a member of
datacenter = "dc1"

# Logging Configurations
log_level = "INFO"
log_file  = "/etc/nomad.d/krausen.log"

# Server & Raft configuration
server {
  enabled = false
}

# Client Configuration - Node can be Server & Client
client {
  enabled = true
  server_join {
    retry_join = ["provider=aws tag_key=nomad_cluster_id tag_value=us-east-1"]
  }
}
EOF

# Enable and Start the Nomad Service
echo "Enabling and Starting the Nomad Service"
sudo systemctl enable nomad
sudo systemctl start nomad

echo "Completed"
