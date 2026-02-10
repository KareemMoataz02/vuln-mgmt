# Vulnerability Management Lab

A comprehensive, automated vulnerability management lab environment deployed on Azure using Terraform. This project provides a sandbox for security professionals to practice scanning, detection, and remediation of vulnerabilities across various operating systems and web applications.

![Architecture Diagram](./images/architecture.png)

## Overview

This lab environment consists of several key components designed to simulate a realistic corporate network:

- **Network Infrastructure**: A secure Virtual Network (VNet) with dedicated subnets for scanning tools, target systems, and management access.
- **Vulnerability Scanner**: A pre-configured **OpenVAS** instance located in the Security subnet.
- **Target Systems**:
  - **Linux Server**: Standard Ubuntu instance for OS-level vulnerability scanning.
  - **Windows Server**: Windows Server instance for active directory and OS vulnerability testing.
  - **DVWA & Juice Shop**: Vulnerable web applications hosted as Docker containers for web-specific security testing.
- **Monitoring & SIEM**: Integrated **Microsoft Sentinel**, **Defender for Cloud**, and **Log Analytics** for real-time monitoring and incident response.

## Architecture

The lab is isolated within an Azure Resource Group and follows best practices for secure network segmentation:

- **Management Subnet**: Houses the Azure Bastion service for secure, RDP/SSH access without exposure to the public internet.
- **Security Subnet**: contains the OpenVAS scanner, which has internal access to the Targets subnet.
- **Targets Subnet**: Contains various vulnerable systems, shielded from direct internet access.

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
- **Scanner**: Provisions the OpenVAS scanning engine.
- **Targets**: Deploys vulnerable Linux, Windows, and Web App VMs.
- **Monitoring**: Sets up Sentinel and Defender for Cloud dashboarding.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
