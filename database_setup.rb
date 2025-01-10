require 'sqlite3'

DB = SQLite3::Database.new('profiles.db')
DB.results_as_hash = true

# Create the `profiles` table if it doesn't exist
DB.execute <<-SQL 
    CREATE TABLE IF NOT EXISTS profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE
        name TEXT UNIQUE,

    )

SQL
