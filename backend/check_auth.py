import sqlite3
from main import verify_password

try:
    conn = sqlite3.connect('attendance.db')
    cursor = conn.cursor()
    cursor.execute("SELECT hashed_password FROM admin_users WHERE username='admin'")
    row = cursor.fetchone()
    if row:
        hash_val = row[0]
        match = verify_password('admin123', hash_val)
        print(f"Hash: {hash_val}")
        print(f"Match: {match}")
    else:
        print("User admin not found")
    conn.close()
except Exception as e:
    print(f"Error: {e}")
