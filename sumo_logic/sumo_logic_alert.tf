terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    sumologic = {
      source  = "SumoLogic/sumologic"
      version = "~> 2.28"
    }
  }
}

provider "sumologic" {
  access_id   = var.sumologic_access_id
  access_key  = var.sumologic_access_key
  environment = "us2"  # Change to your Sumo Logic deployment (us1, us2, eu, etc.)
}

variable "sumologic_access_id" {
  description = "Sumo Logic Access ID"
  type        = string
  sensitive   = true
}

variable "sumologic_access_key" {
  description = "Sumo Logic Access Key"
  type        = string
  sensitive   = true
}

# Sumo Logic Monitor (Alert)
resource "sumologic_monitor" "api_response_time_alert" {
  name        = "API Data Endpoint - High Response Time"
  description = "Alert when /api/data endpoint response time exceeds 3 seconds"
  type        = "MonitorsLibraryMonitor"
  is_disabled = false
  
  # Alert grouping
  group_notifications = true
  
  # Monitor queries
  queries {
    row_id = "A"
    query  = <<-EOQ
        _sourceCategory=application/logs "/api/data"
        | parse "response_time=*ms" as response_time_ms
        | where response_time_ms > 3000
        | count by _timeslice, response_time_ms
    EOQ
  }
  
  # Trigger conditions
  triggers {
    threshold_type   = "GreaterThan"
    threshold        = 0
    time_range       = "15m"
    occurrence_type  = "ResultCount"
    trigger_source   = "AllResults"
    trigger_type     = "Critical"
    detection_method = "StaticCondition"
    
    resolution_window = "5m"
  }
  
  # Notification configuration - Webhook to trigger Lambda
  notifications {
    notification {
      connection_type = "Webhook"
      connection_id   = sumologic_connection.lambda_webhook.id
      
      payload_override = jsonencode({
        SearchName        = "{{SearchName}}"
        SearchDescription = "{{SearchDescription}}"
        SearchQuery       = "{{SearchQuery}}"
        SearchQueryUrl    = "{{SearchQueryUrl}}"
        TriggerType       = "{{TriggerType}}"
        TriggerTimeRange  = "{{TriggerTimeRange}}"
        TriggerTime       = "{{TriggerTime}}"
        TriggerCondition  = "{{TriggerCondition}}"
        TriggerValue      = "{{TriggerValue}}"
        NumRawResults     = "{{NumRawResults}}"
        Alert = {
          Name     = "{{Name}}"
          ID       = "{{AlertId}}"
          Severity = "{{TriggerType}}"
        }
      })
    }
  }
  
  monitor_type = "Logs"
  evaluation_delay = "0m"
}

# Webhook Connection to Lambda (requires API Gateway - we'll create this next)
resource "sumologic_connection" "lambda_webhook" {
  name        = "Lambda EC2 Reboot Webhook"
  description = "Webhook connection to trigger Lambda function for EC2 reboot"
  type        = "WebhookConnection"
  
  webhook_type = "Webhook"
  url          = aws_apigatewayv2_stage.lambda_stage.invoke_url
  
  default_payload = jsonencode({
    source = "SumoLogic"
  })
}