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

