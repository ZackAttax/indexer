#!/bin/bash
# Deployment script for Cloud Function wrapper

set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-east1"
FUNCTION_NAME="check-and-trigger-job"
JOB_NAME="ekubo-indexer-starknet-mainnet"

echo "Deploying Cloud Function: $FUNCTION_NAME"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"

# Deploy the Cloud Function
gcloud functions deploy $FUNCTION_NAME \
  --gen2 \
  --runtime nodejs20 \
  --region $REGION \
  --entry-point checkAndTriggerJob \
  --trigger-http \
  --allow-unauthenticated \
  --set-env-vars GCP_PROJECT=$PROJECT_ID \
  --source .

echo ""
echo "Cloud Function deployed successfully!"
echo ""

# Get the function URL
FUNCTION_URL=$(gcloud functions describe $FUNCTION_NAME --gen2 --region $REGION --format="value(serviceConfig.uri)")

echo "Function URL: $FUNCTION_URL"
echo ""

# Check if scheduler already exists
if gcloud scheduler jobs describe ekubo-indexer-starknet-mainnet-scheduler --location $REGION &>/dev/null; then
  echo "Updating existing Cloud Scheduler job..."
  gcloud scheduler jobs update http ekubo-indexer-starknet-mainnet-scheduler \
    --location $REGION \
    --schedule="*/5 * * * *" \
    --uri="$FUNCTION_URL" \
    --http-method GET \
    --time-zone "UTC" \
    --description "Checks if job is running and triggers if not"
else
  echo "Creating new Cloud Scheduler job..."
  gcloud scheduler jobs create http ekubo-indexer-starknet-mainnet-scheduler \
    --location $REGION \
    --schedule="*/5 * * * *" \
    --uri="$FUNCTION_URL" \
    --http-method GET \
    --time-zone "UTC" \
    --description "Checks if job is running and triggers if not"
fi

echo ""
echo "Setup complete!"
echo ""
echo "The scheduler will check every 5 minutes if the job is running."
echo "If no job is running, it will trigger a new execution."

