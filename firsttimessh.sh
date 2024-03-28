#!/bin/bash 
host="$1"
port="$2"
username="$3"
new_password="$4"

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

#first_time_ssh_to_remotehost_and_setup_password "$1" "$2" "$3" "$4"
#first_time_ssh_to_remotehost_and_setup_password "20.239.245.125" 2222 "admin" "Welcome.123"
