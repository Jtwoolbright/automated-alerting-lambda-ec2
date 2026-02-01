# EC2 Auto-Reboot with Lambda and Sumo Logic Alert

## Overview

This project automatically reboots an EC2 instance when triggered by a simulated Sumo Logic alert. The infrastructure is deployed using Terraform.

**Components:**
- Lambda Function (Python 3.11) - Reboots EC2 instance and sends notifications
- EC2 Instance (t2.micro) - Target instance for reboot
- SNS Topic - Email notifications for reboot events
- IAM Role & Policies - Lambda permissions
- Sumo Logic Monitor (Optional) - Detects slow API response times

## Architecture

```
Sumo Logic Alert → Lambda Function → EC2 Reboot + SNS Notification
```

## Prerequisites

- Terraform v1.14+
- AWS CLI configured with credentials
- Python 3.11

## Project Structure

```
.
├── lambda/
│   └── lambda_function.py
│   └── events.json
├── sumo_logic/
│   └── sumo_logic_alert.tf
│   └── sumo_logic_query.tf
├── terraform/
│   ├── main.tf
│   ├── provider.tf
└── README.md
```

## Quick Start

1. **Update Configuration**
   - Edit SNS email address in `main.tf`
   - Update AWS region and AMI ID if needed

2. **Deploy Infrastructure**
   ```bash
   cd terraform/
   terraform init
   terraform apply
   ```

3. **Confirm SNS Subscription**
   - Check email and click confirmation link

4. **Test Lambda Function**
   ```bash
   aws lambda invoke \
     --function-name ec2-reboot-function \
     --payload file://lambda/events.json \
     --cli-binary-format raw-in-base64-out \
     response.json
   ```

## Sumo Logic Query (Optional)

Query to detect `/api/data` endpoint response times > 3 seconds:

```
_sourceCategory=application/logs "/api/data"
| parse "response_time=*ms" as response_time_ms
| where response_time_ms > 3000
| count by _timeslice, response_time_ms
```

## Cleanup

```bash
terraform destroy
```

---

**Terraform Version**: 1.14  
**Python Runtime**: 3.11