provider "aws" {
  default_tags {
    tags = {
      Id    = local.identifier
      Owner = local.owner
    }
  }
  region = local.aws_region
}

provider "acme" {
  server_url = local.acme_server_url
}

provider "github" {}
provider "kubernetes" {} # make sure you set the env variable KUBE_CONFIG_PATH to local_file_path (file_path variable)
provider "helm" {}       # make sure you set the env variable KUBE_CONFIG_PATH to local_file_path (file_path variable)


locals {
  identifier            = var.identifier
  example               = "downstream"
  project_name          = "tf-${substr(md5(join("-", [local.example, local.identifier])), 0, 5)}"
  username              = local.project_name
  domain                = local.project_name
  zone                  = var.zone
  key_name              = var.key_name
  key                   = var.key
  owner                 = var.owner
  rke2_version          = var.rke2_version
  local_file_path       = var.file_path
  runner_ip             = chomp(data.http.myip.response_body) # "runner" is the server running Terraform
  rancher_version       = var.rancher_version
  cert_manager_version  = "1.18.1" #"1.16.3" #"1.13.1"
  os                    = "sle-micro-61"
  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
  aws_region            = var.aws_region
  aws_session_token     = var.aws_session_token
  # tflint-ignore: terraform_unused_declarations
  aws_instance_type = "m5.large"
  # tflint-ignore: terraform_unused_declarations
  node_count      = 1
  email           = (var.email != "" ? var.email : "${local.identifier}@${local.zone}")
  acme_server_url = "https://acme-staging-v02.api.letsencrypt.org/directory" #"https://acme-v02.api.letsencrypt.org/directory"
  helm_chart_values = {
    "hostname"                                            = "${local.domain}.${local.zone}"
    "replicas"                                            = "1"
    "bootstrapPassword"                                   = "admin"
    "ingress.enabled"                                     = "true"
    "ingress.tls.source"                                  = "letsEncrypt"
    "tls"                                                 = "ingress"
    "letsEncrypt.ingress.class"                           = "nginx"
    "letsEncrypt.environment"                             = "staging" # "production"
    "letsEncrypt.email"                                   = local.email
    "certmanager.version"                                 = local.cert_manager_version
    "agentTLSMode"                                        = "strict"
    "privateCA"                                           = "true"
    "additionalTrustedCAs"                                = "true"
    "ingress.extraAnnotations.cert-manager\\.io\\/issuer" = "rancher" # hard coded
  }
  cert_manager_config = {
    aws_access_key_id     = local.aws_access_key_id
    aws_secret_access_key = local.aws_secret_access_key
    aws_session_token     = local.aws_session_token
    aws_region            = local.aws_region
    acme_email            = local.email
    acme_server_url       = local.acme_server_url
  }
  node_configuration = {
    "rancher" = {
      type            = "all-in-one"
      size            = "large" # this is the smallest size that Rancher will fit in, "xl" or "xxl" are probably more appropriate
      os              = local.os
      indirect_access = true
      initial         = true
    }
  }
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
  rke2_version       = local.rke2_version
  local_file_path    = local.local_file_path
  install_method     = "rpm" # rpm only for now, need to figure out local helm chart installs otherwise
  cni                = "canal"
  node_configuration = local.node_configuration
  # rancher
  rancher_version            = local.rancher_version
  rancher_helm_chart_values  = local.helm_chart_values
  cert_manager_version       = local.cert_manager_version
  cert_use_strategy          = "rancher"
  cert_manager_configuration = local.cert_manager_config
  acme_server_url            = local.acme_server_url
}

module "rke2_image" {
  source              = "rancher/server/aws"
  version             = "v1.4.0"
  server_use_strategy = "skip"
  image_use_strategy  = "find"
  image_type          = local.os # this is not required to match Rancher, it just seemed easier in this example
}

provider "rancher2" {
  api_url   = "https://${local.domain}.${local.zone}"
  token_key = module.rancher.admin_token
  timeout   = "300s"
  ca_certs  = module.rancher.tls_certificate_chain
}

# you can add this one multiple times, or use a loop to deploy multiple clusters
module "downstream" {
  depends_on = [
    module.rancher,
    module.rke2_image,
  ]
  source = "./modules/downstream"
  # general
  name       = "tf-all-in-one-config" # this should be unique per cluster
  identifier = local.identifier
  owner      = local.owner
  # aws access
  aws_access_key_id     = local.aws_access_key_id
  aws_secret_access_key = local.aws_secret_access_key
  aws_session_token     = trimspace(chomp(local.aws_session_token))
  aws_region            = local.aws_region
  aws_region_letter = replace(
    module.rancher.subnets[keys(module.rancher.subnets)[0]].availability_zone,
    local.aws_region,
    ""
  )
  # aws project info
  vpc_id                        = module.rancher.vpc.id
  security_group_id             = module.rancher.security_group.id
  load_balancer_security_groups = module.rancher.load_balancer_security_groups
  subnet_id                     = module.rancher.subnets[keys(module.rancher.subnets)[0]].id
  # node info
  aws_instance_type = local.aws_instance_type
  ami_id            = module.rke2_image.image.id
  ami_ssh_user      = module.rke2_image.image.user
  ami_admin_group   = module.rke2_image.image.admin_group
  node_count        = local.node_count
  direct_node_access = {
    runner_ip       = local.runner_ip
    ssh_access_key  = local.key
    ssh_access_user = local.project_name
  }
  # rke2 info
  rke2_version = local.rke2_version
}
