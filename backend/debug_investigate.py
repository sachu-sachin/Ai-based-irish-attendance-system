import sqlite3
import os
import subprocess

def investigate():
    print("--- Database Check ---")
    if os.path.exists('attendance.db'):
        conn = sqlite3.connect('attendance.db')
        cursor = conn.cursor()
        print("Tables:", cursor.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall())
        admins = cursor.execute("SELECT id, username, role FROM admin_users").fetchall()
        print("Admins in DB:", admins)
        conn.close()
    else:
        print("attendance.db not found!")

    print("\n--- Port 8000 Check ---")
    try:
        # Check what's listening on port 8000
        output = subprocess.check_output("netstat -ano | findstr :8000", shell=True).decode()
        print("Processes on port 8000:\n", output)
    except Exception as e:
        print("No processes found on port 8000 or error:", e)

if __name__ == "__main__":
    investigate()
