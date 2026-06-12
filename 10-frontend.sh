#!bin/bash

LOG_FOLDER='/var/log/roboshop'

sudo mkdir -p $LOG_FOLDER

sudo chown -R ec2-user:ec2-user $LOG_FOLDER

sudo chmod -R 755 $LOG_FOLDER

LOG_FILE="/$LOG_FOLDER/$0.log"

SCRIPT_DIR=$PWD

MYSQL_HOST=mysql.learndevopskills.shop

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S" )

USER_ID=$(id -u)

if [ $USER_ID -ne 0 ]; then
    echo -e "$TIMESTAMP [ERROR] $R Please access with admin user $N" | tee -a $LOG_FILE
    exit 1
fi

VALIDATE(){
    if [ $1 -ne 0 ]; then
        echo -e "$TIMESTAMP [ERROR] $2 ... $R FAILURE $N" | tee -a $LOG_FILE
    else
        echo -e "$TIMESTAMP [INFO] $2 ... $G SUCCESS $N" | tee -a $LOG_FILE
    fi
}

dnf module disable nginx -y &>> LOG_FILE
dnf module enable nginx:1.24 -y &>> LOG_FILE
dnf install nginx -y &>> LOG_FILE
VALIDATE $? "Installing nginx"

rm -rf /usr/share/nginx/html/* &>> $LOG_FILE
VALIDATE $? "Removed Default code"

curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip &>> $LOG_FILE
cd /usr/share/nginx/html 
unzip /tmp/frontend.zip &>> $LOG_FILE
VALIDATE $? "Downloaded and extracted frontend code"

rm -rf /etc/nginx/nginx.conf
VALIDATE $? "Removed Default conf"

cp $SCRIPT_DIR/nginx.conf /etc/nginx/nginx.conf
VALIDATE $? "Copied roboshop nginx conf"

systemctl restart nginx
systemctl enable nginx &>> $LOG_FILE
VALIDATE $? "Enabled and restarted nginx"
