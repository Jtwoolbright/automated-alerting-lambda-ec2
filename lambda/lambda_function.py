import json
import boto3
import os

ec2_client = boto3.client('ec2')
sns_client = boto3.client('sns')

def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    
    # Get environment variables
    instance_id = os.environ.get('EC2_INSTANCE_ID')
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
    
    if not instance_id:
        return {
            'statusCode': 400,
            'body': json.dumps('EC2_INSTANCE_ID environment variable not set')
        }
    
    try:
        # Reboot the EC2 instance
        print(f"Rebooting instance: {instance_id}")
        ec2_client.reboot_instances(InstanceIds=[instance_id])
        
        # Prepare SNS message
        message = f"""
        EC2 Instance Reboot Triggered

        Instance ID: {instance_id}
        Trigger Event: {json.dumps(event, indent=2)}
        Status: Reboot command sent successfully
        """
        
        # Send SNS notification
        if sns_topic_arn:
            sns_client.publish(
                TopicArn=sns_topic_arn,
                Subject='EC2 Instance Reboot Alert',
                Message=message
            )
            print(f"SNS notification sent to {sns_topic_arn}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(f'Successfully rebooted instance {instance_id}')
        }
        
    except Exception as e:
        error_message = f"Error rebooting instance {instance_id}: {str(e)}"
        print(error_message)
        
        # Send error notification to SNS
        if sns_topic_arn:
            sns_client.publish(
                TopicArn=sns_topic_arn,
                Subject='EC2 Instance Reboot Failed',
                Message=error_message
            )
        
        return {
            'statusCode': 500,
            'body': json.dumps(error_message)
        }