# -------------------------
# Log Analytics + Sentinel
# -------------------------
resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.name}-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags
}

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_id = azurerm_log_analytics_workspace.law.id
}

# -------------------------
# Defender for Cloud + Defender for Endpoint
# Defender for Servers P1/P2 auto-deploys MDE extension to VMs when enabled
# -------------------------
resource "azurerm_security_center_subscription_pricing" "defender_servers" {
  count = var.enable_defender_for_cloud ? 1 : 0

  tier          = "Standard"
  resource_type = "VirtualMachines"
  subplan       = "P2"
}

# Defender-for-Sentinel connector: not available in azurerm provider. Enable manually in Sentinel:
# Data connectors -> Microsoft Defender for Cloud -> Connect

# -------------------------
# NSG diagnostics -> Log Analytics
# -------------------------
resource "azurerm_monitor_diagnostic_setting" "nsg_diag" {
  for_each = var.enable_defender_for_cloud ? var.nsg_ids : {}

  name                       = "${var.name}-nsg-diag-${each.key}"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }
  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

# -------------------------
# Azure Monitor Agent + DCR (Linux Syslog)
# -------------------------
resource "azurerm_monitor_data_collection_rule" "dcr_linux_syslog" {
  name                = "${var.name}-dcr-linux-syslog"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "Linux"
  tags                = var.tags

  destinations {
    log_analytics {
      name                  = "law"
      workspace_resource_id = azurerm_log_analytics_workspace.law.id
    }
  }

  data_sources {
    syslog {
      name           = "syslog"
      facility_names = ["auth", "authpriv", "daemon", "user"]
      log_levels     = ["Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["law"]
  }
}

resource "azurerm_monitor_data_collection_rule_association" "dcr_assoc" {
  for_each = { for k, v in var.linux_vm_ids : k => v if try(v, "") != "" }

  name                    = "${var.name}-dcr-${each.key}"
  target_resource_id      = each.value
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr_linux_syslog.id
}



# -------------------------
# Sentinel detections (Scheduled Analytics Rules)
# -------------------------
resource "azurerm_sentinel_alert_rule_scheduled" "ssh_bruteforce" {
  name                       = "${var.name}-ssh-bruteforce"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  display_name               = "SOC Lab - SSH brute force attempts"
  severity                   = "High"
  enabled                    = true

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel]

  query = <<-KQL
Syslog
| where ProcessName in ("sshd", "ssh")
| where SyslogMessage has "Failed password" or SyslogMessage has "Failed publickey" or SyslogMessage has "Invalid user"
| summarize Attempts=count(), Hosts=dcount(Computer) by SourceIP=tostring(extract(@"from ([^ ]+)", 1, SyslogMessage)), bin(TimeGenerated, 5m)
| where Attempts >= 8
KQL

  query_frequency   = "PT5M"
  query_period      = "PT30M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      reopen_closed_incidents = false
      lookback_duration       = "PT1H"
      entity_matching_method  = "AllEntities"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "SourceIP"
    }
  }
}

resource "azurerm_sentinel_alert_rule_scheduled" "new_user" {
  name                       = "${var.name}-new-user"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  display_name               = "SOC Lab - New local user created"
  severity                   = "Medium"
  enabled                    = true

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel]

  query = <<-KQL
Syslog
| where SyslogMessage has_any ("useradd", "new user", "adduser")
| summarize Events=count() by Computer, bin(TimeGenerated, 10m)
| where Events >= 1
KQL

  query_frequency   = "PT5M"
  query_period      = "PT1H"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      reopen_closed_incidents = false
      lookback_duration       = "PT4H"
      entity_matching_method  = "AllEntities"
    }
  }
}

resource "azurerm_sentinel_alert_rule_scheduled" "nsg_denies_spike" {
  name                       = "${var.name}-nsg-denies"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  display_name               = "SOC Lab - NSG deny spike"
  severity                   = "Medium"
  enabled                    = true

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel]

  query = <<-KQL
AzureDiagnostics
| where tostring(column_ifexists("Category", "")) == "NetworkSecurityGroupRuleCounter"
   or tostring(column_ifexists("Category_s", "")) == "NetworkSecurityGroupRuleCounter"
| extend props = parse_json(tostring(column_ifexists("properties_s", "{}")))
| extend Action = tostring(props.type),
         MatchedConnections = toint(props.matchedConnections)
| where Action == "Deny"
| summarize DenyConnections = sum(MatchedConnections) by NSG=_ResourceId, bin(TimeGenerated, 5m)
| where DenyConnections >= 50
KQL


  query_frequency   = "PT5M"
  query_period      = "PT30M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      reopen_closed_incidents = false
      lookback_duration       = "PT2H"
      entity_matching_method  = "AllEntities"
    }
  }
}
