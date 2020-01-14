#!/usr/bin/env bash

case $1 in
    'start' )
	apt-get install -y awscli
	SCHEDULE='* */4 * * *' # every four hours
	(crontab -l 2> /dev/null; echo "$SCHEDULE $(pwd)/$(basename $0)") | crontab - ;;
    'stop' )
	crontab -l | grep -v $(basename $0) | crontab - ;;
    *)
	INSTANCE=$(curl -fs http://169.254.169.254/latest/meta-data/instance-id)
	REGION=$(curl -fs http://169.254.169.254/latest/meta-data/placement/availability-zone)
	REGION=${REGION%?}
	OLD_IP=$(curl -fs http://169.254.169.254/latest/meta-data/public-ipv4)
	NEW_IP=$(aws ec2 allocate-address --query PublicIp --region $REGION | tr -d '"')
	echo ''
	echo "Old IP: $OLD_IP"
	echo "New IP: $NEW_IP"
	echo "Associating new IP $NEW_IP"
	echo ''
        allocationId=`aws ec2 describe-addresses --public-ips $NEW_IP --region $REGION --query 'Addresses[*].AllocationId' --output text`
	aws ec2 create-tags --resources $allocationId --tags Key=Name,Value=vms-youtube-backend
	aws ec2 associate-address --instance-id $INSTANCE --public-ip $NEW_IP --region $REGION
	if [ -n "$OLD_IP" ]; then
		echo ''
                allocationId=`aws ec2 describe-addresses --public-ips $OLD_IP --region $REGION --query 'Addresses[*].AllocationId' --output text`
		echo "Releasing old IP $OLD_IP with allocationId: $allocationId"
		aws ec2 release-address --allocation-id $allocationId --region $REGION
	fi
esac
