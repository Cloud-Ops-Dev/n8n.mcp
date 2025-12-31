#!/bin/bash
#===============================================================================
# Build AWS Redis AMI
#===============================================================================
#
# DESCRIPTION:
#   Builds an AWS AMI with Docker and Redis pre-installed for the message
#   queue demo. Uses Packer with the Amazon EBS builder.
#
# PREREQUISITES:
#   - Packer installed (https://www.packer.io/downloads)
#   - AWS credentials configured in variables.pkrvars.hcl
#
# USAGE:
#   ./build.sh
#
#===============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==============================================================================="
echo "  Building AWS Redis AMI (Option C: Hybrid)"
echo "==============================================================================="

# Check for variables file
if [ ! -f "variables.pkrvars.hcl" ]; then
    echo ""
    echo "ERROR: variables.pkrvars.hcl not found!"
    echo ""
    echo "Create it from the example:"
    echo "  cp variables.pkrvars.hcl.example variables.pkrvars.hcl"
    echo ""
    echo "Then edit with your AWS credentials."
    exit 1
fi

# Check for Packer
if ! command -v packer &> /dev/null; then
    echo ""
    echo "ERROR: Packer not found!"
    echo ""
    echo "Install Packer: https://www.packer.io/downloads"
    echo "Or via Docker: docker run -it hashicorp/packer:latest"
    exit 1
fi

echo ""
echo "[1/3] Initializing Packer plugins..."
packer init redis-ami.pkr.hcl

echo ""
echo "[2/3] Validating template..."
packer validate -var-file=variables.pkrvars.hcl redis-ami.pkr.hcl

echo ""
echo "[3/3] Building AMI..."
packer build -var-file=variables.pkrvars.hcl redis-ami.pkr.hcl

echo ""
echo "==============================================================================="
echo "  Build Complete!"
echo "==============================================================================="
echo ""
echo "The AMI ID will be displayed above. Update your terraform.tfvars with this ID:"
echo "  ami_id = \"ami-xxxxxxxxxxxxxxxxx\""
echo ""
echo "Location: terraform/aws-ec2-ondemand/terraform.tfvars"
echo ""
echo "==============================================================================="
