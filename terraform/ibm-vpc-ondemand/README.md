# IBM VPC On-Demand VSI Automation

**Purpose**: Provision and destroy IBM Cloud VPC Virtual Server Instances on-demand using Terraform (via Docker) and n8n workflows.

## 📋 Overview

This setup allows you to:
- **Spin up** an IBM VPC VSI with Docker pre-installed (via cloud-init)
- **Tear down** all resources to stop hourly billing
- **Automate** via n8n workflows (no Terraform installation required)

**Cost Optimization**: Only pay for compute time when you need it!

---

## 🏗️ Architecture

### Resources Created:
- **VPC**: `n8n-lab-vpc`
- **Subnet**: `10.240.0.0/24` in `us-south-1`
- **Security Group**: SSH (22) inbound, all outbound
- **Public Gateway**: For internet access
- **VSI**: Ubuntu 22.04 minimal (cx2-2x4: 2 vCPU, 4 GB RAM)
- **Floating IP**: Public IP address for SSH access

### Auto-Configuration:
- Docker CE installed via cloud-init
- User `ubuntu` added to docker group
- Ready for containers ~2-3 minutes after provisioning

---

## 📁 Files

```
/home/clay/Documents/GitHub/n8n.mcp/terraform/ibm-vpc-ondemand/
├── main.tf              # Terraform configuration
├── variables.tf         # Variable definitions
├── providers.tf         # IBM Cloud provider setup
├── terraform.tfvars     # Your credentials (gitignored)
└── README.md            # This file
```

---

## 🚀 Usage

### Option 1: n8n Workflows (Recommended)

#### Spin Up VSI:
1. Open n8n: http://localhost:5678
2. Import workflow: `/workflows/examples/ibm-vpc-vsi-spin-up.json`
3. Click "Execute Workflow"
4. Wait 3-5 minutes
5. Get output with public IP and SSH command

#### Tear Down VSI:
1. Import workflow: `/workflows/examples/ibm-vpc-vsi-tear-down.json`
2. Click "Execute Workflow"
3. Wait 2-3 minutes
4. Resources deleted, billing stopped

---

### Option 2: Manual Docker Commands

```bash
cd /home/clay/Documents/GitHub/n8n.mcp/terraform/ibm-vpc-ondemand

# Initialize
docker run --rm -v $(pwd):/workspace -w /workspace hashicorp/terraform:latest init

# Plan
docker run --rm -v $(pwd):/workspace -w /workspace hashicorp/terraform:latest plan

# Apply
docker run --rm -v $(pwd):/workspace -w /workspace hashicorp/terraform:latest apply -auto-approve

# Get outputs
docker run --rm -v $(pwd):/workspace -w /workspace hashicorp/terraform:latest output

# Destroy
docker run --rm -v $(pwd):/workspace -w /workspace hashicorp/terraform:latest destroy -auto-approve
```

---

## 🔑 Prerequisites

### 1. IBM Cloud Setup

- **IBM Cloud account** with VPC infrastructure access
- **API Key**: Already configured in `terraform.tfvars`
- **SSH Key**: Must exist in IBM Cloud named `ibm-lab-key`
  - Upload your public key: https://cloud.ibm.com/vpc-ext/compute/sshKeys

### 2. Local Setup

- **Docker**: Already installed
- **n8n**: Running at http://localhost:5678
- **SSH Key**: `/home/clay/Documents/Security/ibm_cloud_vsi_key`

---

## 📊 Configuration

Edit `terraform.tfvars` to customize:

```hcl
ibm_region       = "us-south"          # Change region if needed
instance_profile = "cx2-2x4"           # Change instance size
instance_name    = "n8n-lab-vsi-ondemand"
```

Available profiles:
- `cx2-2x4`: 2 vCPU, 4 GB RAM (~$0.10/hour)
- `cx2-4x8`: 4 vCPU, 8 GB RAM (~$0.20/hour)
- `cx2-8x16`: 8 vCPU, 16 GB RAM (~$0.40/hour)

---

## 🧪 Testing

After spin-up, test the VSI:

```bash
# Get the public IP from terraform output
ssh -i /home/clay/Documents/Security/ibm_cloud_vsi_key ubuntu@<PUBLIC_IP>

# Verify Docker
docker --version
docker ps
```

---

## 🛠️ Troubleshooting

### SSH Key Not Found
```
Error: SSH key 'ibm-lab-key' not found
```
**Solution**: Upload your SSH key to IBM Cloud:
1. Go to: https://cloud.ibm.com/vpc-ext/compute/sshKeys
2. Click "Create +"
3. Name: `ibm-lab-key`
4. Paste contents of: `/home/clay/Documents/Security/ibm_cloud_vsi_key.pub`

### Permission Denied
```
Error: docker: permission denied
```
**Solution**: Add current user to docker group:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Region Issues
```
Error: VPC not available in region
```
**Solution**: Check available regions at https://cloud.ibm.com/docs/overview?topic=overview-locations

---

## 💰 Cost Management

### Hourly Billing:
- **VSI (cx2-2x4)**: ~$0.095/hour
- **Floating IP**: ~$0.004/hour
- **Data Transfer**: First 5GB free, then ~$0.09/GB

### Best Practices:
1. **Tear down** when not in use (run destroy workflow)
2. **Schedule** spin-up/tear-down with n8n cron triggers
3. **Monitor** costs: https://cloud.ibm.com/billing

---

## 🔄 Migration from Classic Infrastructure

Your current Classic VSI (169.48.107.199) is separate. To migrate:

1. **Backup** data from Classic VSI
2. **Spin up** new VPC VSI with this Terraform
3. **Restore** data to new VSI
4. **Update** n8n workflows to use new IP
5. **Delete** Classic VSI manually (different API)

---

## 📚 Resources

- **IBM VPC Docs**: https://cloud.ibm.com/docs/vpc
- **Terraform IBM Provider**: https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs
- **n8n Docs**: https://docs.n8n.io

---

## ✅ Next Steps

1. ✅ Import n8n workflows
2. ⬜ Test spin-up workflow
3. ⬜ SSH into new VSI and verify Docker
4. ⬜ Test tear-down workflow
5. ⬜ Create scheduled workflows (optional)
6. ⬜ Migrate workloads from Classic VSI (optional)

---

**Created**: 2025-12-08
**Status**: Ready for testing
**Lab**: n8n + Terraform Multi-Cloud Automation
