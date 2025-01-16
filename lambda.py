import boto3
import urllib3
import json
import os
region = "${aws_region}"
instances = ["${aws_instance}"]
ec2 = boto3.client('ec2', region_name=region)
webhook_url = os.environ.get('DISCORD_WEBHOOK')

def lambda_handler(event, context):
    status=""
    try:
      instance_state = ec2.describe_instance_status(InstanceIds=[instances[0]], IncludeAllInstances=True)

      if instance_state == "running":
          print('Server already running.')
          status = "already running."
      else:
          print('Starting your Satisfactory server...')
          ec2.start_instances(InstanceIds=instances)
          status = "starting up."
    except Exception as e:
      print('Failed to start Satisfactory server.')
      status = "failing to start."
    webhook_content = {
      "content": status,
      "username": "Ficsit Corp",
      "embeds": [{
        "title": "AWS Instance Status",
        "description": "Instance is "+status,
        "color": "45973"
      }]
      } 

    http = urllib3.PoolManager()
    webhook = http.request('POST',
                        webhook_url,
                        body = json.dumps(webhook_content),
                        headers = {'Content-Type': 'application/json'},
                        retries = False)

