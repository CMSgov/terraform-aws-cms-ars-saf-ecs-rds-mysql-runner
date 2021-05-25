{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": ["${cloudwatch_arn}:*"]
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": [
        "${repo_arn}"
      ]
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:${partition}:secretsmanager:${region}:${caller_id}:secret:/${app_name}-${environment}*",
        "arn:${partition}:secretsmanager:${region}:${caller_id}:secret:macbis/${environment}/saf-rds*"
      ]
    },
    %{ if secretsManager_arn == ""}
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters"
      ],
      "Resource": [
        "${username_arn}",
        "${password_arn}",
        "${hostname_arn}"
      ]
    },
    %{ endif }
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": [
        "${kms_key_arn}"
      ]
    }
  ]
}