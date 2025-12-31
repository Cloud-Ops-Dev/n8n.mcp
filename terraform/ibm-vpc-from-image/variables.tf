# Variables for IBM VPC from Custom Image

variable "ibm_api_key" {
  description = "IBM Cloud API Key"
  type        = string
  sensitive   = true
}

variable "ibm_region" {
  description = "IBM Cloud region"
  type        = string
  default     = "us-south"
}

variable "custom_image_id" {
  description = "ID of the custom image to use"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of existing SSH key in IBM Cloud"
  type        = string
  default     = "lab-key"
}

variable "ssh_key_path" {
  description = "Local path to SSH private key"
  type        = string
  default     = "/home/clay/.ssh/id_ed25519"
}

variable "instance_name" {
  description = "Name for the VSI instance"
  type        = string
  default     = "n8n-lab-vsi-from-image"
}

variable "instance_profile" {
  description = "Instance profile (size)"
  type        = string
  default     = "cx2-2x4"  # 2 vCPU, 4 GB RAM
}

variable "redis_host" {
  description = "Redis server IP address (AWS EC2)"
  type        = string
}

variable "redis_port" {
  description = "Redis server port"
  type        = string
  default     = "6379"
}

variable "queue_name" {
  description = "Redis queue name"
  type        = string
  default     = "demo-queue"
}

variable "message_interval" {
  description = "Seconds between messages"
  type        = string
  default     = "5"
}
