# working-title

TBD

#1
the repo has to be created manually
aws ecr create-repository --repository-name wt --region us-east-1

# enable terraform still manage the repo even after manual creation

terraform import aws_ecr_repository.this wt

#2
the github actions role has to be created manually

aws iam create-open-id-connect-provider \
 --url https://token.actions.githubusercontent.com \
 --client-id-list sts.amazonaws.com \
 --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# incase u dont have the policy

cat > trust-policy.json <<EOF
{
"Version": "2012-10-17",
"Statement": [
{
"Effect": "Allow",
"Principal": {
"Federated": "arn:aws:iam::<your-account-id>:oidc-provider/token.actions.githubusercontent.com"
},
"Action": "sts:AssumeRoleWithWebIdentity",
"Condition": {
"StringEquals": {
"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
},
"StringLike": {
"token.actions.githubusercontent.com:sub": "repo:<your-github-username>/<your-repo-name>:*"
}
}
}
]
}
EOF

aws iam create-role \
 --role-name github-actions-role \
 --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
 --role-name github-actions-role \
 --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
