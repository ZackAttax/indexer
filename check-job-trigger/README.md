# Cloud Function Job Trigger Wrapper

This Cloud Function checks if a Cloud Run Job is currently running before triggering a new execution, ensuring only one job runs at a time.

## Setup Instructions for Cloud Shell

1. **Create the function directory in Cloud Shell:**
```bash
mkdir -p ~/check-job-trigger
cd ~/check-job-trigger
```

2. **Create the files** (copy the contents from the local files, or use the commands below)

3. **Deploy the function:**
```bash
chmod +x deploy.sh
./deploy.sh
```

Or deploy manually:
```bash
export PROJECT_ID=$(gcloud config get-value project)
gcloud functions deploy check-and-trigger-job \
  --gen2 \
  --runtime nodejs20 \
  --region us-east1 \
  --entry-point checkAndTriggerJob \
  --trigger-http \
  --allow-unauthenticated \
  --set-env-vars GCP_PROJECT=$PROJECT_ID \
  --source .
```

4. **The deploy script will automatically set up Cloud Scheduler**

## Manual Scheduler Setup

If you need to set up the scheduler manually:

```bash
export PROJECT_ID=$(gcloud config get-value project)
FUNCTION_URL=$(gcloud functions describe check-and-trigger-job --gen2 --region us-east1 --format="value(serviceConfig.uri)")

gcloud scheduler jobs create http ekubo-indexer-starknet-mainnet-scheduler \
  --location us-east1 \
  --schedule="*/5 * * * *" \
  --uri="$FUNCTION_URL" \
  --http-method GET \
  --time-zone "UTC" \
  --description "Checks if job is running and triggers if not"
```

## Testing

Test the function manually:
```bash
FUNCTION_URL=$(gcloud functions describe check-and-trigger-job --gen2 --region us-east1 --format="value(serviceConfig.uri)")
curl $FUNCTION_URL
```

## Schedule Options

- Every 1 minute: `"* * * * *"`
- Every 5 minutes: `"*/5 * * * *"`
- Every 10 minutes: `"*/10 * * * *"`

