#!/bin/bash
sudo su
yum update -y
cd /var/log/ 
aws s3 cp /var/log/maillog  s3://chidobucketpractice
