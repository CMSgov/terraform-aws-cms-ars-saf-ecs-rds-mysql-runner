[
  {
    "name": "${app_name}-${environment}-${task_name}",
    "image": "${repo_url}:${repo_tag}",
    "cpu": 128,
    "memory": 1024,
    "essential": true,
    "portMappings": [],
    "environment": [
      {"name": "s3_bucket_path", "value": "${s3_results_bucket}"},
      {"name": "PORT", "value": "${mysql_port}"},
      {"name": "RDSARN", "value": "${rdsARN}"},
      {"name": "PRODUCTARN", "value": "${productARN}"},
      {"name": "ACCOUNTID", "value": "${accountID}"},
      {"name": "MYSQL_VERSION", "value": "${mysql_version}"},
      {"name": "MYSQL_USERS", "value": "[${join(",",mysql_users)}]"},
      {"name": "WORKER_CONFIGURED", "value": "${tostring(worker_configured)}"},
      {"name": "ADMIN_USERS", "value": "[${join(",",admin_users)}]"},
      {"name": "READ_WRITE_USERS", "value": "[${join(",",read_write_users)}]"}
    ],
    %{ if secretsManager_arn == ""}
    "secrets": [
      {"name": "USERNAME", "valueFrom": "${username_arn}"},
      {"name": "PASSWORD", "valueFrom": "${password_arn}"},
      {"name": "HOSTNAME", "valueFrom": "${hostname_arn}"}
    ],
    %{ else }
    "secrets": [
      {"name": "RDS_CREDS", "valueFrom": "${secretsManager_arn}"}
    ],
    %{ endif }
    "logConfiguration": {
      "logDriver": "awslogs",
      "secretOptions": null,
      "options": {
        "awslogs-group": "${awslogs_group}",
        "awslogs-region": "${awslogs_region}",
        "awslogs-stream-prefix": "${app_name}"
      }
    },
    "mountPoints": [],
    "volumesFrom": [],
    "entryPoint": [
            "./profiles/scriptRunner.sh"
    ]
  }
]