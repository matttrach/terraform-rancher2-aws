# project
variable "identifier" {
  type        = string
  description = <<-EOT
    A random string used to uniquely identify resources in this project.
    Servers will receive a tag 'Id' with this value.
  EOT
}
variable "owner" {
  type        = string
  description = <<-EOT
    An identifier for the person or group responsible for the resources created.
    A tag 'Owner' will be added to the servers with this value.
  EOT
}
variable "project_name" {
  type        = string
  description = <<-EOT
    A name for the project, used as a prefix for resource names.
  EOT
}
variable "domain" {
  type        = string
  description = <<-EOT
    The host for this project, should not include the zone.
    The zone for this domain must already exist in AWS and should be specified in the 'zone' variable.
    If left empty this will default to the project name.
    eg. "test" in "test.example.com"
  EOT
}
variable "zone" {
  type        = string
  description = <<-EOT
    The Route53 DNS zone to deploy the cluster into.
    The zone must already exist and have propagated.
  EOT
}
# access
variable "key_name" {
  type        = string
  description = <<-EOT
    The name of an AWS key pair to use for SSH access to the instance.
    This key should already be added to your ssh agent for server authentication.
  EOT
}
variable "key" {
  type        = string
  description = <<-EOT
    The contents of an AWS key pair to use for SSH access to the instance.
    This is necessary for installing rke2 on the nodes and will be removed after installation.
  EOT
}
variable "username" {
  type        = string
  description = <<-EOT
    The username to use for SSH access to the instance.
  EOT
}
variable "admin_ip" {
  type        = string
  description = <<-EOT
    The IP address of the server running Terraform.
  EOT
}
# rke2
variable "rke2_version" {
  type        = string
  description = <<-EOT
    The version of rke2 to install on the nodes.
  EOT
}
variable "local_file_path" {
  type        = string
  description = <<-EOT
    A local path to store files related to the install.
    Needs to be isolated from the terraform files and state.
  EOT
  default     = "./rke2"
}
variable "install_method" {
  type        = string
  description = <<-EOT
    The method to use for installing rke2 on the nodes.
    Can be either 'rpm' or 'tar'.
  EOT
}
variable "cni" {
  type        = string
  description = <<-EOT
    The CNI plugin to use for the cluster.
  EOT
}
variable "node_configuration" {
  type = map(object({
    type            = string
    size            = string
    os              = string
    indirect_access = bool
    initial         = bool
  }))
  description = <<-EOT
    A map of configuration options for the nodes to constitute the cluster.
    Only one node should have the "initial" attribute set to true.
    Be careful which node you decide to start the cluster,
      it must host the database for others to be able to join properly.
    There are 5 types of node: 'all-in-one', 'control-plane', 'worker', 'database', 'api'.
      'all-in-one' nodes have all roles (control-plane, worker, etcd)
      'control-plane' nodes have the api (control-plane) and database (etcd) roles
      'worker' nodes have just the 'worker' role
      'database' nodes have only the database (etcd) role
      'api' nodes have only the api (control-plane) server role
    By default we will set taints to prevent non-component workloads
      from running on database, api, and control-plane nodes.
    Size correlates to the server size options from the server module:
      https://github.com/rancher/terraform-aws-server/blob/main/modules/server/types.tf
    We recommend using the size nodes that best fit your use case:
      https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/installation-requirements#rke2-kubernetes
    OS correlates to the server image options from the server module:
      https://github.com/rancher/terraform-aws-server/blob/main/modules/image/types.tf
    We recommend using the same os for all servers, we don't currently test for clusters with mixed OS types.
    Indirect access refers to how the cluster will be load balanced,
      some admins are ok with every server in the cluster responding to inbound requests since the built in proxy will redirect,
      but that isn't always the best choice since some nodes (like database nodes and secure workers)
      are better to restrict to internal access only.
      Setting this value to true will allow the network load balancer to direct traffic to the node.
      Setting this value to false will prevent the load balancer from directing traffic to the node.
  EOT
  default = {
    "initial" = {
      type            = "all-in-one"
      size            = "medium"
      os              = "sle-micro-60"
      indirect_access = true
      initial         = true
    }
  }
}
# Rancher
variable "cert_manager_version" {
  type        = string
  description = <<-EOT
    The version of cert-manager to install.
  EOT
  default     = "v1.18.1"
}
variable "cert_use_strategy" {
  type        = string
  description = <<-EOT
    How you intend to get TLS working with Rancher.
    Must be one of "module", "rancher", or "supply".
    The "module" option means that you want to use the certificate that the module generates for you.
    The "rancher" option means that you want to configure cert-manager to generate TLS certs with Rancher's help.
    The "supply" option means that you want to supply your own certificate as variables to the module.
  EOT
  validation {
    condition     = contains(["module", "rancher", "supply"], var.cert_use_strategy)
    error_message = "Must be one of 'module', 'rancher', or 'supply'."
  }
}
variable "tls_public_cert" {
  type        = string
  description = <<-EOT
    The contents of your public certificate to use for Rancher TLS connections.
    Required when cert_use_strategy is "provide".
  EOT
  default     = null
  sensitive   = true
}
variable "tls_public_chain" {
  type        = string
  description = <<-EOT
    The contents of your public certificate chain to use for Rancher TLS connections.
    This should include the public cert along with any intermediate certificates.
    In the case of self-signed certs this will probably match the tls_public_cert variable.
    Required when cert_use_strategy is "provide".
  EOT
  default     = null
  sensitive   = true
}
variable "tls_private_key" {
  type        = string
  description = <<-EOT
    The contents of your private key to use for Rancher TLS connections.
    Required when cert_use_strategy is "supply".
    WARNING! This will be stored in state.
  EOT
  default     = null
  sensitive   = true
}
variable "rancher_version" {
  type        = string
  description = <<-EOT
    The version of rancher to install.
  EOT
  default     = "2.11.2"
}
variable "rancher_helm_repo" {
  type        = string
  description = <<-EOT
    The Helm repository to retrieve charts from.
  EOT
  default     = "https://releases.rancher.com/server-charts"
}
variable "rancher_helm_channel" {
  type        = string
  description = <<-EOT
    The Helm repository channel retrieve charts from.
    Can be "latest" or "stable", defaults to "stable".
  EOT
  default     = "stable"
}
variable "bootstrap_rancher" {
  type        = bool
  description = <<-EOT
    Whether or not to install Rancher, defaults to true.
    This mostly exists to provide a convenient way to generate RKE2 clusters that are Rancher compatible.
    For a more robust solution check out the terraform-aws-rke2 module.
  EOT
  default     = true
}
variable "cert_manager_configuration" {
  type = object({
    aws_access_key_id     = string
    aws_secret_access_key = string
    aws_region            = string
    aws_session_token     = string
    acme_email            = string
    acme_server_url       = string
  })
  description = <<-EOT
    The AWS access key information necessary to configure cert-manager.
    This should have the limited access as found in the cert-manager documentation.
    https://cert-manager.io/docs/configuration/acme/dns01/route53/#iam-user-with-long-term-access-key
    This is required when the cert_use_strategy variable is "rancher".
  EOT
  default     = null
  sensitive   = true
}
variable "rancher_helm_chart_use_strategy" {
  type        = string
  description = <<-EOT
    The strategy to use for Rancher's Helm chart values.
    Options include: "default", "merge", or "provide".
    Default will tell the module to use our suggested default configuration.
    Merge will merge our default suggestions with your supplied configuration, anything you supply will override the default.
    Provide will ignore our default suggestions and use the configuration provided in the rancher_helm_chart_values argument.
  EOT
  default     = "default"
  validation {
    condition     = contains(["default", "merge", "provide"], var.rancher_helm_chart_use_strategy)
    error_message = "Must be one of 'default', 'merge', or 'provide'."
  }
}
variable "rancher_helm_chart_values" {
  type        = map(any)
  description = <<-EOT
    A key/value map of Helm arguments to pass to the Rancher helm chart.
    This will be ignored if the rancher_helm_chart_use_strategy argument is set to "default".
    eg.
    {
      "hostname"                  = local.rancher_domain
      "replicas"                  = "1"
      "bootstrapPassword"         = "admin"
      "ingress.enabled"           = "true"
      "ingress.tls.source"        = "secret"
      "ingress.tls.secretName"    = "tls-rancher-ingress"
      "privateCA"                 = "true"
      "agentTLSMode"              = "system-store"
    }
  EOT
  default     = {}
}
variable "acme_server_url" {
  type        = string
  description = <<-EOT
    The acme_server_url to use when generating TLS certs with Let's Encrypt.
  EOT
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}
