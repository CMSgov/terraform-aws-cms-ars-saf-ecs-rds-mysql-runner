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
        %{ if secretsManager_arn != ""}
        "${secretsManager_arn}",
        %{ endif }
        "arn:${partition}:secretsmanager:${region}:${caller_id}:secret:/${app_name}-${environment}*"
      ]
    %{ if secretsManager_arn == ""}
    },
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
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": [
        "${parameter_store_enc_kms_key}"
      ]
    %{ endif }
    }
  ]
}