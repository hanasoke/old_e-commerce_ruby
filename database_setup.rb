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
        age TEXT,
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

# DB.execute <<-SQL 
#     CREATE TABLE IF NOT EXISTS cars (
#         id INTEGER PRIMARY KEY AUTOINCREMENT,
#         name TEXT,
#         type TEXT,
#         brand TEXT,
#         transmission TEXT,
#         seat INTEGER,
#         machine INTEGER,
#         power INTEGER,
#         photo TEXT,
#         price INTEGER
#     );
# SQL

# Step 1:Create a new table with the updated schema
# DB.execute <<-SQL 
#     CREATE TABLE IF NOT EXISTS cars_new (
#         id INTEGER PRIMARY KEY AUTOINCREMENT,
#         name TEXT,
#         color TEXT, --Renamed column from 'type' to 'color'
#         brand TEXT,
#         transmission TEXT,
#         seat INTEGER,
#         machine INTEGER,
#         power INTEGER,
#         photo TEXT,
#         price INTEGER
#     );
# SQL

# Step 2: Copy data from the old table to the new table
# DB.execute <<-SQL
#     INSERT INTO cars_new (id, name, color, brand, transmission, seat, machine, power, photo, price)
#     SELECT id, name, type, brand, transmission, seat, machine, power, photo, price
#     FROM cars;
# SQL

# Step 3: DROP the old table
# DB.execute("DROP TABLE cars;")

# Step 4: Rename the new table to the original table name
# DB.execute("ALTER TABLE cars_new RENAME TO cars;")

# Add the `stock` column if it doesn't exist
# begin 
#     DB.execute("ALTER TABLE cars ADD COLUMN stock INTEGER;")
# rescue SQLite3::SQLException => e 
#     puts "Column 'stock' already exists or another error occured: #{e.message}"
# end

# begin 
#     DB.execute("ALTER TABLE cars ADD COLUMN manufacture TEXT;")
# rescue SQLite3::SQLException => e 
#     puts "Column 'manufacture' already exists or another error occured: #{e.message}"
# end

DB.execute <<-SQL 
    CREATE TABLE IF NOT EXISTS cars (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        color TEXT,
        brand TEXT,
        transmission TEXT,
        seat INTEGER,
        machine INTEGER,
        power INTEGER,
        photo TEXT,
        price INTEGER,
        stock INTEGER,
        manufacture TEXT
    );
SQL