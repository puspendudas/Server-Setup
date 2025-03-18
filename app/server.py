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
        # Read and return the script content directly
        with open(script_path, 'r') as f:
            content = f.read()
            
        # Set proper headers for script download
        return Response(
            content=content,
            media_type="text/plain",
            headers={
                "Content-Disposition": f'attachment; filename="{script_name}"'
            }
        )
        
    except Exception as e:
        logger.error(f"Error reading script: {str(e)}")
        return Response(
            content=f"Error reading script: {str(e)}",
            status_code=500,
            media_type="text/plain"
        )
