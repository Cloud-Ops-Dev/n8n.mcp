#!/bin/bash
#===============================================================================
# Build IBM Cloud Producer Custom Image
#===============================================================================
#
# DESCRIPTION:
#   Builds an IBM Cloud custom image with Docker and the Producer app
#   pre-installed for the message queue demo.
#
# PREREQUISITES:
#   - Packer installed (https://www.packer.io/downloads)
#   - IBM Cloud credentials configured in variables.pkrvars.hcl
#   - Existing VPC subnet in IBM Cloud
#
# USAGE:
#   ./build.sh
#
#===============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==============================================================================="
echo "  Building IBM Cloud Producer Image (Option C: Hybrid)"
echo "==============================================================================="

# Check for variables file
if [ ! -f "variables.pkrvars.hcl" ]; then
    echo ""
    echo "ERROR: variables.pkrvars.hcl not found!"
    echo ""
    echo "Create it from the example:"
    echo "  cp variables.pkrvars.hcl.example variables.pkrvars.hcl"
    echo ""
    echo "Then edit with your IBM Cloud credentials."
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

# Check for required files
if [ ! -f "files/producer.py" ]; then
    echo "ERROR: files/producer.py not found!"
    exit 1
fi

if [ ! -f "files/docker-compose.yml" ]; then
    echo "ERROR: files/docker-compose.yml not found!"
    exit 1
fi

echo ""
echo "[1/3] Initializing Packer plugins..."
packer init producer-image.pkr.hcl

echo ""
echo "[2/3] Validating template..."
packer validate -var-file=variables.pkrvars.hcl producer-image.pkr.hcl

echo ""
echo "[3/3] Building custom image..."
packer build -var-file=variables.pkrvars.hcl producer-image.pkr.hcl

echo ""
echo "==============================================================================="
echo "  Build Complete!"
echo "==============================================================================="
echo ""
echo "The image ID will be displayed above. Update your terraform.tfvars with this ID:"
echo "  custom_image_id = \"r006-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\""
echo ""
echo "Location: terraform/ibm-vpc-from-image/terraform.tfvars"
echo ""
echo "==============================================================================="
