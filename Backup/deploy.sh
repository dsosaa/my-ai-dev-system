#!/usr/bin/env bash
#
# ECS/Fargate Deployment Script with Enhanced Debugging
# - Checks Docker, AWS CLI, IAM roles, network config
# - Builds/pushes Docker image (optional build)
# - Registers/updates ECS Service
# - Custom wait loop with debug info (stopReasons, ECS events)
#
# NOTE: This script uses 'jq' for JSON parsing. If you don't have 'jq' installed,
#       you can install it via your package manager (e.g. 'brew install jq' on macOS).

set -euo pipefail

########################################
#          USER CONFIGURATION
########################################
AWS_ACCOUNT_ID="108613986753"
AWS_REGION="us-west-2"
ECR_REPO="my-ai-dev-system"

ECS_CLUSTER="my-ai-cluster"
ECS_TASK="my-ai-task"
ECS_SERVICE="my-ai-service"

SUBNETS="subnet-015cd8eef389cc15f,subnet-0cb4b289cb9118ec9,subnet-056c2e97fdadb6739,subnet-07f8e24b141a67c9f"
SECURITY_GROUP="sg-0ba13788585c194be"

CONTAINER_NAME="my-ai-container"
CONTAINER_PORT="3001"
DESIRED_COUNT=1
FARGATE_CPU="256"
FARGATE_MEMORY="512"

# IAM Role we expect to use for ECS Task Execution
ECS_TASK_EXECUTION_ROLE_NAME="ecsTaskExecutionRole"
ECS_TASK_EXECUTION_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ECS_TASK_EXECUTION_ROLE_NAME}"

# How long (in seconds) to wait for the service to become stable
MAX_WAIT_TIME=600  # 10 minutes
CHECK_INTERVAL=20  # check every 20 seconds

# Check that "jq" is installed (for JSON parsing)
if ! command -v jq &>/dev/null; then
  echo "❌ 'jq' utility not found. Please install 'jq' for JSON parsing."
  exit 1
fi

########################################
#     0. PRE-FLIGHT CHECKS
########################################

# Check AWS CLI is installed
if ! command -v aws &> /dev/null; then
  echo "❌ AWS CLI not found. Please install AWS CLI before running this script."
  exit 1
fi

# Verify AWS CLI is configured and we have valid credentials
echo "🔍 Checking AWS CLI authentication..."
if ! aws sts get-caller-identity --region "$AWS_REGION" &> /dev/null; then
  echo "❌ AWS CLI is not authenticated. Run 'aws configure' or ensure your credentials are valid."
  exit 1
fi

########################################
# 1. CHECK DOCKER INSTALLATION
########################################

if ! command -v docker &> /dev/null; then
  echo "❌ Docker is not installed or not found in PATH. Please install Docker."
  exit 1
fi

########################################
# 2. VALIDATE IAM ROLE FOR ECS TASK
########################################

echo "🔎 Checking if IAM role [$ECS_TASK_EXECUTION_ROLE_NAME] exists..."
ROLE_CHECK=$(aws iam get-role --role-name "$ECS_TASK_EXECUTION_ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null || true)
if [[ -z "$ROLE_CHECK" ]]; then
  echo "⚠️  IAM role [$ECS_TASK_EXECUTION_ROLE_NAME] not found."
  echo "   Please create the role with the correct trust policy and permissions (AmazonECSTaskExecutionRolePolicy)."
  echo "   Exiting to avoid deployment issues."
  exit 1
else
  echo "✅ IAM role [$ECS_TASK_EXECUTION_ROLE_NAME] exists."
fi

########################################
# 3. VALIDATE NETWORK CONFIGURATION
########################################

IFS=',' read -r -a SUBNET_ARRAY <<< "$SUBNETS"

echo "🔎 Validating that subnets exist..."
for subnet_id in "${SUBNET_ARRAY[@]}"; do
  SUBNET_CHECK=$(aws ec2 describe-subnets --subnet-ids "$subnet_id" --region "$AWS_REGION" 2>/dev/null || true)
  if [[ -z "$SUBNET_CHECK" ]]; then
    echo "❌ Subnet [$subnet_id] does not exist or is invalid in region [$AWS_REGION]."
    exit 1
  fi
done
echo "✅ All subnets found."

echo "🔎 Validating that security group [$SECURITY_GROUP] exists..."
SG_CHECK=$(aws ec2 describe-security-groups --group-ids "$SECURITY_GROUP" --region "$AWS_REGION" 2>/dev/null || true)
if [[ -z "$SG_CHECK" ]]; then
  echo "❌ Security group [$SECURITY_GROUP] not found or you lack permission."
  exit 1
fi
echo "✅ Security group [$SECURITY_GROUP] exists."

########################################
# 4. ENSURE ECR REPOSITORY EXISTS
########################################

echo "🔍 Checking if ECR repository [$ECR_REPO] exists..."
if ! aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" &> /dev/null; then
  echo "📌 ECR repository [$ECR_REPO] not found. Creating..."
  aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION" >/dev/null
  echo "✅ ECR repository [$ECR_REPO] created."
else
  echo "✅ ECR repository [$ECR_REPO] already exists."
fi

########################################
# 5. CHECK LOCAL DOCKER IMAGE + PUSH
########################################

# If needed, build Docker image here, e.g.:
# echo "🔨 Building Docker image locally..."
# docker build -t "${ECR_REPO}:latest" .

echo "🔎 Checking if local Docker image [${ECR_REPO}:latest] exists..."
LOCAL_IMAGE=$(docker images -q "${ECR_REPO}:latest" || true)
if [[ -z "$LOCAL_IMAGE" ]]; then
  echo "❌ Local Docker image [${ECR_REPO}:latest] does not exist. Build the image before running this script."
  exit 1
fi
echo "✅ Found local Docker image [${ECR_REPO}:latest]."

echo "🔑 Logging into ECR..."
LOGIN_OUTPUT=$(aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" 2>&1)
if [[ $? -ne 0 ]]; then
  echo "❌ Docker login to ECR failed. Output:"
  echo "$LOGIN_OUTPUT"
  exit 1
fi
echo "✅ Successfully logged into ECR."

echo "🔍 Checking ECR for existing 'latest' image..."
ECR_LIST=$(aws ecr list-images \
  --repository-name "$ECR_REPO" \
  --region "$AWS_REGION" \
  --query 'imageIds[].imageTag' \
  --output text 2>/dev/null || true)

if [[ "$ECR_LIST" =~ "latest" ]]; then
  echo "✅ 'latest' tag is present in ECR. (You may still want to push if you've updated locally.)"
else
  echo "📌 No 'latest' Docker image found in ECR. Pushing local image..."
  docker tag "${ECR_REPO}:latest" "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest"
  docker push "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest"
  echo "✅ Docker image pushed to ECR."
fi

########################################
# CREATE ECS CLUSTER IF NEEDED
########################################

echo "🔎 Checking ECS cluster [$ECS_CLUSTER]..."
CLUSTER_STATUS=$(aws ecs describe-clusters \
  --clusters "$ECS_CLUSTER" \
  --region "$AWS_REGION" \
  --query 'clusters[0].status' \
  --output text 2>/dev/null || true)

if [[ "$CLUSTER_STATUS" != "ACTIVE" ]]; then
  echo "📌 ECS cluster [$ECS_CLUSTER] not found or inactive. Creating..."
  aws ecs create-cluster --cluster-name "$ECS_CLUSTER" --region "$AWS_REGION" >/dev/null
  echo "✅ ECS cluster [$ECS_CLUSTER] created."
else
  echo "✅ ECS cluster [$ECS_CLUSTER] already exists."
fi

########################################
# REGISTER TASK DEFINITION
########################################

echo "📌 Registering Task Definition [$ECS_TASK]..."

TASK_DEFINITION_JSON=$(cat <<EOF
[
  {
    "name": "$CONTAINER_NAME",
    "image": "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest",
    "cpu": $FARGATE_CPU,
    "memory": $FARGATE_MEMORY,
    "essential": true,
    "portMappings": [
      {
        "containerPort": $CONTAINER_PORT,
        "hostPort": $CONTAINER_PORT
      }
    ]
  }
]
EOF
)

# OPTIONAL: Uncomment to see the JSON:
# echo "$TASK_DEFINITION_JSON"

aws ecs register-task-definition \
  --family "$ECS_TASK" \
  --network-mode awsvpc \
  --requires-compatibilities FARGATE \
  --cpu "$FARGATE_CPU" \
  --memory "$FARGATE_MEMORY" \
  --execution-role-arn "$ECS_TASK_EXECUTION_ROLE_ARN" \
  --container-definitions "$TASK_DEFINITION_JSON" \
  --region "$AWS_REGION" >/dev/null

echo "✅ Task Definition [$ECS_TASK] registered."

########################################
# CREATE OR UPDATE THE SERVICE
########################################

echo "🚀 Deploying ECS Service [$ECS_SERVICE]..."

SERVICE_STATUS=$(aws ecs describe-services \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --region "$AWS_REGION" \
  --query 'services[0].status' \
  --output text 2>/dev/null || true)

if [[ "$SERVICE_STATUS" == "ACTIVE" ]]; then
  echo "🔄 Service [$ECS_SERVICE] already exists. Updating..."
  aws ecs update-service \
    --cluster "$ECS_CLUSTER" \
    --service "$ECS_SERVICE" \
    --task-definition "$ECS_TASK" \
    --desired-count "$DESIRED_COUNT" \
    --region "$AWS_REGION" >/dev/null
  echo "✅ Service [$ECS_SERVICE] updated."
elif [[ "$SERVICE_STATUS" == "INACTIVE" ]]; then
  echo "📌 Service [$ECS_SERVICE] is INACTIVE. Creating a new service..."
  aws ecs create-service \
    --cluster "$ECS_CLUSTER" \
    --service-name "$ECS_SERVICE" \
    --task-definition "$ECS_TASK" \
    --launch-type FARGATE \
    --desired-count "$DESIRED_COUNT" \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=ENABLED}" \
    --region "$AWS_REGION" >/dev/null
  echo "✅ Service [$ECS_SERVICE] created."
else
  echo "📌 Service [$ECS_SERVICE] not found. Creating..."
  aws ecs create-service \
    --cluster "$ECS_CLUSTER" \
    --service-name "$ECS_SERVICE" \
    --task-definition "$ECS_TASK" \
    --launch-type FARGATE \
    --desired-count "$DESIRED_COUNT" \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=ENABLED}" \
    --region "$AWS_REGION" >/dev/null
  echo "✅ Service [$ECS_SERVICE] created."
fi

########################################
# CUSTOM WAIT LOOP FOR SERVICE STABILITY
########################################

echo "⏳ Waiting up to $MAX_WAIT_TIME seconds for ECS Service [$ECS_SERVICE] to become stable..."

START_TIME=$(date +%s)
STABLE="false"

while true; do
  SERVICE_DESC=$(aws ecs describe-services \
    --cluster "$ECS_CLUSTER" \
    --services "$ECS_SERVICE" \
    --region "$AWS_REGION" \
    --query 'services[0]' \
    --output json)
  
  CURRENT_RUNNING_COUNT=$(echo "$SERVICE_DESC" | jq -r '.runningCount')
  CURRENT_DESIRED_COUNT=$(echo "$SERVICE_DESC" | jq -r '.desiredCount')
  CURRENT_STATUS=$(echo "$SERVICE_DESC" | jq -r '.status')
  CURRENT_DEPLOYMENTS=$(echo "$SERVICE_DESC" | jq -r '.deployments | length')
  
  echo "  - Service status: $CURRENT_STATUS"
  echo "  - Running count:  $CURRENT_RUNNING_COUNT"
  echo "  - Desired count:  $CURRENT_DESIRED_COUNT"
  
  # If the runningCount == desiredCount and only 1 active deployment, we consider it stable
  if [[ "$CURRENT_RUNNING_COUNT" == "$CURRENT_DESIRED_COUNT" && "$CURRENT_DEPLOYMENTS" == "1" ]]; then
    echo "✅ Service is stable (runningCount == desiredCount)."
    STABLE="true"
    break
  fi
  
  # If runningCount < desiredCount, tasks might be failing. Check STOPPED tasks:
  if [[ "$CURRENT_RUNNING_COUNT" -lt "$CURRENT_DESIRED_COUNT" ]]; then
    echo "⚠️  Some tasks may be failing to start. Checking STOPPED tasks..."
    
    STOPPED_TASKS=$(aws ecs list-tasks \
      --cluster "$ECS_CLUSTER" \
      --service-name "$ECS_SERVICE" \
      --desired-status STOPPED \
      --region "$AWS_REGION" \
      --query 'taskArns' \
      --output json)
    
    if [[ "$STOPPED_TASKS" != "[]" ]]; then
      echo "🔎 Found stopped tasks. Describing reasons..."
      STOPPED_TASK_ARN_ARRAY=$(echo "$STOPPED_TASKS" | jq -r '.[]')
      for TASK_ARN in $STOPPED_TASK_ARN_ARRAY; do
        STOP_REASON=$(aws ecs describe-tasks \
          --cluster "$ECS_CLUSTER" \
          --tasks "$TASK_ARN" \
          --region "$AWS_REGION" \
          --query 'tasks[0].stopReason' \
          --output text)
        echo "   - Task [$TASK_ARN] stopped reason: $STOP_REASON"
      done
    else
      echo "   - No STOPPED tasks found yet."
    fi
  fi
  
  # Print recent ECS events (helpful for diagnosing capacity/image/permission issues)
  echo "🔎 Checking recent ECS events..."
  aws ecs describe-services \
    --cluster "$ECS_CLUSTER" \
    --services "$ECS_SERVICE" \
    --region "$AWS_REGION" \
    --query "services[0].events[0:5].[createdAt,message]" \
    --output table || true
  
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))
  if [[ "$ELAPSED" -ge "$MAX_WAIT_TIME" ]]; then
    echo "❌ Timed out after $MAX_WAIT_TIME seconds waiting for service to become stable."
    echo "   Please check ECS console, logs, or the STOPPED task reasons above."
    exit 1
  fi
  
  echo "😴 Waiting $CHECK_INTERVAL seconds before next check..."
  sleep "$CHECK_INTERVAL"
done

if [[ "$STABLE" == "true" ]]; then
  echo "🔎 Retrieving public IP of the running task..."
  
  TASK_ARN=$(aws ecs list-tasks \
    --cluster "$ECS_CLUSTER" \
    --service-name "$ECS_SERVICE" \
    --desired-status RUNNING \
    --region "$AWS_REGION" \
    --query 'taskArns[0]' \
    --output text)
  
  if [[ -z "$TASK_ARN" || "$TASK_ARN" == "None" ]]; then
    echo "❌ No running tasks found for service [$ECS_SERVICE] after stability check."
    exit 1
  fi
  
  ENI_ID=$(aws ecs describe-tasks \
    --cluster "$ECS_CLUSTER" \
    --tasks "$TASK_ARN" \
    --region "$AWS_REGION" \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text)
  
  PUBLIC_IP=$(aws ec2 describe-network-interfaces \
    --region "$AWS_REGION" \
    --network-interface-ids "$ENI_ID" \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --output text)
  
  if [[ -z "$PUBLIC_IP" || "$PUBLIC_IP" == "None" ]]; then
    echo "❌ Could not find a public IP. Ensure subnets & security groups allow public IP assignment."
    exit 1
  fi
  
  echo "✅ Application is accessible at: http://$PUBLIC_IP:$CONTAINER_PORT"
  
  ########################################
  # OPTIONAL: TEST THE API
  ########################################
  TEST_ENDPOINT="http://$PUBLIC_IP:$CONTAINER_PORT/status"
  echo "🔬 Testing the API endpoint: $TEST_ENDPOINT"
  
  if ! curl -sf "$TEST_ENDPOINT" >/dev/null; then
    echo "⚠️  API might not be responding at [$TEST_ENDPOINT]. Check ECS logs or your application."
  else
    echo "✅ API responded successfully at [$TEST_ENDPOINT]."
  fi
  
  echo "🎉 Deployment script completed successfully!"
else
  echo "❌ Service never became stable. Check ECS console for details."
  exit 1
fi