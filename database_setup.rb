require 'sqlite3'

DB = SQLite3::Database.new('profiles.db')
DB.results_as_hash = true

# Profiles Table
DB.execute <<-SQL 
    CREATE TABLE IF NOT EXISTS profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE
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
