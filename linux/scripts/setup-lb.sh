#!/bin/bash

echo "=> Update APT and install HAProxy..."
apt-get update -y
apt-get install haproxy -y

echo "=> Backing up default config..."
cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak

echo "=> Configuring HAProxy Load Balancer..."
cat <<EOF >> /etc/haproxy/haproxy.cfg

# --- CUSTOM DEVOPS LAB CONFIGURATION ---
frontend http_front
    bind *:80
    stats uri /haproxy?stats
    default_backend apache_web_servers

backend apache_web_servers
    balance roundrobin
    server web1 192.168.56.11:80 check
    server web2 192.168.56.12:80 check
EOF

echo "=> Restarting HAProxy..."
systemctl restart haproxy
systemctl enable haproxy
