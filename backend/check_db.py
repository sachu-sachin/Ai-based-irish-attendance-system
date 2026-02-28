import sqlite3
import sys

def main():
    try:
        conn = sqlite3.connect('attendance.db')
        cursor = conn.cursor()
        
        # Get all tables
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = [t[0] for t in cursor.fetchall()]
        print(f"Tables found: {tables}")
        
        if 'users' in tables:
            cursor.execute("SELECT COUNT(*) FROM users")
            count = cursor.fetchone()[0]
            print(f"Users table count: {count}")
            if count > 0:
                cursor.execute("SELECT id, username, role, is_active FROM users")
                users = cursor.fetchall()
                print("Users:")
                for u in users:
                    print(f" - {u}")
        else:
            print("No 'users' table found!")
            
        if 'admin_users' in tables:
            cursor.execute("SELECT COUNT(*) FROM admin_users")
            count = cursor.fetchone()[0]
            print(f"Admin users count: {count}")
            if count > 0:
                cursor.execute("SELECT id, username, email FROM admin_users")
                users = cursor.fetchall()
                print("Admin Users:")
                for u in users:
                    print(f" - {u}")
                    
    except Exception as e:
        print(f"Error: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    main()
