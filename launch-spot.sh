#!/bin/bash

# Notes:
#  InstanceType must be GPU-enabled, currently g2.2xlarge is the only option
#  BlockDeviceMappings is only there to make sure volume is auto-deleted, not certain this is necessary
#  UserData: This is a very simple shim that does: \"curl <myurl> | bash\" so most of the logic lives off server
#  Subnet: The AZ selected will correspond to the AZ associated with the subnet
#     Your AZ will determine your pricing so this is important to keep an eye on
# 
#  I wanted to pass in the parameters using EC2 Tags, but Spot Instance Request tags aren't inherited by the descendant instances, which makes it a pain to use Tags


# Caution, there's hardcoded / invisible \r's below
SHIMB64=$( cat <<EOH | base64
#!/bin/bash
curl https://raw.githubusercontent.com/pabloav/aws-cudahashcat-auto/master/run.sh | bash -x
EOH)

# Be sure to use single quotes for HASH, as your $ may get interpolated
HASH='jimbo:$6$RqdxA5IE$CRYNB47dDqur77uZlv3nrU32XnUWY0DkbqAl5q5drYWR7vBAAW4gtRXZ/3rsKzh8Dc.x4r8kYD7tICiv3bpPx/'
HASHTYPE=1800
HASHCAT_ARGS="-a0 --username"
HASHCAT_DICT="rockyou.txt"

SUBNET=subnet-2a871d5d
AMI=ami-ecc79c84
SECURITY=sg-c73fb1a3
KEYPAIR=aws-pablo-20140912
IAMROLE=HashcatServer
REGION=us-east-1

requestid=$(aws ec2 request-spot-instances --region us-east-1 --spot-price 0.070 --launch-specification "{
	\"ImageId\":\"$AMI\",
	\"InstanceType\":\"g2.2xlarge\",
	\"SubnetId\":\"$SUBNET\",
	\"SecurityGroupIds\":[\"$SECURITY\"],
	\"KeyName\":\"$KEYPAIR\",
	\"UserData\":\"$SHIMB64\",
	\"BlockDeviceMappings\":[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"DeleteOnTermination\":true}}],
	\"IamInstanceProfile\":{\"Name\":\"$IAMROLE\"}
	}" | grep "SpotInstanceRequestId" | tr -d '", ' | cut -f2 -d:)



aws ec2 create-tags --region $REGION --resources $requestid --tags \
	Key=Hash,Value="$HASH" \
	Key=HashType,Value="$HASHTYPE" \
	Key=HashcatDict,Value="$HASHCAT_DICT" \
	Key=HashcatArgs,Value="$HASHCAT_ARGS"

