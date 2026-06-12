#!bin/bash

LOG_FOLDER='/var/log/roboshop'

sudo mkdir -p $LOG_FOLDER

sudo chown -R ec2-user:ec2-user $LOG_FOLDER

sudo chmod -R 755 $LOG_FOLDER

LOG_FILE="/$LOG_FOLDER/$0.log"

SCRIPT_DIR=$PWD

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

dnf module disable nodejs -y &>> $LOG_FILE
dnf module enable nodejs:20 -y &>> $LOG_FILE
dnf  install nodejs -y -y &>> $LOG_FILE
VALIDATE $? "Installing nodejs:20"

id roboshop &>> $LOG_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE
    VALIDATE $? "Creating roboshop system user"
else
    echo -e "$R User Already present with this name $N ... $Y SKIPPING $N"
fi

rm -rf /app
VALIDATE $? "Removing Existing app/code"

rm -rf /tmp/user.zip
VALIDATE $? "Removing Exisiting user"

mkdir -p /app &>> $LOG_FILE
VALIDATE $? "Creating app folder for code"

curl -o /tmp/user.zip https://roboshop-artifacts.s3.amazonaws.com/user-v3.zip  &>>$LOG_FILE
cd /app
unzip /tmp/user.zip &>>$LOG_FILE
VALIDATE $? "Unzipping the user code"

npm install &>> $LOG_FILE
VALIDATE $? "Installing npm dependencies"


cp $SCRIPT_DIR/user.service /etc/systemd/system/user.service
VALIDATE $? "Creating systemctl service"

systemctl enable user
systemctl restart user
VALIDATE $? "Enabling and restarting user"

