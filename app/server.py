from fastapi import FastAPI, Response
from fastapi.responses import PlainTextResponse
import subprocess
import os
import logging
import stat

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
        current_mode = os.stat(script_path).st_mode
        os.chmod(script_path, current_mode | stat.S_IEXEC)
        logger.info(f"Script permissions set: {script_path}")
        
        # Set up environment variables
        env = {
            "HOME": "/root",
            "TERM": "xterm-256color",
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "USER": "root",
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
            "SSH_KEY_PATH": "/root/.ssh/id_ED25519"
        }
        
        # Create .ssh directory if it doesn't exist
        os.makedirs("/root/.ssh", exist_ok=True)
        os.chmod("/root/.ssh", 0o700)
        
        # Run script and capture output
        result = subprocess.run(
            ["/bin/bash", script_path],
            capture_output=True,
            text=True,
            env=env
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
