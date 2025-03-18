from fastapi import FastAPI
import subprocess
import os

app = FastAPI()
SCRIPT_DIR = os.getenv("SCRIPT_DIR", "/scripts")

@app.get("/run/{script_name}")
def run_script(script_name: str):
    script_path = os.path.join(SCRIPT_DIR, script_name)

    if not os.path.exists(script_path):
        return {"error": "Script not found"}

    try:
        result = subprocess.run(["/bin/bash", script_path], capture_output=True, text=True)
        return {"output": result.stdout, "error": result.stderr}
    except Exception as e:
        return {"error": str(e)}
