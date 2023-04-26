module "ldap_mgmt" {
  source = "./modules/ldap-mgmt"

  ## ldap config
  # connection
  ldap_url = "ldaps://ipa.infra.sololab:636"
  # ldap_starttls     = true
  ldap_insecure_tls = true
  # ldap_certificate  = var.certificate
  # Binding - Authenticated Search
  ldap_binddn   = "uid=system,cn=sysaccounts,cn=etc,dc=infra,dc=sololab"
  ldap_bindpass = "P@ssw0rd"
  ldap_userdn   = "cn=users,cn=accounts,dc=infra,dc=sololab"
  ldap_userattr = "uid"
  # Group Membership Resolution
  ldap_groupfilter = "(&(objectClass=posixgroup)(cn=svc-vault-*)(member:={{.UserDN}}))"
  ldap_groupdn     = "cn=groups,cn=accounts,dc=infra,dc=sololab"
  ldap_groupattr   = "cn"

  # vault policies
  vault_policies = {
    vault-root = {
      policy_content = <<EOT
path "secret/*" 
{
  capabilities = [ "create", "read", "update", "delete", "list", "patch" ]
}
# Manage identity
path "identity/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "sys/health"
{
  capabilities = ["read", "sudo"]
}
# Create and manage ACL policies broadly across Vault
# List existing policies
path "sys/policies/acl"
{
  capabilities = ["list"]
}
# Create and manage ACL policies
path "sys/policies/acl/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
# Enable and manage authentication methods broadly across Vault
# Manage auth methods broadly across Vault
path "auth/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
# Create, update, and delete auth methods
path "sys/auth/*"
{
  capabilities = ["create", "update", "delete", "sudo"]
}
# List auth methods
path "sys/auth"
{
  capabilities = ["read"]
}
# Enable and manage the key/value secrets engine at `secret/` path
# List, create, update, and delete key/value secrets
path "secret/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
# Manage secrets engines
path "sys/mounts/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
# List existing secrets engines.
path "sys/mounts"
{
  capabilities = ["read"]
}
EOT
    }
  }

  # groups
  groups = {
    vault-root = {
      group_type     = "external"
      group_policies = ["vault-root"]
      group_alias    = ["svc-vault-root"]
    }
  }
}

# module "vault_policy_root" {
#   source = "./modules/policies"

#   policy_name    = "vault-root"
#   policy_content = <<EOT
# path "secret/*" 
# {
#   capabilities = [ "create", "read", "update", "delete", "list", "patch" ]
# }
# # Manage identity
# path "identity/*"
# {
#   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
# }
# path "sys/health"
# {
#   capabilities = ["read", "sudo"]
# }
# # Create and manage ACL policies broadly across Vault
# # List existing policies
# path "sys/policies/acl"
# {
#   capabilities = ["list"]
# }
# # Create and manage ACL policies
# path "sys/policies/acl/*"
# {
#   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
# }
# # Enable and manage authentication methods broadly across Vault
# # Manage auth methods broadly across Vault
# path "auth/*"
# {
#   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
# }
# # Create, update, and delete auth methods
# path "sys/auth/*"
# {
#   capabilities = ["create", "update", "delete", "sudo"]
# }
# # List auth methods
# path "sys/auth"
# {
#   capabilities = ["read"]
# }
# # Enable and manage the key/value secrets engine at `secret/` path
# # List, create, update, and delete key/value secrets
# path "secret/*"
# {
#   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
# }
# # Manage secrets engines
# path "sys/mounts/*"
# {
#   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
# }
# # List existing secrets engines.
# path "sys/mounts"
# {
#   capabilities = ["read"]
# }
# EOT
# }

# module "vault_group_root" {
#   source = "./modules/identity"

#   group_name     = "vault-root"
#   group_type     = "external"
#   group_policies = ["vault-root"]
#   group_alias = {
#     svc-vault-root = {
#       name : "svc-vault-root"
#       mount_accessor : module.vault_auth_ldap.ldap_accessor
#     }
#   }
# }
