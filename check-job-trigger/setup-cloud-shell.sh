#!/bin/bash
# Run this script in Google Cloud Shell to set up the Cloud Function

set -e

echo "Setting up Cloud Function wrapper for Cloud Run Job..."

# Create directory
mkdir -p ~/check-job-trigger
cd ~/check-job-trigger

# Create package.json
cat > package.json << 'EOF'
{
  "name": "check-job-trigger",
  "version": "1.0.0",
  "description": "Cloud Function to check if Cloud Run Job is running before triggering",
  "main": "index.js",
  "dependencies": {
    "@google-cloud/run": "^3.0.0"
  }
}
EOF

# Create index.js
cat > index.js << 'EOF'
const {run_v1} = require('@google-cloud/run');

exports.checkAndTriggerJob = async (req, res) => {
  const projectId = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || 'exploration-dev-417917';
  const region = 'us-east1';
  const jobName = 'ekubo-indexer-starknet-mainnet';
  
  const client = new run_v1.JobsClient();
  const parent = `projects/${projectId}/locations/${region}`;
  const name = `${parent}/jobs/${jobName}`;
  
  try {
    console.log(`Checking for running executions of job: ${jobName}`);
    
    // List recent executions
    const [executions] = await client.listExecutions({
      parent: name,
      pageSize: 5,
    });
    
    // Check if any execution is currently running
    const runningExecution = executions.find(exec => {
      const conditions = exec.status?.conditions || [];
      const completed = conditions.find(c => c.type === 'Completed');
      const started = conditions.find(c => c.type === 'Started');
      
      // Execution is running if it's started but not completed
      return started?.status === 'True' && (!completed || completed.status !== 'True');
    });
    
    if (runningExecution) {
      console.log(`Job already running: ${runningExecution.name}`);
      res.status(200).json({
        message: 'Job already running, skipping trigger',
        runningExecution: runningExecution.name,
        timestamp: new Date().toISOString(),
      });
      return;
    }
    
    // No job running, trigger a new one
    console.log('No job running, triggering new execution...');
    const [execution] = await client.runJob({
      name: name,
    });
    
    console.log(`Job execution triggered: ${execution.name}`);
    res.status(200).json({
      message: 'Job execution triggered',
      execution: execution.name,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ 
      error: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString(),
    });
  }
};
EOF

# Create .gcloudignore
cat > .gcloudignore << 'EOF'
node_modules/
.git/
*.log
.env
.env.local
EOF

echo "Files created. Deploying Cloud Function..."

# Deploy the function
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

echo ""
echo "Cloud Function deployed successfully!"
echo ""

# Get the function URL
FUNCTION_URL=$(gcloud functions describe check-and-trigger-job --gen2 --region us-east1 --format="value(serviceConfig.uri)")

echo "Function URL: $FUNCTION_URL"
echo ""

# Enable Cloud Scheduler API if needed
gcloud services enable cloudscheduler.googleapis.com --quiet

# Check if scheduler already exists
if gcloud scheduler jobs describe ekubo-indexer-starknet-mainnet-scheduler --location us-east1 &>/dev/null 2>&1; then
  echo "Updating existing Cloud Scheduler job..."
  gcloud scheduler jobs update http ekubo-indexer-starknet-mainnet-scheduler \
    --location us-east1 \
    --schedule="*/5 * * * *" \
    --uri="$FUNCTION_URL" \
    --http-method GET \
    --time-zone "UTC" \
    --description "Checks if job is running and triggers if not"
else
  echo "Creating new Cloud Scheduler job..."
  gcloud scheduler jobs create http ekubo-indexer-starknet-mainnet-scheduler \
    --location us-east1 \
    --schedule="*/5 * * * *" \
    --uri="$FUNCTION_URL" \
    --http-method GET \
    --time-zone "UTC" \
    --description "Checks if job is running and triggers if not"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "The scheduler will check every 5 minutes if the job is running."
echo "If no job is running, it will trigger a new execution."
echo ""
echo "Test the function manually:"
echo "curl $FUNCTION_URL"

