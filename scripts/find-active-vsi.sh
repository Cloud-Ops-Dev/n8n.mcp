#!/bin/bash
# Find active IBM VPC VSI from either terraform directory
# Returns JSON with VSI info or error

ONDEMAND_DIR="/home/clay/IDE/tools/n8n.mcp/terraform/ibm-vpc-ondemand"
FROMIMAGE_DIR="/home/clay/IDE/tools/n8n.mcp/terraform/ibm-vpc-from-image"

# Function to check terraform output
check_terraform_output() {
    local dir=$1
    local source=$2

    # Get terraform output as JSON
    output=$(docker run --rm -v "$dir:/workspace" -w /workspace hashicorp/terraform:latest output -json 2>/dev/null || echo '{}')

    # Use python to parse JSON (more reliable than bash/grep/sed)
    result=$(python3 -c "
import json
import sys

try:
    data = json.loads('''$output''')
    if 'public_ip' in data and 'value' in data['public_ip']:
        public_ip = data['public_ip']['value']
        private_ip = data.get('private_ip', {}).get('value', '')
        vsi_id = data.get('vsi_id', {}).get('value', '')

        print(json.dumps({
            'status': 'VSI_FOUND',
            'source': '$source',
            'public_ip': public_ip,
            'private_ip': private_ip,
            'vsi_id': vsi_id
        }))
        sys.exit(0)
    else:
        sys.exit(1)
except Exception:
    sys.exit(1)
" 2>/dev/null)

    if [ $? -eq 0 ]; then
        echo "$result"
        return 0
    fi

    return 1
}

# Check ondemand first
if check_terraform_output "$ONDEMAND_DIR" "ibm-vpc-ondemand"; then
    exit 0
fi

# Check from-image second
if check_terraform_output "$FROMIMAGE_DIR" "ibm-vpc-from-image"; then
    exit 0
fi

# No VSI found
echo "{\"status\":\"NO_VSI\",\"message\":\"No active VSI found in either terraform directory\"}"
exit 1
