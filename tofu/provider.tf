terraform {
    backend "s3" {
        bucket = "tofu"
        key = "home-ops/terraform.tfstate"

        skip_credentials_validation = true
        skip_region_validation = true
        skip_requesting_account_id  = true
        skip_s3_checksum = true
    }

    required_providers {
        cloudflare = {
            source = "cloudflare/cloudflare"
            version = "4.34.0"
        }
        proxmox = {
          source = "bpg/proxmox"
          version = "0.59.1"
        }
        sops = {
          source = "carlpett/sops"
          version = "1.1.1"
        }
    }
}

provider "cloudflare" {
}

provider "proxmox" {
    insecure = true
    endpoint = data.sops_file.encrypted-secrets.data["proxmox_endpoint"]
}

data "sops_file" "encrypted-secrets" {
  source_file = "secrets.sops.yaml"
  input_type = "yaml"
}
