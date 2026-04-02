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

#Frontend Configuration
sudo dnf install nginx -y &>>$log_file
error_validation "Install Nginx"
sudo systemctl enable nginx &>>$log_file
error_validation "Enable Nginx service"
sudo systemctl start nginx &>>$log_file
error_validation "Start nginx service"
rm -rf /usr/share/nginx/html/*
error_validation "Remove default nginx content"
curl -o /tmp/frontend.zip https://expense-joindevops.s3.us-east-1.amazonaws.com/expense-frontend-v2.zip &>>$log_file
cd /usr/share/nginx/html
error_validation "change to html directory"
unzip /tmp/frontend.zip &>>$log_file
error_validation "Unzip code"
cp /home/ec2-user/Expense-Shell-Script/expense.conf /etc/nginx/default.d/expense.conf
error_validation "copy expense-config"
sudo systemctl restart nginx
error_validation "Restart Nginx"
end_time=$(date +%s)
echo -e "{$GREEN}Frontend configuration is successfully completed in $(($end_time - $start_time)) Seconds.{$NC}"