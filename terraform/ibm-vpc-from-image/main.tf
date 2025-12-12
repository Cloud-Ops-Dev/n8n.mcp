# IBM VPC VSI from Custom Image
# Purpose: Spin up VSI from a previously captured custom image

# Data source for custom image
data "ibm_is_image" "custom_image" {
  identifier = var.custom_image_id
}

# Data source for SSH key (existing)
data "ibm_is_ssh_key" "lab_key" {
  name = var.ssh_key_name
}

# VPC
resource "ibm_is_vpc" "ondemand_vpc" {
  name = "n8n-lab-vpc-from-image"
  tags = ["n8n-lab", "on-demand", "custom-image"]
}

# Subnet
resource "ibm_is_subnet" "ondemand_subnet" {
  name            = "n8n-lab-subnet-from-image"
  vpc             = ibm_is_vpc.ondemand_vpc.id
  zone            = "${var.ibm_region}-1"
  ipv4_cidr_block = "10.240.0.0/24"
  tags            = ["n8n-lab", "on-demand", "custom-image"]
}

# Security Group to allow SSH and HTTP
resource "ibm_is_security_group" "ondemand_sg" {
  name = "n8n-lab-sg-from-image"
  vpc  = ibm_is_vpc.ondemand_vpc.id
  tags = ["n8n-lab", "on-demand", "custom-image"]
}

resource "ibm_is_security_group_rule" "allow_ssh" {
  group     = ibm_is_security_group.ondemand_sg.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "allow_outbound" {
  group     = ibm_is_security_group.ondemand_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

# Public Gateway for internet access
resource "ibm_is_public_gateway" "ondemand_gateway" {
  name = "n8n-lab-gateway-from-image"
  vpc  = ibm_is_vpc.ondemand_vpc.id
  zone = "${var.ibm_region}-1"
  tags = ["n8n-lab", "on-demand", "custom-image"]
}

# Attach gateway to subnet
resource "ibm_is_subnet_public_gateway_attachment" "ondemand_gateway_attachment" {
  subnet         = ibm_is_subnet.ondemand_subnet.id
  public_gateway = ibm_is_public_gateway.ondemand_gateway.id
}

# VSI Instance from Custom Image
resource "ibm_is_instance" "ondemand_vsi" {
  name    = var.instance_name
  image   = data.ibm_is_image.custom_image.id
  profile = var.instance_profile
  tags    = ["n8n-lab", "on-demand", "custom-image"]

  primary_network_interface {
    subnet          = ibm_is_subnet.ondemand_subnet.id
    security_groups = [ibm_is_security_group.ondemand_sg.id]
  }

  vpc  = ibm_is_vpc.ondemand_vpc.id
  zone = "${var.ibm_region}-1"
  keys = [data.ibm_is_ssh_key.lab_key.id]
}

# Floating IP for public access
resource "ibm_is_floating_ip" "ondemand_fip" {
  name   = "n8n-lab-fip-from-image"
  target = ibm_is_instance.ondemand_vsi.primary_network_interface[0].id
  tags   = ["n8n-lab", "on-demand", "custom-image"]
}

# Outputs
output "vsi_id" {
  value       = ibm_is_instance.ondemand_vsi.id
  description = "VSI Instance ID"
}

output "public_ip" {
  value       = ibm_is_floating_ip.ondemand_fip.address
  description = "Public IP address"
}

output "private_ip" {
  value       = ibm_is_instance.ondemand_vsi.primary_network_interface[0].primary_ip[0].address
  description = "Private IP address"
}

output "vpc_id" {
  value       = ibm_is_vpc.ondemand_vpc.id
  description = "VPC ID"
}

output "ssh_command" {
  value       = "ssh -i ${var.ssh_key_path} ubuntu@${ibm_is_floating_ip.ondemand_fip.address}"
  description = "SSH command to connect"
}

output "image_id_used" {
  value       = data.ibm_is_image.custom_image.id
  description = "Custom image ID that was used"
}
