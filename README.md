# 💸 Expense-Shell-Script

> Production-grade Bash scripts to provision AWS infrastructure and deploy the **Expense Tracker** application — from EC2 instance creation and Route 53 DNS registration, through to database setup, backend runtime, and Nginx frontend — fully automated, one script per layer.

---

## 📌 Overview

This repository automates the complete deployment of the Expense Tracker application on AWS EC2 (RHEL/Rocky Linux 8). Each numbered script handles one layer of the stack and follows a consistent pattern: root validation, structured logging, colour-coded output, and per-step error checking via a shared `error_validation()` function.

| Layer | Technology | DNS Record | IP Type |
|---|---|---|---|
| Database | MySQL 8 | `mysql.rscloudservices.icu` | Private |
| Backend | Node.js 20 + Express (port 8080) | `backend.rscloudservices.icu` | Private |
| Frontend | Nginx (reverse proxy) | `expense.rscloudservices.icu` | **Public** |

---

## 🏗️ Architecture

```
  User Browser
       │
       │ HTTP → expense.rscloudservices.icu (Public IP)
       ▼
┌──────────────────────────┐
│   Frontend  (Nginx)      │   /api/* ──────────────────────────────┐
│   3-frontend.sh          │   proxied to localhost:8080             │
└──────────────────────────┘                                         │
                                                                     ▼
                                                    ┌────────────────────────────┐
                                                    │  Backend  (Node.js 20)     │
                                                    │  2-backend.sh              │
                                                    │  Listens on :8080          │
                                                    └─────────────┬──────────────┘
                                                                  │ Private IP
                                                                  ▼
                                                    ┌────────────────────────────┐
                                                    │  Database  (MySQL 8)       │
                                                    │  1-mysql.sh                │
                                                    │  mysql.rscloudservices.icu │
                                                    └────────────────────────────┘
```

---

## ✅ Prerequisites

### On your local machine (for `0-instances.sh`)
- AWS CLI v2 installed and configured (`aws configure`)
- IAM permissions: `ec2:RunInstances`, `ec2:DescribeInstances`, `route53:ChangeResourceRecordSets`

### On each target EC2 server (for scripts 1–3)
- OS: **RHEL 8 / Rocky Linux 8**
- Root or sudo access
- Outbound internet access for package downloads from `dnf` and AWS S3
- Repo cloned to `/home/ec2-user/Expense-Shell-Script/` — scripts reference this path for `backend.service` and `expense.conf`

---

## 🚀 Deployment Order

> ⚠️ Scripts **must** be executed in this exact order. Each layer depends on the one beneath it.

| Step | Script | Runs On | Purpose |
|---|---|---|---|
| 0 | `0-instances.sh` | Local machine | Provision EC2 instances + Route 53 DNS |
| 1 | `1-mysql.sh` | MySQL EC2 instance | Install & configure MySQL 8 |
| 2 | `2-backend.sh` | Backend EC2 instance | Deploy Node.js 20 backend as a systemd service |
| 3 | `3-frontend.sh` | Frontend EC2 instance | Deploy Nginx + frontend app + reverse proxy config |

---

## 📜 Scripts Reference

### `0-instances.sh` — AWS Infrastructure Provisioning

Prompts for a space-separated list of instance names, creates `t3.micro` EC2 instances, and registers Route 53 A records automatically.

**AWS configuration baked in:**
```
AMI:            ami-0220d79f3f480ecf5
Instance type:  t3.micro
Security Group: sg-0ce5a2e10ef96202d
Region:         us-east-1
Hosted Zone:    Z050001923LY47PA0PTIR
Domain:         rscloudservices.icu
```

**DNS assignment logic:**
- Instance named `frontend` → **Public IP** → `expense.rscloudservices.icu`
- All other instances → **Private IP** → `<instance-name>.rscloudservices.icu`

**Usage:**
```bash
bash 0-instances.sh
# When prompted enter: mysql backend frontend
```

---

### `1-mysql.sh` — MySQL 8 Installation & Configuration

Installs MySQL server, starts and enables the `mysqld` service, and secures the root account.

**Steps executed:**
1. Root access check
2. Creates log directory `/var/log/expense/`
3. Installs `mysql-server` via `dnf`
4. Starts and enables `mysqld` systemd service
5. Runs `mysql_secure_installation --set-root-pass ExpenseApp@1`

**Log file:** `/var/log/expense/mysql_configuration.log`

**Usage:**
```bash
# SSH into the MySQL EC2 instance, then:
bash 1-mysql.sh
```

---

### `2-backend.sh` — Node.js Backend Deployment

Installs Node.js 20, deploys the Expense backend application, loads the MySQL schema, and manages the process via systemd.

**Steps executed:**
1. Root access check
2. Creates log directory `/var/log/expense/`
3. Disables default system NodeJS module
4. Enables and installs **Node.js 20** via `dnf module enable nodejs:20`
5. Creates dedicated system user `expense`
6. Creates `/app` directory
7. Downloads backend release from S3:
   ```
   https://expense-joindevops.s3.us-east-1.amazonaws.com/expense-backend-v2.zip
   ```
8. Unzips to `/app` and runs `npm install`
9. Copies `backend.service` → `/etc/systemd/system/backend.service`
10. Reloads systemd daemon, starts and enables `backend` service
11. Installs `mysql` client package
12. Loads DB schema into MySQL:
    ```bash
    mysql -h mysql.rscloudservices.icu -uroot -pExpenseApp@1 < /app/schema/backend.sql
    ```
13. Restarts backend service to apply schema changes

**Log file:** `/var/log/expense/backend_configuration.log`

**Usage:**
```bash
# SSH into the Backend EC2 instance, then:
bash 2-backend.sh
```

---

### `3-frontend.sh` — Nginx Frontend Deployment

Installs Nginx, deploys the frontend static assets, and drops in the reverse proxy config to route API calls to the backend.

**Steps executed:**
1. Root access check
2. Creates log directory `/var/log/expense/`
3. Installs, enables, and starts `nginx`
4. Removes default Nginx content from `/usr/share/nginx/html/`
5. Downloads frontend release from S3:
   ```
   https://expense-joindevops.s3.us-east-1.amazonaws.com/expense-frontend-v2.zip
   ```
6. Unzips frontend assets to `/usr/share/nginx/html/`
7. Copies `expense.conf` → `/etc/nginx/default.d/expense.conf`
8. Restarts Nginx to apply the new configuration

**Log file:** `/var/log/expense/backend_configuration.log`

**Usage:**
```bash
# SSH into the Frontend EC2 instance, then:
bash 3-frontend.sh
```

---

## 🔧 Configuration Files

### `backend.service`
Systemd unit file that manages the Node.js backend process lifecycle. Copied to `/etc/systemd/system/backend.service` by `2-backend.sh`.

### `expense.conf`
Nginx location block config, dropped into `/etc/nginx/default.d/` by `3-frontend.sh`. Handles two routes:

```nginx
proxy_http_version 1.1;

# Proxy all API calls to the Node.js backend
location /api/ { proxy_pass http://localhost:8080/; }

# Health check endpoint
location /health {
    stub_status on;
    access_log off;
}
```

---

## 🎨 Script Design Standards

All scripts share a consistent engineering pattern:

**Colour-coded terminal output**
```
🟢 GREEN  → Step succeeded
🔴 RED    → Step failed — script exits immediately
```

**`error_validation()` — called after every significant command**
```bash
error_validation() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error performing $1. Please review the logs.${NC}"
        exit 1
    else
        echo -e "${GREEN}$1 is success.${NC}"
    fi
}
```

**Structured logging** — keeps terminal clean, full output in log file
```bash
dnf install nodejs -y &>> $log_file
error_validation "NodeJS installation"
```

**Root access guard** — first thing every script checks
```bash
if [ $(id -u) -ne 0 ]; then
    echo -e "${RED}Please run the script with root privileges.${NC}"
    exit 1
fi
```

**Execution timer** — reports total time taken at the end
```bash
start_time=$(date +%s)
# ... all work ...
end_time=$(date +%s)
echo "Completed in $(( end_time - start_time )) seconds."
```

---

## 📂 Repository Structure

```
Expense-Shell-Script/
├── 0-instances.sh      # AWS EC2 provisioning + Route 53 DNS registration
├── 1-mysql.sh          # MySQL 8 installation & root password configuration
├── 2-backend.sh        # Node.js 20 backend deployment + DB schema loading
├── 3-frontend.sh       # Nginx + frontend assets + reverse proxy config
├── backend.service     # systemd unit for the Node.js backend process
└── expense.conf        # Nginx location config — API proxy + health endpoint
```

---

## 📋 Log Files on Target Servers

```
/var/log/expense/
├── mysql_configuration.log      # All output from 1-mysql.sh
└── backend_configuration.log    # All output from 2-backend.sh and 3-frontend.sh
```

Tail logs live during a deployment:
```bash
tail -f /var/log/expense/backend_configuration.log
```

---

## 🔐 Security Considerations

> The defaults below are suitable for development/demo. Review before production use.

- MySQL root password is hardcoded as `ExpenseApp@1` — **rotate this before production**
- The backend runs under a dedicated non-root `expense` system user — correct practice
- Only the **frontend instance has a public IP** — backend and database are on private IPs only
- Route 53 TTL is set to `1` second for fast initial propagation — **raise to 300+** in production
- Review inbound rules on security group `sg-0ce5a2e10ef96202d` to enforce least-privilege access

---

## 🛣️ Roadmap

- [ ] Replace `0-instances.sh` with **Terraform** for declarative, version-controlled infrastructure
- [ ] Migrate scripts 1–3 to **Ansible** playbooks for idempotent, reusable configuration management
- [ ] Add **GitHub Actions** pipeline for automated, triggered deployments
- [ ] Add **HTTPS** via Let's Encrypt or AWS ACM + Application Load Balancer
- [ ] Move hardcoded secrets (DB password) to **AWS Secrets Manager**
- [ ] Add a teardown script to cleanly terminate instances and remove DNS records

---

## 📄 License

This project is intended for learning and demonstration purposes.
