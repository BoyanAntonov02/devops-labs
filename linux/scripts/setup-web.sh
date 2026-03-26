#!/bin/bash

echo "=> Update APT and install Apache2..."
apt-get update -y
apt-get install apache2 -y

echo "=> Creating a custom index.html to show the server's hostname..."
HOSTNAME=$(hostname)
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head><title>DevOps Lab</title></head>
<body style="background-color: #282a36; color: #f8f8f2; font-family: sans-serif; text-align: center; padding-top: 50px;">
    <h1>Test: <span style="color: #50fa7b;">$HOSTNAME</span></h1>
    <p>Opsss</p>
</body>
</html>
EOF

echo "=> Restarting Apache..."
systemctl restart apache2
systemctl enable apache2
