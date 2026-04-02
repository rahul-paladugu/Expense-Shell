#!/bin/bash

GREEN='\e[32m'
RED='\e[31m'
NC='\e[0m'   # No Color (reset)
start_time=$(date +%s)
#Check root access for the admin tasks
root=$(id -u)
if [ $root -ne 0 ]; then
  echo -e "${RED}Please run the script with root privileges.${NC}"
  exit 1
else
  echo -e "${GREEN}Root access verified. Proceeding with the script...${NC}"
fi

#Logs Creation
mkdir -p /var/log/expense
log_file="/var/log/expense/mysql_configuration.log"

#Exit on an error
error_validation() {
    if [ $? -ne 0 ]; then
      echo -e "${RED}Error performing $1. Please review the logs.${NC}"
      exit 1
    else
      echo -e "${GREEN}$1 is success.${NC}"
    fi
}

#Install mysql server
sudo dnf install mysql-server -y &>> $log_file
error_validation "MySQL server installation"
sudo systemctl start mysqld &>> $log_file
error_validation "Start MySQL server service"
sudo systemctl enable mysqld &>> $log_file
error_validation "Enable MySQL server service"

#Configure mysql server
sudo mysql_secure_installation --set-root-pass ExpenseApp@1 &>> $log_file
error_validation "Set admin password for MySQL server"
end_time=$(date +%s)
echo -e "${GREEN}MySQL server installation and configuration is completed successfully in $(($end_time - $start_time)) Seconds.${NC}"