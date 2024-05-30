cat > /tmp/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "$CC_AWS_ROLE"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role --role-name ClickHouseAccessRole-avin --assume-role-policy-document file:///tmp/trust-policy.json
  

cat > /tmp/s3-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:GetBucketLocation",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::avin-clickhouse"
            ],
            "Effect": "Allow"
        },
        {
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
                "arn:aws:s3:::avin-clickhouse/*"
            ],
            "Effect": "Allow"
        }
    ]
}
EOF

aws iam create-policy --policy-name avin-clickhouse-s3-policy --policy-document file:///tmp/s3-policy.json
aws iam attach-role-policy --policy-arn `aws iam list-policies --query 'Policies[?PolicyName==\`avin-clickhouse-s3-policy\`].Arn' --output text` --role-name ClickHouseAccessRole-avin
