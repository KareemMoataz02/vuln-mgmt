# Vulnerability Management Lab

A comprehensive, automated vulnerability management lab environment deployed on Azure using Terraform. This project provides a sandbox for security professionals to practice scanning, detection, and remediation of vulnerabilities across various operating systems and web applications.

![Architecture Diagram](./images/architecture.png)

## Overview

This lab environment consists of several key components designed to simulate a realistic corporate network with integrated security controls.

### 🛡️ Vulnerability Scanners

The lab features two complementary vulnerability scanning tools:

#### OpenVAS (Greenbone Vulnerability Management)
- **Deployment**: Automated via `cloud-init` on Ubuntu 22.04.
- **Architecture**: Runs as a multi-container Docker application (`gvmd`, `gsa`, `ospd-openvas`).
- **Functionality**: Performs authenticated and unauthenticated network-level scans across the internal network.
- **Web UI**: Accessible at `https://<openvas-ip>:9392` (default credentials: `admin` / `admin`).

#### OWASP ZAP (Zed Attack Proxy)
- **Deployment**: Runs as a Docker container on the same VM as OpenVAS.
- **Architecture**: Containerized ZAP daemon with API and web UI exposed on port 8080.
- **Functionality**: Specialized web application security scanner for finding vulnerabilities in web apps.
- **Target**: Pre-configured to scan OWASP Juice Shop at `http://10.10.2.4:3000`.
- **API Access**: `http://localhost:8080` (API key: `zapkey123`).
- **Scan Reports**: Stored in `/opt/zap-data/` on the scanner VM.
- **Automated Scanning**: Runs a baseline scan on startup and can be triggered via API.

### 🎯 Target Systems
The lab includes diverse targets to test different attack vectors:
- **Linux Server**: A standard Ubuntu instance used for auditing OS vulnerabilities and testing Syslog-based detection.
- **Windows Server**: A Windows Server 2022 instance with:
    - **Audit Policies**: Pre-configured for deep visibility into process execution and login events.
    - **Attack Simulation**: Includes a custom PowerShell script that simulates "bad behavior" (e.g., suspicious process execution, failed logon spikes) to trigger SIEM alerts.
- **Web Applications**: Dockerized versions of **OWASP Juice Shop** and **DVWA** (Damn Vulnerable Web Application) for web-specific vulnerability assessment.

### 🔍 Monitoring & SIEM (Sentinel)
A robust monitoring stack is deployed to provide real-time visibility and incident response capabilities:
- **Microsoft Sentinel**: The primary SIEM, pre-configured with **Scheduled Analytics Rules**:
    - `SOC Lab - SSH brute force attempts`: Detects repeated failed SSH logins.
    - `SOC Lab - New local user created`: Identifies unauthorized user additions.
    - `SOC Lab - NSG deny spike`: Monitors firewall logs for potential port scanning or lateral movement.
- **Defender for Cloud**: Configured with the **Standard (StandardSSD_LRS)** pricing tier for Virtual Machines to provide enhanced threat protection and vulnerability assessment.
- **Azure Monitor Agent (AMA)**: Installed on all VMs to stream security events and Syslog data to a central **Log Analytics Workspace**.

## Architecture

The lab is isolated within an Azure Resource Group and follows best practices for secure network segmentation:
- **Management Subnet**: Houses the **Azure Bastion** service for secure, browser-based RDP/SSH access without public IP exposure.
- **Security Subnet**: Isolated subnet for the OpenVAS scanner with controlled access to the target environment.
- **Targets Subnet**: Contains vulnerable systems, isolated from the management plane but reachable by the scanner and monitoring agents.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) v1.0+
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- An active Azure Subscription

## Getting Started

1. **Clone the repository**:
   ```bash
   git clone https://github.com/KareemMoataz02/vuln-mgmt.git
   cd vuln-mgmt
   ```

2. **Login to Azure**:
   ```bash
   az login
   ```

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Plan the deployment**:
   ```bash
   terraform plan
   ```

5. **Apply the configuration**:
   ```bash
   terraform apply
   ```

## Included Modules

- **Network**: Defines the VNet, Subnets, and Network Security Groups (NSGs).
- **Bastion**: Deploys Azure Bastion for secure management.
## Testing the Lab

Follow these steps to verify your lab environment is fully functional:

### 1. Verify Deployment
Once `terraform apply` completes, verify the outputs:
```bash
terraform output
```
Note the private IPs for the `openvas`, `linux_target`, and `windows_target`.

### 2. Access the Environment
Secure access is provided via **Azure Bastion**.
- **Web Access**: Navigate to the Azure Portal, select a VM (e.g., `openvas`), and click **Connect > Bastion**.
- **CLI Access**:
  ```bash
  az network bastion ssh --name <bastion_name> --resource-group <rg_name> --target-resource-id <vm_id> --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/id_rsa
  ```

### 3. Vulnerability Scanning (OpenVAS)
1. Connect to the **OpenVAS VM** via Bastion.
2. The scanner web UI is available at `https://<openvas_private_ip>:9392`.
   - *Note: Since this is an internal IP, you may need a SOCKS proxy via SSH or access from another VM in the VNet.*
3. **Login**: Default credentials are `admin` / `admin`.
4. **Run a Scan**:
   - Go to **Scans > Tasks**.
   - Use the **Task Wizard** (magic wand icon).
   - Enter the Targets subnet range (e.g., `10.0.2.0/24`) and click **Start Scan**.

### 4. Web Application Scanning (OWASP ZAP)
1. Connect to the **OpenVAS VM** via Bastion (same VM hosts both scanners).
2. **Verify ZAP is running**:
   ```bash
   docker ps | grep zap-scanner
   docker logs zap-scanner
   ```
3. **Check the automated baseline scan results**:
   ```bash
   ls -la /opt/zap-data/
   cat /opt/zap-data/baseline-report.md
   ```
4. **Run a manual scan via ZAP API**:
   ```bash
   # Check ZAP version/status
   curl -s http://localhost:8080/JSON/core/view/version/
   
   # Spider the target (crawl to discover URLs)
   SCAN_ID=$(curl -s "http://localhost:8080/JSON/spider/action/scan/?url=http://10.10.2.4:3000&apikey=zapkey123" | grep -oP '(?<="scan":")[^"]*')
   
   # Check spider status (wait until progress reaches 100)
   curl -s "http://localhost:8080/JSON/spider/view/status/?scanId=$SCAN_ID&apikey=zapkey123"
   
   # Run active scan (this may take several minutes)
   curl -s "http://localhost:8080/JSON/ascan/action/scan/?url=http://10.10.2.4:3000&apikey=zapkey123"
   
   # Generate HTML report
   curl -s "http://localhost:8080/OTHER/core/other/htmlreport/?apikey=zapkey123" > /opt/zap-data/full-scan-report.html
   ```
5. **Access ZAP Web UI** (optional):
   - Set up an SSH tunnel from your local machine:
     ```bash
     az network bastion tunnel --name <bastion_name> --resource-group <rg_name> \
       --target-resource-id <openvas_vm_id> --resource-port 8080 --port 8080
     ```
   - Open your browser to `http://localhost:8080/zap/`

### 5. Trigger SIEM Alerts (Microsoft Sentinel)

Test the detection rules by simulating attacks:
- **SSH Brute Force**: From the OpenVAS VM (or any other VM in the VNet), attempt to SSH into the Linux Target multiple times with a wrong password:
  ```bash
  for i in {1..10}; do ssh adminuser@<linux_target_ip>; done
  ```
- **Windows Attack Simulation**: The Windows VM automatically runs a simulation script on startup. You can manually trigger it via the Custom Script Extension or by manually failing several RDP logins.
- **Verification**:
  1. In the Azure Portal, go to **Microsoft Sentinel**.
  2. Select your workspace and click on **Incidents**.
  3. You should see alerts like `SOC Lab - SSH brute force attempts` or `SOC Lab - NSG deny spike` within 5-15 minutes.

## CI/CD Pipeline

This project is configured with a GitHub Actions pipeline (`.github/workflows/terraform.yml`) that automates Terraform operations and security scanning.

### Pipeline Workflow
1. **Trigger**: Push to `main` or Pull Requests.
2. **Security Scan**: Runs `tfsec` to catch security misconfigurations.
3. **Terraform**:
   - `terraform init`
   - `terraform validate`
   - `terraform plan`
   - `terraform apply` (Only on `push` to `main` if all checks pass)

### Required GitHub Secrets
To use the pipeline, you must configure the following **Repository Secrets** in GitHub:

**Azure Authentication:**
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`

**Terraform Variables:**
- `ADMIN_PUBLIC_KEY` - Your SSH public key for Linux VMs

**Remote Backend (State Storage):**
- `BACKEND_STORAGE_ACCOUNT` - Created by `scripts/create-backend.sh`
- `BACKEND_ACCESS_KEY` - Created by `scripts/create-backend.sh`

### Setting Up Remote Backend

The pipeline uses Azure Storage to persist Terraform state across runs. To set this up:

1. **Run the bootstrap script**:
   ```bash
   ./scripts/create-backend.sh
   ```
   This creates a storage account and container for state files.

2. **Add the secrets**: The script outputs two values that you need to add to GitHub Secrets:
   - `BACKEND_STORAGE_ACCOUNT`
   - `BACKEND_ACCESS_KEY`

3. **Commit and push**: The pipeline will automatically use the remote backend on the next run.

