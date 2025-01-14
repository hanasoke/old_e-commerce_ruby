require 'sqlite3'

DB = SQLite3::Database.new('profiles.db')
DB.results_as_hash = true

# Profiles Table
DB.execute <<-SQL 
    CREATE TABLE IF NOT EXISTS profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        name TEXT UNIQUE,
        email TEXT UNIQUE,
        password TEXT,
        phone INTEGER,
        country TEXT,
        photo TEXT,
        reset_token TEXT,
        access INTEGER
    );
SQL

# Add the 'age' column if it doesn't exist
# begin
#     DB.execute("ALTER TABLE profiles ADD COLUMN age INTEGER;")
# rescue SQLite3::SQLException => e 
#     puts "Column 'age' already exists or another error occured: #{e.message}"
# end

DB.execute <<-SQL 
    CREATE TABLE IF NOT EXISTS cars (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        type TEXT,
        brand TEXT,
        transmission TEXT,
        seat INTEGER,
        machine INTEGER,
        power INTEGER,
        photo TEXT,
        price INTEGER
    );
SQL