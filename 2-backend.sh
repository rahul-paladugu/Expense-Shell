#!/bin/bash
GREEN='\e[32m'
RED='\e[31m'
NC='\e[0m'   # No Color (reset)
start_time=$(date +%s)
# Check root access for the admin tasks
root=$(id -u)
if [ $root -ne 0 ]; then
  echo -e "${RED}Please run the script with root privileges.${NC}"
  exit 1
else
  echo -e "${GREEN}Root access verified. Proceeding with the script...${NC}"
fi

# Error validator
error_validation() {
    if [ $? -ne 0 ]; then
      echo -e "${RED}Error performing $1. Please review the logs.${NC}"
      exit 1
    else
      echo -e "${GREEN}$1 is success.${NC}"
    fi
}
#Logs Creation
mkdir -p /var/log/expense
log_file="/var/log/expense/backend_configuration.log"
error_validation "logs creation"

# Backend configuration
sudo dnf module disable nodejs -y &>>$log_file
error_validation "Disable default version of NodeJS"
sudo dnf module enable nodejs:20 -y &>> $log_file
error_validation "Enable code specific version of NodeJS"
sudo dnf install nodejs -y &>> $log_file
error_validation "NodeJS installation"

# Service user creation
sudo useradd expense
error_validation "Service user creation"

#Code deployment
mkdir -p /app
error_validation "App directory creation"
curl -o /tmp/backend.zip https://expense-joindevops.s3.us-east-1.amazonaws.com/expense-backend-v2.zip &>>$log_file
error_validation "Code download"
cd /app
error_validation "Change directory to /app"
sudo unzip /tmp/backend.zip &>> $log_file
error_validation "Code unzip"
cd /app
error_validation "Change directory to /app"
npm install &>>$log_file
error_validation "NodeJS dependencies installation"
cp /home/ec2-user/Expense-Shell-Script/backend.service /etc/systemd/system/backend.service
error_validation "Service file copy"
sudo systemctl daemon-reload &>> $log_file
error_validation "Daemon reload"
sudo systemctl start backend &>> $log_file
error_validation "Start backend service"
sudo systemctl enable backend &>> $log_file
error_validation "Enable backend service"

#Load schema to mysql
sudo dnf install mysql -y &>> $log_file
error_validation "MySQL client installation"
mysql -h mysql.rscloudservices.icu -uroot -pExpenseApp@1 < /app/schema/backend.sql &>>$log_file
error_validation "Schema loading"
sudo systemctl restart backend
end_time=$(date +%s)
echo -e "${GREEN}Backend configuration completed successfully in $(($end_time - $start_time)) seconds.${NC}"