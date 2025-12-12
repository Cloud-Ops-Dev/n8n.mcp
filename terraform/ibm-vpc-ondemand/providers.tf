terraform {
  required_version = ">= 1.0"

  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 1.0"
    }
  }
}

provider "ibm" {
  ibmcloud_api_key = var.ibm_api_key
  region           = var.ibm_region
}
