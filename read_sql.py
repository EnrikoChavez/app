import sqlite3

conn = sqlite3.connect("todos.db")
cursor = conn.cursor()

cursor.execute("SELECT * FROM todos")
rows = cursor.fetchall()

for row in rows:
    print(row)

conn.close()