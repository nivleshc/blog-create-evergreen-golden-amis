#!/bin/bash
set -ex

sudo yum update -y
sudo /usr/sbin/update-motd --disable
echo 'No unauthorized access permitted' | sudo tee /etc/motd
sudo rm /etc/issue
sudo ln -s /etc/motd /etc/issue
sudo yum install -y elinks screen
sudo yum install git -y