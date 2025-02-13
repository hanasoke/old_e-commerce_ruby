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

DB.execute <<-SQL 
    CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER,
        car_id INTEGER, 
        quantity INTEGER,
        total_price INTEGER,
        payment_method TEXT,
        account_number TEXT,
        payment_photo TEXT,
        payment_status TEXT,
        transaction_date TEXT,
        FOREIGN KEY(profile_id) REFERENCES profiles(id),
        FOREIGN KEY(car_id) REFERENCES cars(id) 
    );
SQL

# begin 
#     DB.execute("ALTER TABLE transactions ADD COLUMN admin_approved BOOLEAN DEFAULT 0;")
# rescue SQLite3::SQLException => e 
#     puts "Column 'transactions' already exists or another error occured: #{e.message}"
# end

# Start a transaction to ensure data integrity
# DB.transaction do 
#     # Create a new table without the admin_approved column
#     DB.execute <<-SQL
#         CREATE TABLE transactions_new (
#             id INTEGER PRIMARY KEY AUTOINCREMENT,
#             profile_id INTEGER,
#             car_id INTEGER,
#             quantity INTEGER,
#             total_price INTEGER,
#             payment_method TEXT,
#             account_number TEXT,
#             payment_photo TEXT,
#             payment_status TEXT,
#             transaction_date TEXT,
#             FOREIGN KEY(profile_id) REFERENCES profiles(id),
#             FOREIGN KEY(car_id) REFERENCES cars(id)
#         );
#     SQL

#     # Copy all data except the admin_approved column
#     DB.execute <<-SQL 
#         INSERT INTO transactions_new(id, profile_id, car_id, quantity, total_price,
#                                     payment_method, account_number, payment_photo,
#                                     payment_status, transaction_date)
#         SELECT id, profile_id, car_id, quantity, total_price,
#                 payment_method, account_number, payment_photo,
#                 payment_status, transaction_date
#         FROM transactions;
#     SQL

#     # Drop the old table
#     DB.execute("DROP TABLE transactions;")

#     # Rename the new table to transactions
#     DB.execute("ALTER TABLE transactions_new RENAME TO transactions;")
# end 

DB.execute <<-SQL 
    CREATE TABLE IF NOT EXISTS wishlists (
        CREATE TABLE IF NOT EXISTS wishlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            car_id INTEGER,
            quantity INTEGER, 
            total_price INTEGER
        )
    );
SQL