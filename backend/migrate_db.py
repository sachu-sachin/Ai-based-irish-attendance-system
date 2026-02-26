import sqlite3

def migrate():
    try:
        conn = sqlite3.connect('attendance.db')
        cursor = conn.cursor()
        
        # Add iris_feature columns to students table
        columns_to_add = [
            ("students", "iris_feature_left", "TEXT"),
            ("students", "iris_feature_right", "TEXT"),
            # Add these if missing from attendance_records (based on previous logs)
            ("attendance_records", "is_fake_eye", "BOOLEAN DEFAULT 0"),
            ("attendance_records", "confidence", "FLOAT DEFAULT 1.0"),
        ]
        
        for table, col, col_type in columns_to_add:
            try:
                cursor.execute(f"ALTER TABLE {table} ADD COLUMN {col} {col_type}")
                print(f"Added column {col} to {table}")
            except sqlite3.OperationalError:
                print(f"Column {col} already exists in {table} or table missing")
        
        conn.commit()
        conn.close()
        print("Migration completed successfully.")
    except Exception as e:
        print(f"Migration error: {e}")

if __name__ == "__main__":
    migrate()
