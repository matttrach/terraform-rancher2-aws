provider "aws" {
  default_tags {
    tags = {
      Id    = local.identifier
      Owner = local.owner
    }
  }
}

provider "acme" {
  server_url = local.acme_server_url
}

provider "github" {}
provider "kubernetes" {} # make sure you set the env variable KUBE_CONFIG_PATH to local_file_path (file_path variable)
provider "helm" {}       # make sure you set the env variable KUBE_CONFIG_PATH to local_file_path (file_path variable)


locals {
  identifier           = var.identifier
  example              = "basic"
  project_name         = "tf-${substr(md5(join("-", [local.example, local.identifier])), 0, 5)}"
  username             = local.project_name
  domain               = local.project_name
  zone                 = var.zone
  key_name             = var.key_name
  key                  = var.key
  acme_server_url      = "https://acme-staging-v02.api.letsencrypt.org/directory" # "https://acme-v02.api.letsencrypt.org/directory"
  owner                = var.owner
  rke2_version         = var.rke2_version
  local_file_path      = var.file_path
  runner_ip            = chomp(data.http.myip.response_body) # "runner" is the server running Terraform
  rancher_version      = var.rancher_version
  cert_manager_version = "1.18.1"
  os                   = "sle-micro-61"
}

data "http" "myip" {
  url = "https://ipinfo.io/ip"
}

module "rancher" {
  source = "../../"
  # project
  identifier   = local.identifier
  owner        = local.owner
  project_name = local.project_name
  domain       = local.domain
  zone         = local.zone
  # access
  key_name = local.key_name
  key      = local.key
  username = local.username
  admin_ip = local.runner_ip
  # rke2
  rke2_version    = local.rke2_version
  local_file_path = local.local_file_path
  install_method  = "rpm" # rpm only for now, need to figure out local helm chart installs otherwise
  cni             = "canal"
  node_configuration = {
    "rancher" = {
      type            = "all-in-one"
      size            = "medium"
      os              = local.os
      indirect_access = true
      initial         = true
    }
  }
  # rancher
  cert_manager_version = local.cert_manager_version
  cert_use_strategy    = "module"
  rancher_version      = local.rancher_version
  acme_server_url      = local.acme_server_url
}

provider "rancher2" {
  alias     = "authenticate"
  bootstrap = true
  api_url   = "https://${local.domain}.${local.zone}"
  timeout   = "300s"
  ca_certs  = module.rancher.tls_certificate_chain
}

resource "rancher2_bootstrap" "authenticate" {
  depends_on = [
    module.rancher,
  ]
  provider         = rancher2.authenticate
  initial_password = module.rancher.admin_password
  password         = module.rancher.admin_password
  token_update     = true
  token_ttl        = 7200 # 2 hours
}

provider "rancher2" {
  alias     = "default"
  api_url   = "https://${local.domain}.${local.zone}"
  token_key = rancher2_bootstrap.authenticate.token
  timeout   = "300s"
  ca_certs  = module.rancher.tls_certificate_chain
}

data "rancher2_cluster" "local" {
  depends_on = [
    module.rancher,
    rancher2_bootstrap.authenticate,
  ]
  provider = rancher2.default
  name     = "local"
}
