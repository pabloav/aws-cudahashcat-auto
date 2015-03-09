#!/bin/bash

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=$(echo $AZ | sed -e 's:\([0-9][0-9]*\)[a-z]*:\1:')

echo "Instance: $INSTANCE_ID - AZ: $AZ - REGION: $REGION"

S3BUCKET=cudahashcat
S3FOLDER=incoming
S3OBJECT=output.$( date +"%Y%m%d-%H%M" ).$INSTANCE_ID.txt

OUTFILE=output.txt

tmpdir=$(mktemp -d)
cd $tmpdir

cudahome=/root/cudaHashcat-1.33
chmod a+x $cudahome/*.bin

# Install awscli 
( apt-get update -qq; apt-get install -qq -y awscli )

# This retrieves the rockyou password file, you might not want this if you're bruteforcing
aws s3 cp --region $REGION s3://$S3BUCKET/assets/rockyou.txt rockyou.txt

# Figured out a way to get the HASH and HASHTYPE parameters from Tags, 
# but it takes a little more effort because we get it form the spot instance request
# The upside is if/when we get to parallelizing, all instances will get the same hash

SIRID=$(aws ec2 describe-instances --region $REGION --instance-id $INSTANCE_ID | grep SpotInstanceRequestId | tr -d '", ' | cut -f2 -d:)

HASHTYPE=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$SIRID" "Name=key,Values=HashType" --region $REGION --output=text | cut -f5)
HASH=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$SIRID" "Name=key,Values=Hash" --region $REGION --output=text | cut -f5)
HASHCAT_ARGS=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$SIRID" "Name=key,Values=HashcatArgs" --region $REGION --output=text | cut -f5)

if [ "$HASHCAT_ARGS" == "" ]; then
  HASHCAT_ARGS="-a0"
fi


HASHCAT_ARGS="$HASHCAT_ARGS -m $HASHTYPE --status --status-timer=60 --outfile=$tmpdir/$OUTFILE --outfile-format=7"
HASHCAT_DICT=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$SIRID" "Name=key,Values=HashcatDict" --region $REGION --output=text | cut -f5)

if [ "$HASHCAT_DICT" == "" ]; then
  HASHCAT_DICT="rockyou.txt"
fi

echo $HASH > $tmpdir/passwd.txt

cat <<EOH > $tmpdir/screenrc
sessionname hashcat
screen -t shutdown 2
stuff "shutdown -h +55"

screen -t crack 0
stuff "$cudahome/cudaHashcat64.bin $HASHCAT_ARGS $tmpdir/passwd.txt $HASHCAT_DICT ; aws s3 cp --region $REGION $OUTFILE s3://$S3BUCKET/$S3FOLDER/$S3OBJECT "

EOH

screen -d -m -c $tmpdir/screenrc
