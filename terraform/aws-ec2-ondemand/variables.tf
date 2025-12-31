# Variables for AWS EC2 On-Demand Instance

variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance (Ubuntu 22.04)"
  type        = string
  default     = "ami-0ea3c35c5c3284d82"  # Ubuntu 22.04 LTS in us-east-2
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"  # Free tier eligible
}

variable "instance_name" {
  description = "Name for the EC2 instance"
  type        = string
  default     = "n8n-lab-ec2-redis"
}

variable "ssh_key_name" {
  description = "Name of existing SSH key pair in AWS"
  type        = string
  default     = "R_Smurf_001"
}

variable "ssh_key_path" {
  description = "Local path to SSH private key"
  type        = string
  default     = "/home/clay/.ssh/R_Smurf_001.pem"
}
