from fastapi import FastAPI, Response
from fastapi.responses import PlainTextResponse
import subprocess
import os

app = FastAPI()
SCRIPT_DIR = os.getenv("SCRIPT_DIR", "/scripts")

@app.get("/run/{script_name}", response_class=PlainTextResponse)
async def run_script(script_name: str):
    script_path = os.path.join(SCRIPT_DIR, script_name)

    if not os.path.exists(script_path):
        return Response(
            content="Script not found",
            status_code=404,
            media_type="text/plain"
        )

    try:
        # Make script executable
        os.chmod(script_path, 0o755)
        
        # Run script and capture output
        result = subprocess.run(
            ["/bin/bash", script_path],
            capture_output=True,
            text=True,
            env={"TERM": "xterm-256color"}  # Enable color output
        )
        
        # Return the output directly
        return result.stdout or result.stderr
        
    except Exception as e:
        return Response(
            content=f"Error executing script: {str(e)}",
            status_code=500,
            media_type="text/plain"
        )
