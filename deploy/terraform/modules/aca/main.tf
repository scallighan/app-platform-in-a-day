locals {
  loc_short = "${upper(substr(var.location, 0 , 1))}US"
  tags = merge(
    {
      "module" = "aca"
    },
    var.tags
  ) 
}

data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "default" {
  name                = "DefaultWorkspace-${data.azurerm_client_config.current.subscription_id}-${local.loc_short}"
  resource_group_name = "DefaultResourceGroup-${local.loc_short}"
} 

data "azurerm_key_vault" "this" {
  name = split("/", (split(".", var.key_vault_uri)[0]))[2]
  resource_group_name = var.resource_group_name
}

# 10.7.8.0 - 10.7.15.255
resource "azurerm_subnet" "aca" {
  name                 = "aca-subnet-${var.location}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = ["10.7.8.0/21"]

}

resource "azurerm_storage_account" "sa" {
  name                     = "saaca${var.name}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_nested_items_to_be_public = false
}

resource "azurerm_user_assigned_identity" "aca" {
  name                = "uai-aca-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  
}

resource "azurerm_key_vault_access_policy" "this" {
  key_vault_id = data.azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.aca.principal_id

  key_permissions = [
    "Get",
  ]

  secret_permissions = [
    "Get",
    "List",
  ]

}


resource "azurerm_container_app_environment" "aca" {
  name                       = "ace-${var.name}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.default.id
  infrastructure_subnet_id   = azurerm_subnet.aca.id
  tags = local.tags
}

resource "azurerm_storage_share" "accountsapi" {
  name                 = "accountsapi"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 1
}

resource "azurerm_storage_share_file" "accountsapiappjson" {
  name             = "applicationinsights.json"
  storage_share_id = azurerm_storage_share.accountsapi.id
  source           = "${path.module}/accounts-applicationinsights.json"
}

resource "azurerm_container_app_environment_storage" "accountsapi" {
  name                         = "accountsapishare"
  container_app_environment_id = azurerm_container_app_environment.aca.id
  account_name                 = azurerm_storage_account.sa.name
  share_name                   = azurerm_storage_share.accountsapi.name
  access_key                   = azurerm_storage_account.sa.primary_access_key
  access_mode                  = "ReadOnly"
}

resource "azurerm_container_app" "accountsapi" {
  name                         = "aca-accounts-api"
  container_app_environment_id = azurerm_container_app_environment.aca.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 1
    container {
      name   = "aca-accounts-api"
      image  = "ghcr.io/implodingduck/quackers-bank-accounts-api:main"
      cpu    = 0.25
      memory = "0.5Gi"
      volume_mounts {
        name = azurerm_container_app_environment_storage.accountsapi.name
        path = "/opt/target/config"
      }
      env {
        name = "APPLICATIONINSIGHTS_CONFIGURATION_FILE"
        value = "/opt/target/config/applicationinsights.json"
      }
      env {
        name = "ACCOUNTSAPI_BASEURL"
        value = "http://localhost:3500/v1.0/invoke/accounts-api/method"
      }
      env {
        name = "TRANSACTIONSAPI_BASEURL"
        value = "http://localhost:3500/v1.0/invoke/transactions-api/method"
      }
      env {
        name = "ACCOUNTS_SCOPES"
        secret_name = "accounts-scopes"
      }
      env {
        name = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        secret_name = "applicationinsights-connection-string"
      }
      env {
        name = "B2C_BASE_URI"
        secret_name = "b2c-base-uri"
      }
      env {
        name = "B2C_CLIENT_ID"
        secret_name = "b2c-client-id-accounts"
      }
      env {
        name = "B2C_CLIENT_SECRET"
        secret_name = "b2c-client-secret"
      }
      env {
        name = "B2C_TENANT_ID"
        secret_name = "b2c-tenant-id"
      }
      env {
        name = "DB_PASSWORD"
        secret_name = "db-password"
      }
      env {
        name = "DB_URL"
        secret_name = "db-url"
      }
      env {
        name = "DB_USERNAME"
        secret_name = "db-username"
      }
      env {
        name = "TRANSACTIONS_SCOPES"
        secret_name = "transactions-scopes"
      }
      
    }
    
    volume {
      name         = azurerm_container_app_environment_storage.accountsapi.name
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.accountsapi.name
    }
  }
  ingress {
    allow_insecure_connections = true
    external_enabled           = true
    target_port                = 8080
    transport                  = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
  dapr {
    app_id       = "accounts-api"
    app_port     = 8080
    app_protocol = "http"
  }

  secret {
    name = "accounts-scopes"
    value = "keyvaultref:${var.key_vault_uri}/secrets/ACCOUNT-SCOPES/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "applicationinsights-connection-string"
    value = "keyvaultref:${var.key_vault_uri}/secrets/APPLICATIONINSIGHTS-CONNECTION-STRING/,identityref:${azurerm_user_assigned_identity.aca.id}"
  } 

  secret {
    name = "b2c-base-uri"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-BASE-URI/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "b2c-client-id-accounts"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-CLIENT-ID-ACCOUNTS/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "b2c-client-secret"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-CLIENT-SECRET/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "b2c-tenant-id"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-TENANT-ID/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "db-password"
    value = "keyvaultref:${var.key_vault_uri}/secrets/DB-PASSWORD/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "db-url"
    value = "keyvaultref:${var.key_vault_uri}/secrets/DB-URL/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "db-username"
    value = "keyvaultref:${var.key_vault_uri}/secrets/DB-USERNAME/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "transactions-scopes"
    value = "keyvaultref:${var.key_vault_uri}/secrets/TRANSACTIONS-SCOPES/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }


  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.aca.id
    ]
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [
      secret
    ]
  }
}

resource "azurerm_storage_share" "frontend" {
  name                 = "frontend"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 1
}

resource "azurerm_storage_share_file" "frontendappjson" {
  name             = "applicationinsights.json"
  storage_share_id = azurerm_storage_share.frontend.id
  source           = "${path.module}/frontend-applicationinsights.json"
}

resource "azurerm_container_app_environment_storage" "frontend" {
  name                         = "frontendshare"
  container_app_environment_id = azurerm_container_app_environment.aca.id
  account_name                 = azurerm_storage_account.sa.name
  share_name                   = azurerm_storage_share.frontend.name
  access_key                   = azurerm_storage_account.sa.primary_access_key
  access_mode                  = "ReadOnly"
}

resource "azurerm_container_app" "frontend" {
  name                         = "aca-frontend"
  container_app_environment_id = azurerm_container_app_environment.aca.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 1
    container {
      name   = "aca-frontend"
      image  = "ghcr.io/implodingduck/quackers-bank-frontend:main"
      cpu    = 0.25
      memory = "0.5Gi"
      
      volume_mounts {
        name = azurerm_container_app_environment_storage.frontend.name
        path = "/opt/target/config"
      }
      env {
        name = "APPLICATIONINSIGHTS_CONFIGURATION_FILE"
        value = "/opt/target/config/applicationinsights.json"
      }
      env {
        name = "ACCOUNTSAPI_BASEURL"
        value = "http://localhost:3500/v1.0/invoke/accounts-api/method"
      }
      env {
        name = "TRANSACTIONSAPI_BASEURL"
        value = "http://localhost:3500/v1.0/invoke/transactions-api/method"
      }
      env {
        name = "ACCOUNTS_SCOPES"
        secret_name = "accounts-scopes"
      }
      env {
        name = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        secret_name = "applicationinsights-connection-string"
      }
      env {
        name = "B2C_BASE_URI"
        secret_name = "b2c-base-uri"
      }
      env {
        name = "B2C_CLIENT_ID"
        secret_name = "b2c-client-id"
      }
      env {
        name = "B2C_CLIENT_SECRET"
        secret_name = "b2c-client-secret"
      }
      env {
        name = "B2C_TENANT_ID"
        secret_name = "b2c-tenant-id"
      }
      env {
        name = "DB_PASSWORD"
        secret_name = "db-password"
      }
      env {
        name = "DB_URL"
        secret_name = "db-url"
      }
      env {
        name = "DB_USERNAME"
        secret_name = "db-username"
      }
      env {
        name = "TRANSACTIONS_SCOPES"
        secret_name = "transactions-scopes"
      }
    }
    
    volume {
      name         = azurerm_container_app_environment_storage.frontend.name
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.frontend.name
    }
  }
  ingress {
    allow_insecure_connections = true
    external_enabled           = true
    target_port                = 8080
    transport                  = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  dapr {
    app_id       = "frontend"
    app_port     = 8080
    app_protocol = "http"
  }

  secret {
    name = "accounts-scopes"
    value = "keyvaultref:${var.key_vault_uri}/secrets/ACCOUNT-SCOPES/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "applicationinsights-connection-string"
    value = "keyvaultref:${var.key_vault_uri}/secrets/APPLICATIONINSIGHTS-CONNECTION-STRING/,identityref:${azurerm_user_assigned_identity.aca.id}"
  } 

  secret {
    name = "b2c-base-uri"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-BASE-URI/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "b2c-client-id"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-CLIENT-ID/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }


  secret {
    name = "b2c-client-id-accounts"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-CLIENT-ID-ACCOUNTS/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "b2c-client-secret"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-CLIENT-SECRET/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "b2c-tenant-id"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-TENANT-ID/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "db-password"
    value = "keyvaultref:${var.key_vault_uri}/secrets/DB-PASSWORD/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "db-url"
    value = "keyvaultref:${var.key_vault_uri}/secrets/DB-URL/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "db-username"
    value = "keyvaultref:${var.key_vault_uri}/secrets/DB-USERNAME/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "transactions-scopes"
    value = "keyvaultref:${var.key_vault_uri}/secrets/TRANSACTIONS-SCOPES/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  tags = local.tags
  lifecycle {
    ignore_changes = [
      secret
    ]
  }
}

resource "azurerm_storage_share" "transactionsapi" {
  name                 = "transactionsapi"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 1
}

resource "azurerm_storage_share_file" "transactionsappjson" {
  name             = "applicationinsights.json"
  storage_share_id = azurerm_storage_share.transactionsapi.id
  source           = "${path.module}/transactions-applicationinsights.json"
}

resource "azurerm_container_app_environment_storage" "transactionsapi" {
  name                         = "transactionsapishare"
  container_app_environment_id = azurerm_container_app_environment.aca.id
  account_name                 = azurerm_storage_account.sa.name
  share_name                   = azurerm_storage_share.transactionsapi.name
  access_key                   = azurerm_storage_account.sa.primary_access_key
  access_mode                  = "ReadOnly"
}

resource "azurerm_container_app" "transactionsapi" {
  name                         = "aca-transactions-api"
  container_app_environment_id = azurerm_container_app_environment.aca.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 1
    container {
      name   = "aca-transactions-api"
      image  = "ghcr.io/implodingduck/quackers-bank-transactions-api:main"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name = azurerm_container_app_environment_storage.transactionsapi.name
        path = "/opt/target/config"
      }
      env {
        name = "APPLICATIONINSIGHTS_CONFIGURATION_FILE"
        value = "/opt/target/config/applicationinsights.json"
      }
      env {
        name = "ACCOUNTSAPI_BASEURL"
        value = "http://localhost:3500/v1.0/invoke/accounts-api/method"
      }
      env {
        name = "TRANSACTIONSAPI_BASEURL"
        value = "http://localhost:3500/v1.0/invoke/transactions-api/method"
      }
      env {
        name = "ACCOUNTS_SCOPES"
        secret_name = "accounts-scopes"
      }
      env {
        name = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        secret_name = "applicationinsights-connection-string"
      }
      env {
        name = "B2C_BASE_URI"
        secret_name = "b2c-base-uri"
      }
      env {
        name = "B2C_CLIENT_ID"
        secret_name = "b2c-client-id-transactions"
      }
      env {
        name = "B2C_CLIENT_SECRET"
        secret_name = "b2c-client-secret-transactions"
      }
      env {
        name = "B2C_TENANT_ID"
        secret_name = "b2c-tenant-id"
      }
      env {
        name = "DB_PASSWORD"
        secret_name = "db-password"
      }
      env {
        name = "DB_URL"
        secret_name = "db-url"
      }
      env {
        name = "DB_USERNAME"
        secret_name = "db-username"
      }
      env {
        name = "TRANSACTIONS_SCOPES"
        secret_name = "transactions-scopes"
      }
    }
    
    volume {
      name         = azurerm_container_app_environment_storage.transactionsapi.name
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.transactionsapi.name
    }
  }
  ingress {
    allow_insecure_connections = true
    external_enabled           = true
    target_port                = 8080
    transport                  = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  dapr {
    app_id       = "transactions-api"
    app_port     = 8080
    app_protocol = "http"
  }

  secret {
    name = "accounts-scopes"
    value = "keyvaultref:${var.key_vault_uri}/secrets/ACCOUNT-SCOPES/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "applicationinsights-connection-string"
    value = "keyvaultref:${var.key_vault_uri}/secrets/APPLICATIONINSIGHTS-CONNECTION-STRING/,identityref:${azurerm_user_assigned_identity.aca.id}"
  } 

  secret {
    name = "b2c-base-uri"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-BASE-URI/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }
  secret {
    name = "b2c-client-id-transactions"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-CLIENT-ID-TRANSACTIONS/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "b2c-client-id-accounts"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-CLIENT-ID-ACCOUNTS/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "b2c-client-secret"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-CLIENT-SECRET/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "b2c-client-secret-transactions"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-CLIENT-SECRET-TRANSACTIONS/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "b2c-tenant-id"
    value = "keyvaultref:${var.key_vault_uri}/secrets/B2C-TENANT-ID/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "db-password"
    value = "keyvaultref:${var.key_vault_uri}/secrets/DB-PASSWORD/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "db-url"
    value = "keyvaultref:${var.key_vault_uri}/secrets/DB-URL/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "db-username"
    value = "keyvaultref:${var.key_vault_uri}/secrets/DB-USERNAME/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  secret {
    name = "transactions-scopes"
    value = "keyvaultref:${var.key_vault_uri}/secrets/TRANSACTIONS-SCOPES/,identityref:${azurerm_user_assigned_identity.aca.id}"
  }

  tags = local.tags
  lifecycle {
    ignore_changes = [
      secret
    ]
  }
}