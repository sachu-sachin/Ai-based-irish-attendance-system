import os
import subprocess
import signal

def kill_ghosts():
    print("Searching for ghost processes on port 8000...")
    try:
        # Find PIDs listening on 8000
        output = subprocess.check_output("netstat -ano | findstr :8000", shell=True).decode()
        pids = set()
        for line in output.strip().split('\n'):
            parts = line.split()
            if len(parts) > 4:
                pids.add(parts[-1])
        
        if not pids:
            print("No ghost processes found.")
            return

        print(f"Found PIDs: {pids}")
        for pid in pids:
            try:
                print(f"Killing PID {pid}...")
                os.system(f"taskkill /F /PID {pid}")
            except Exception as e:
                print(f"Could not kill {pid}: {e}")
                
        print("Port 8000 should be clear now.")
    except Exception as e:
        print("Error or no processes to kill:", e)

if __name__ == "__main__":
    kill_ghosts()
