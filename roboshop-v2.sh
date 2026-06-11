#!/bin/bash
## AUtomate instances
AMI_ID="ami-0220d79f3f480ecf5"
ZONE_ID="Z0968816Y6XJN6LDEDWK"
DOMAIN_NAME="learndevopskills.shop"

#check for validation with atleast 2 arguments
if [ $# -lt 2 ]; then
    echo -e "$R [ERROR]: $N Atleast two arguments must be passed"
    echo -e "USAGE: $0 [create/destroy] [instance1] [instamce...]"
    exit 1
fi

ACTION=$1
shift 

if [ "$ACTION" != "create" ] && [ "$ACTION" != "delete" ]; then
    echo -e "$R ERROR:: $N First argument either create or delete"
    echo -e "USAGE: $0 [create/destroy] [instance1] [instamce...]"
    exit 1
fi

get_instance_id(){
    name=$1
     ( aws ec2 describe-instances --filters "Name=tag:Name,Values=roboshop-$name" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text 
     )
    
}

for instance in $@
do
    INSTANCE_ID=$(get_instance_id "$instance")
    if [ "$ACTION" == "create" ]; then
        if [ "$INSTANCE_ID" == "None" ]; then
            echo "Launching instance: roboshop-$instance"
            INSTANCE_ID=$( aws ec2 run-instances \
            --image-id $AMI_ID \
            --instance-type t3.micro \
            --security-groups "roboshop-common" "roboshop-$instance" \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]" \
            --query 'Instances[0].InstanceId' \
            --output text
            )
            echo " Launched Instance ID: $INSTANCE_ID"

            #update Route53 record
            if [ $instance == "frontend" ]; then
            IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
            --query 'Reservations[*].Instances[*].PublicIpAddress' \
            --output text
            )
            R53_RECORD="$DOMAIN_NAME"
            else
                IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
                --query 'Reservations[*].Instances[*].PrivateIpAddress' \
                --output text
                )
                R53_RECORD="$instance.$DOMAIN_NAME"
            fi

            aws route53 change-resource-record-sets \
                --hosted-zone-id $ZONE_ID \
                --change-batch '
                    {
                        "Comment": "Updating the A record for the subdomain",
                        "Changes": [
                                {
                                "Action": "UPSERT",
                                "ResourceRecordSet": {
                                    "Name": "'$R53_RECORD'",
                                    "Type": "A",
                                    "TTL": 1,
                                    "ResourceRecords": [
                                        {
                                            "Value": "'$IP'"
                                        }
                                    ]
                                }
                            }
                        ]
                    }
                '
                echo "Updated Route53 record for: $instance"
        else
            echo "roboshop-$instance already running: $INSTANCE_ID"
        fi

        #if already instance running, again we are updating the route53 records
        if [ $instance == "frontend" ]; then
            IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
            --query 'Reservations[*].Instances[*].PublicIpAddress' \
            --output text
            )
            R53_RECORD="$DOMAIN_NAME"
            else
                IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
                --query 'Reservations[*].Instances[*].PrivateIpAddress' \
                --output text
                )
                R53_RECORD="$instance.$DOMAIN_NAME"
            fi

            aws route53 change-resource-record-sets \
                --hosted-zone-id $ZONE_ID \
                --change-batch '
                    {
                        "Comment": "Updating the A record for the subdomain",
                        "Changes": [
                                {
                                "Action": "UPSERT",
                                "ResourceRecordSet": {
                                    "Name": "'$R53_RECORD'",
                                    "Type": "A",
                                    "TTL": 1,
                                    "ResourceRecords": [
                                        {
                                            "Value": "'$IP'"
                                        }
                                    ]
                                }
                            }
                        ]
                    }
                '
            echo "Updated Route53 record for existing: $instance"
        else
            if [ "$INSTANCE_ID" == "None" ]; then
                echo "$instance already destroyed, nothing to do..."
            else
                aws ec2 terminate-instances --instance-ids $INSTANCE_ID
                echo "Terminating instance: $instance
    fi
done
