from fastapi import FastAPI, Response
from fastapi.responses import PlainTextResponse
import subprocess
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()
SCRIPT_DIR = os.getenv("SCRIPT_DIR", "/scripts")

@app.get("/run/{script_name}", response_class=PlainTextResponse)
async def run_script(script_name: str):
    script_path = os.path.join(SCRIPT_DIR, script_name)
    
    # Log the script path for debugging
    logger.info(f"Looking for script at: {script_path}")
    
    if not os.path.exists(script_path):
        logger.error(f"Script not found at: {script_path}")
        return Response(
            content=f"Script not found at: {script_path}",
            status_code=404,
            media_type="text/plain"
        )

    try:
        # Make script executable
        os.chmod(script_path, 0o755)
        logger.info(f"Script permissions set: {script_path}")
        
        # Run script and capture output
        result = subprocess.run(
            ["/bin/bash", script_path],
            capture_output=True,
            text=True,
            env={"TERM": "xterm-256color"}  # Enable color output
        )
        
        # Log the output for debugging
        if result.stdout:
            logger.info("Script stdout: %s", result.stdout)
        if result.stderr:
            logger.error("Script stderr: %s", result.stderr)
        
        # Return the output directly
        return result.stdout or result.stderr
        
    except Exception as e:
        logger.error(f"Error executing script: {str(e)}")
        return Response(
            content=f"Error executing script: {str(e)}",
            status_code=500,
            media_type="text/plain"
        )
