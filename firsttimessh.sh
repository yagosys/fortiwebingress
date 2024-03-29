#!/bin/bash 
host="$1"
port="$2"
username="$3"
new_password="$4"
rm $HOME/.ssh/known_hosts
# Loop until SSH host is available
while ! nc -z $host $port; do   
  echo "Waiting for SSH host $host on port $port to become available..."
  sleep 5 # Wait for 5 seconds before checking again
done

echo "SSH host $host on port $port is available for connect"
echo
echo $new_password
sleep 5
/usr/bin/expect <<EOF
spawn ssh -o "StrictHostKeyChecking=no" -p $port $username@$host
expect "password:"
send "\r"
expect "old password:"
send "\r"
expect "new password:"
send "$new_password\r"
expect "new password:"
send "$new_password\r"
interact
EOF

#./firsttimessh.sh k8strainingmaster001.westus.cloudapp.azure.com 2222 admin "Welcome.123"

