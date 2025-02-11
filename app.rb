require 'sinatra'
require 'sinatra/flash'
require 'bcrypt'
require_relative 'database_setup'

enable :sessions
register Sinatra::Flash

# Allow access from any IP
set :bind, '127.0.0.1'

# Different server port
set :port, 4000 

# Helper methods
def logged_in?
    session[:profile_id] != nil 
end 

def current_profile
    @current_profile ||= DB.execute("SELECT * FROM profiles WHERE id = ?", [session[:profile_id]]).first if logged_in?
end 

before do 
    # Fetch car brands
    @cars = DB.execute("SELECT DISTINCT brand FROM cars")
end 

# validate email 
def validate_email(email)
    errors = []
    # Regular expression for email validation
    email_regex = /\A[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\z/ 

    # check if email is blank
    if email.nil? || email.strip.empty?
        errors << "Email cannot be blank."
    elsif email !~ email_regex
        # check if email matches the regular expression
        errors << "Email format is invalid"
    # else 
        # Check for Email fields
        query = id ? "SELECT id FROM profiles WHERE LOWER(email) = ? AND id != ?" : "SELECT id FROM profiles WHERE LOWER(email) = ?"
        existing_email = DB.execute(query, id ? [email.downcase, id] : [email.downcase]).first
        errors << "Email already exist. Please choose a different name." if existing_email
    end 

    errors
end 

# validate profile
def validate_profile(username, name, email, password, re_password, age, phone, country, access, id = nil)
    errors = []

    # username validation
    errors << "Username cannot be blank." if username.nil? || username.strip.empty?

    # name validation
    errors << "Name cannot be blank." if name.nil? || name.strip.empty?

    # password validation
    errors << "Password cannot be blank." if password.nil? || password.strip.empty?

    # phone validation
    if phone.nil? || phone.strip.empty?
        errors << "Phone Cannot be Blank."
    elsif phone.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Phone must be a valid number."
    elsif phone.to_i <= 0
        errors << "Phone must be a positive number."
    end

    # age validation
    if age.nil? || age.strip.empty?
        errors << "Age Cannot be Blank."
    elsif age.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Age must be a valid number."
    elsif age.to_i <= 0
        errors << "Age must be a positive number."
    end

    # country validation
    errors << "Country cannot be blank." if country.nil? || country.strip.empty?

    # access validation
    errors << "Access cannot be blank." if access.nil? || access.strip.empty?

    # validate email
    email_errors = validate_email(email)
    errors.concat(email_errors)

    # check if password match
    errors << "Password do not match." if password != re_password
    errors
end 

# validate user
def validate_user(username, name, email, age, phone, country, access, id = nil)
    errors = []

    # username validation
    errors << "Username cannot be blank." if username.nil? || username.strip.empty?

    # name validation
    errors << "Name cannot be blank." if name.nil? || name.strip.empty?

    # phone validation
    if phone.nil? || phone.strip.empty?
        errors << "Phone Cannot be Blank."
    elsif phone.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Phone must be a valid number."
    elsif phone.to_i <= 0
        errors << "Phone must be a positive number."
    end

    # age validation
    if age.nil? || age.strip.empty?
        errors << "Age Cannot be Blank."
    elsif age.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Age must be a valid number."
    elsif age.to_i <= 0
        errors << "Age must be a positive number."
    end

    # country validation
    errors << "Country cannot be blank." if country.nil? || country.strip.empty?

    # access validation
    errors << "Access cannot be blank." if access.nil? || access.strip.empty?

    # validate email
    email_errors = validate_email(email)
    errors.concat(email_errors)

    errors
end 

# Validate transaction 
def validate_transaction(payment_method, quantity, account_number, id = nil)
    errors = []

    # payment method validation
    errors << "Payment Method cannot be blank." if payment_method.nil? || payment_method.strip.empty?

    # quantity validation
    if quantity.nil? || quantity.strip.empty?
        errors << "Quantity Cannot be Blank."
    elsif quantity.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Quantity must be a valid number."
    elsif quantity.to_i <= 0
        errors << "Quantity must be a positive number."
    end

    # Account Number validation
    if account_number.nil? || account_number.strip.empty?
        errors << "Account Number Cannot be Blank."
    elsif account_number.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Account Number must be a valid number."
    elsif account_number.to_i <= 0
        errors << "Account Number must be a positive number."
    end

    errors 
end 

# Validate transaction 
def editing_transaction(payment_status, id = nil)
    errors = []

    # payment status validation
    errors << "Payment Status cannot be blank." if payment_status.nil? || payment_status.strip.empty?

    errors 
end

def editing_a_transaction(car_name, car_brand, car_color, car_transmission, car_price, car_manufacture, car_seat, car_stock, quantity, payment_method, account_number, id = nil)
    errors = []

    # car name method validation
    errors << "Car Name cannot be blank." if car_name.nil? || car_name.to_s.strip.empty?
    # car brand method validation
    errors << "Car Brand cannot be blank." if car_brand.nil? || car_brand.to_s.strip.empty?
    # car color method validation
    errors << "Car Color cannot be blank." if car_color.nil? || car_color.to_s.strip.empty?
    # car transmission method validation
    errors << "Car Transmission cannot be blank." if car_transmission.nil? || car_transmission.to_s.strip.empty?

    # car price method validation
    if car_price.nil? || car_price.strip.empty?
        errors << "Car Price Cannot be Blank."
    elsif car_price.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Car Price must be a valid number."
    elsif car_price.to_i <= 0
        errors << "Car Price must be a positive number"
    end  
    
    # car manufacture method validation
    errors << "Car Manufacture cannot be blank." if car_manufacture.nil? || car_manufacture.to_s.strip.empty?
    # car seat method validation
    errors << "Car Seat cannot be blank." if car_seat.nil? || car_seat.to_s.strip.empty?
    # car color method validation
    errors << "Car Stock cannot be blank." if car_stock.nil? || car_stock.to_s.strip.empty?
    if quantity.nil? || quantity.strip.empty?
        errors << "Quantity Cannot be Blank."
    elsif quantity.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Quantity must be a valid number."
    elsif quantity.to_i <= 0
        errors << "Quantity must be a positive number"
    end  
    # payment method validation
    errors << "Payment Method cannot be blank." if payment_method.nil? || payment_method.strip.empty?

    # account number validation
    if account_number.nil? || account_number.strip.empty?
        errors << "Account Number Cannot be Blank."
    elsif account_number.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Account Number must be a valid number."
    elsif account_number.to_i <= 0
        errors << "Account Number must be a positive number"
    end  

    errors 
end

def validate_profile_login(email, password)
    errors = []
    errors << "Password cannot be blank." if password.nil? || password.strip.empty?

    # Validate email format
    errors.concat(validate_email(email)) 
    errors
end 

def validate_photo(photo)
  errors = []

  # Check if the photo parameter is valid and has expected structure
  if photo.nil? || !photo.is_a?(Hash) || photo[:tempfile].nil?
    errors << "Photo is required."
  else
    # Check file type
    valid_types = ["image/jpeg", "image/png", "image/gif"]
    if !photo[:type] || !valid_types.include?(photo[:type])
      errors << "Photo must be a JPG, PNG, or GIF file."
    end

    # Check file size (5MB max, 40KB min)
    max_size = 4 * 1024 * 1024 # 4MB in bytes
    min_size = 40 * 1024       # 40KB in bytes
    file_size = photo[:tempfile].size if photo[:tempfile] && photo[:tempfile].respond_to?(:size)

    if file_size.nil?
      errors << "Photo file size could not be determined."
    elsif file_size > max_size
      errors << "Photo size must be less than 4MB."
    elsif file_size < min_size
      errors << "Photo size must be greater than 40KB."
    end
  end

  errors
end

def editing_profile(name, username, email, age, phone, country, access, id = nil)

    errors = []

    errors << "Username cannot be blank." if username.nil? || username.strip.empty?
    errors << "Name cannot be blank." if name.nil? || name.strip.empty?

    errors << "Age cannot be blank." if age.nil? || age.strip.empty?
    errors << "Phone cannot be blank." if phone.nil? || phone.strip.empty?

    errors << "Country cannot be blank." if country.nil? || country.strip.empty?
    errors << "Access cannot be blank." if access.nil? || access.strip.empty?

    # Validate email
    errors.concat(validate_email(email))
    errors
end 

def editing_user(username, name, email, age, phone, country, id = nil)

    errors = []

    errors << "Username cannot be blank." if username.nil? || username.strip.empty?
    errors << "Name cannot be blank." if name.nil? || name.strip.empty?

    errors << "Age cannot be blank." if age.nil? || age.strip.empty?
    errors << "Phone cannot be blank." if phone.nil? || phone.strip.empty?

    errors << "Country cannot be blank." if country.nil? || country.strip.empty?

    # Validate email
    errors.concat(validate_email(email))
    errors
end 

def validate_car(name, color, brand, transmission, seat, machine, power, price, stock, manufacture, id = nil)
    errors = []
    # check for empty fields
    errors << "Name cannot be blank." if name.nil? || name.strip.empty?

    # Check for unique name
    query = id ? "SELECT id FROM cars WHERE LOWER(name) = ? AND id != ?" : "SELECT id FROM cars WHERE LOWER(name) = ?"
    existing_car = DB.execute(query, id ? [name.downcase, id] : [name.downcase]).first
    errors << "Name already exist. Please choose a different name." if existing_car

    # Other Validation 
    errors << "color cannot be blank." if color.nil? || color.strip.empty?

    # brand validation
    errors << "brand cannot be blank." if brand.nil? || brand.strip.empty?

    # transmission validation
    errors << "transmission cannot be blank." if transmission.nil? || transmission.strip.empty?

    # seat validation
    if seat.nil? || seat.to_i < 1 || seat.to_i > 10
        errors << "Seat must be a number between 1 to 10."
    elsif seat.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors <<"Seat must be a valid number"
    end

    # machine validation
    if machine.nil? || machine.strip.empty?
        errors << "machine cannot be blank."
    elsif machine.to_f <= 0
        errors << "machine must be a positive number." 
    elsif machine.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "machine must be a valid number."
    end 

    # power validation
    if power.nil? || power.strip.empty?
        errors << "power cannot be blank."
    elsif power.to_f <= 0
        errors << "power must be a positive number." 
    elsif power.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "power must be a valid number."
    end    

    # price validation
    if price.nil? || price.strip.empty?
        errors << "price cannot be blank."
    elsif price.to_f <= 0
        errors << "Price must be a positive number." 
    elsif price.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Price must be a valid number."
    end 

    # power validation
    if stock.nil? || stock.strip.empty?
        errors << "stock cannot be blank."
    elsif stock.to_f <= 0
        errors << "stock must be a positive number."
    elsif !(stock =~ /\A[+-]?\d+(\.\d+)?\z/)
        errors << "Stock must be a number."
    end 


    # Validate manufacture date
    if manufacture.nil? || manufacture.strip.empty? || !manufacture.match(/^\d{4}-\d{2}-\d{2}$/)
        errors << "Manufacture date must be a valid date (YYYY-MM-DD)."
    end 

    errors
end 

def format_rupiah(number) 
    "Rp #{number.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/,'\\1.').reverse}"
end 

def machine(number)
    "#{number} cc"
end 

def seat(number)
    "#{number} seat"
end 

def power(number)
    "#{number} hp"
end 

# Routes 
get '/' do 
    @title = "Homepage"
    if logged_in?
        erb :'user/index', layout: :'layouts/main' 
    else 
        redirect '/login'
    end 
end 

# Registration
get '/register' do 
    @errors = []
    @title = "Register Dashboard"
    erb :'register/index', layout: :'layouts/sign'
end 

post '/register' do 
    # Validate inputs
    @errors = validate_profile(params[:name], params[:username], params[:email], params[:password], params[:'re-password'], params[:age], params[:phone], params[:country], params[:access])

    # Flash message
    session[:success] = "Your Account has been registered."

    photo = params['photo']
    @errors += validate_photo(photo) if photo # Add photo validation errors

    photo_filename = nil

    if @errors.empty?
        # Handle photo upload
        if photo && photo[:tempfile]
            photo_filename = "#{Time.now.to_i}_#{photo[:filename]}"
            File.open("./public/uploads/#{photo_filename}", 'wb') do |f|
                f.write(photo[:tempfile].read)
            end 
        end 

        name = params[:name]
        username = params[:username]
        email = params[:email]
        password = BCrypt::Password.create(params[:password])
        age = params[:age]
        phone = params[:phone]
        country = params[:country]
        access = params[:access]

        begin 
            DB.execute("INSERT INTO profiles (name, username, email, password, age, phone, country, photo, access) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)", [name, username, email, password, age, phone, country, photo_filename, access])

            redirect '/login'
        
        rescue SQLite3::ConstraintException
            @errors << "Username already exists"
        end 

    end 
    erb :'register/index', layout: :'layouts/sign'
end 

helpers do 
    def flash(type) 
        message = session[type]
        #clear flash message after displaying
        session[type] = nil 
        message
    end 
end 

# Login
get '/login' do 
    @errors = []
    @title = "Login User"
    erb :'login/index', layout: :'layouts/sign'
end 

post '/login' do 
    @errors = validate_profile_login(params[:email], params[:password])

    if @errors.empty?
        email = params[:email]
        profile = DB.execute("SELECT * FROM profiles WHERE email = ?", [email]).first

        if profile && BCrypt::Password.new(profile['password']) == params[:password]
            session[:profile_id] = profile['id']
            
            # Check access level and redirect accordingly
            if profile['access'] == 0
                # Redirect to the user page for regular users
                redirect '/user_page'
            elsif profile['access'] == 1
                # Redirect to the admin page for admins
                redirect '/admin_page' 
            else 
                @errors << "Invalid access level"
            end 
        else 
            @errors << "Invalid email or password"
        end 
    end 
    erb :'login/index', layout: :'layouts/sign'
end 

get '/user_page' do 
    @title = "User Page"
    @cars = DB.execute("SELECT * FROM cars")
    erb :'user/index', layout: :'layouts/main'
end 

get '/admin_page' do 
    redirect '/login' unless session[:profile_id] && DB.execute("SELECT access FROM profiles WHERE id = ?", [session[:profile_id]]).first['access'] == 1
    @title = "Admin Page"
    @profiles = DB.execute("SELECT * FROM profiles WHERE access = 0")
    erb :'admin/index', layout: :'layouts/admin'
end 

# logout
get '/logout' do 
    success_message = "You have been logged out successfully."
    session.clear
    session[:success] = success_message
    redirect '/login'
end 

get '/payment_lists' do 
    @title = "Payment Lists"
    erb :'admin/payments', layout: :'layouts/admin'
end 

get '/transactions_lists' do 
    @title = "Transactions Lists"
    @transactions = DB.execute("SELECT * FROM transactions")
    erb :'admin/transactions', layout: :'layouts/admin'
end 

get '/admin_profile' do 
    @title = "Admin Profile"
    erb :'admin/admin_profile', layout: :'layouts/admin'
end 

get '/profiles/edit' do 
    redirect '/login' unless logged_in?

    @title = "Edit Admin Profile"
    @profile = current_profile
    @errors = []
    erb :'admin/edit_admin_profile', layout: :'layouts/admin'
end 

post '/profiles/:id/edit' do 
    @errors = editing_profile(params[:name], params[:username], params[:email], params[:age], params[:phone], params[:country], params[:access], params[:id])

    # error photo variable check
    photo = params['photo']
    @errors += validate_photo(photo) if photo && photo[:tempfile] # Validate only if a new photo is provided

    photo_filename = nil 

    if @errors.empty?
        # Handle file upload
        if photo && photo[:tempfile]
            photo_filename = "#{Time.now.to_i}_#{photo[:filename]}"
            File.open("./public/uploads/#{photo_filename}", "wb") do |f|
                f.write(photo[:tempfile].read)
            end 
        end 

        # Flash message 
        session[:success] = "Your Profile has been successfully updated"
        DB.execute("UPDATE profiles SET name = ?, username = ?, email = ?, phone = ?, age = ?, country = ?, photo = COALESCE(?, photo), access = ? WHERE id = ?", [params[:name], params[:username], params[:email], params[:phone], params[:age], params[:country], photo_filename, params[:access], params[:id]])

        profile = DB.execute("SELECT * FROM profiles WHERE email = ?", [params[:email]]).first
        session[:profile_id] = profile['id']

        # Redirect based on access level
        case profile['access']
        when 0
            # Flash message 
            session[:success] = "Your Are Customer Now"
            redirect '/login'
        when 1
            # Flash message 
            session[:success] = "Your Profile has been successfully updated"
            redirect '/admin_profile'
        else 
            @errors << "Invalid access level"
        end 
    else 
        # Handle validation errors and re-render the edit form
        original_profile = DB.execute("SELECT * FROM profiles WHERE id = ?", [params[:id]]).first
        
        # Merge profile input with original data to retain user edits
        @profile = {
            'id' => params[:id],
            'name' => params[:name] || original_profile['name'],
            'username' => params[:username] || original_profile['username'] ,
            'email' => params[:email] || original_profile['email'],
            'phone' => params[:phone] || original_profile['phone'],
            'age' => params[:age] || original_profile['age'],
            'country' => params[:country] || original_profile['country'],
            'photo' => photo_filename || original_profile['photo'],
            'access' => params[:access] || original_profile['access']
        }
        erb :'admin/edit_admin_profile', layout: :'layouts/admin'
    end
end 

# Show Forgot Password Page
get '/forgot_password' do 
    @errors = []
    erb :'password/forgot_password', layout: :'layouts/sign'
end 

post '/forgot_password' do 
    email = params[:email]
    @errors = []

    session[:success] = "Password reset link sent to your email."

    if email.strip.empty?
        @errors << "Email cannot be blank."
    elsif !DB.execute("SELECT * FROM profiles WHERE email = ?", [email]).first
        @errors << "Email not found in our records."
    else 
        # Generate reset token (basic implementation, use a secure library in production)
        reset_token = SecureRandom.hex(20)
        DB.execute("UPDATE profiles SET reset_token = ? WHERE email = ?", [reset_token, email])

        # Semulate sending an email (in production, send a real email)
        reset_url = "http://localhost:4000/reset_password/#{reset_token}"
        puts "Reset password link: #{reset_url}" # Replace with email sending logic
        redirect '/login'
    end 
    
    erb :'password/forgot_password', layout: :'layouts/sign'
end 

# Show Reset Password Page
get '/reset_password/:token' do 
    @reset_token = params[:token]
    @profile = DB.execute("SELECT * FROM profiles WHERE reset_token = ?", [@reset_token]).first

    if @profile.nil?
        session[:error] = "Invalid or expired reset token."
        redirect '/login'
    end
    
    erb :'password/reset_password', layout: :'layouts/sign'
end 

# Handle Reset Password Submission
post '/reset_password' do 
    reset_token = params[:reset_token]
    password = params[:password]
    re_password = params[:re_password]
    @errors = []

    if password.strip.empty? || re_password.strip.empty?
        @errors << "Password fields cannot be blank."
    elsif password != re_password
        @errors << "Password do not match."
    else
        profile = DB.execute("SELECT * FROM profiles WHERE reset_token = ?", [reset_token]).first
        
        if profile.nil?
            @errors << "Invalid or expired reset token."
        else 
            hashed_password = BCrypt::Password.create(password)
            DB.execute("UPDATE profiles SET password = ?, reset_token = NULL WHERE id = ?", [hashed_password, profile['id']])
            session[:success] = "Password reset successfully. Please log in."
            redirect '/login'
        end 
    end 

    @reset_token = reset_token
    erb :'password/reset_password', layout: :'layouts/sign'
end 

# Read all cars 
get '/car_lists' do 
    @title = "Car List"
    @cars = DB.execute("SELECT * FROM cars")
    erb :'admin/cars/views', layout: :'layouts/admin'
end 

get '/add_car' do 
    @title = "Adding A Car"
    @errors = []
    erb :'admin/cars/add', layout: :'layouts/admin'
end 

# Create a new car
post '/add_car' do 
    @errors = validate_car(params[:name], params[:color], params[:brand], params[:transmission], params[:seat], params[:machine], params[:power], params[:price], params[:stock], params[:manufacture])

    photo = params['photo']

    # Add photo validation errors
    @errors += validate_photo(photo)

    photo_filename = nil

    if @errors.empty?
        # Handle file upload
        if photo && photo[:tempfile]
            photo_filename = "#{Time.now.to_i}_#{photo[:filename]}"
            File.open("./public/uploads/cars/#{photo_filename}", 'wb') do |f|
                f.write(photo[:tempfile].read)
            end 
        end
        
        # Flash message
        session[:success] = "The Car has been successfully added."

        # Insert car details, including the photo, into the database
        DB.execute("INSERT INTO cars(name, color, brand, transmission, seat, machine, power, photo, price, stock, manufacture) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [params[:name], params[:color], params[:brand], params[:transmission], params[:seat], params[:machine], params[:power], photo_filename, params[:price], params[:stock], params[:manufacture]])
        redirect '/car_lists'
    else 
        erb :'admin/cars/add', layout: :'layouts/admin'
    end 
end 

# Render the edit form for a car
get '/edit_car/:id' do 
    @title = "Edit A Car"

    # Fetch the tree data by ID
    @car = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first
    @errors = []
    erb :'admin/cars/edit', layout: :'layouts/admin'
end 

# Update a car
post '/edit_car/:id' do
    @errors = validate_car(params[:name], params[:color], params[:brand], params[:transmission], params[:seat], params[:machine], params[:power], params[:price], params[:stock], params[:manufacture], params[:id])

    # photo 
    photo = params['photo']

    # Validate only if a new photo is provided
    @errors += validate_photo(photo) if photo && photo [:tempfile] 
    photo_filename = nil 

    if @errors.empty? 
        # Handle file image upload
        if photo && photo[:tempfile]
            photo_filename = "#{Time.now.to_i}_#{photo[:filename]}"
            File.open("./public/uploads/cars/#{photo_filename}", 'wb') do |f|
                f.write(photo[:tempfile].read)
            end 
        end

        # Flash message
        session[:success] = "A Car has been successfully updated."

        # Update the car in the database
        DB.execute("UPDATE cars SET name = ?, color = ?, brand = ?, transmission = ?, seat = ?, machine = ?, power = ?, photo = COALESCE(?, photo), price = ?, stock = ?, manufacture = ? WHERE id = ?", 
            [params[:name], params[:color], params[:brand], params[:transmission], params[:seat], params[:machine], params[:power], photo_filename, params[:price], params[:stock], params[:manufacture], params[:id]])
        redirect '/car_lists'
    else 
        # Handle validation errors and re-render the edit form
        original_car = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first

        # Merge validation errors and re-render the edit form
        @car = {
            'id' => params[:id],
            'name' => params[:name] || original_car['name'],
            'color' => params[:color] || original_car['color'],
            'brand' => params[:brand] || original_car['brand'],
            'transmission' => params[:transmission] || original_car['transmission'],
            'seat' => params[:seat] || original_car['seat'],
            'machine' => params[:machine] || original_car['machine'],
            'power' => params[:power] || original_car['power'],
            'photo' => photo_filename || original_car['photo'],
            'price' => params[:price] || original_car['price'],
            'stock' => params[:stock] || original_car['stock'],
            'manufacture' => params[:manufacture] || original_car['manufacture'],
        }
        erb :'admin/cars/edit', layout: :'layouts/admin'
    end  
end 

# Delete a car 
post '/cars/:id/delete' do 
    # Flash message
    session[:success] = "The Car has been successfully deleted."

    # Delete logic
    DB.execute("DELETE FROM cars WHERE id = ?", [params[:id]])

    redirect '/car_lists'
end 

get '/users/:id/edit' do 
    redirect '/login' unless logged_in?

    @title = "View the User Profile"
    @user = DB.execute("SELECT * FROM profiles WHERE id = ?", [params[:id]]).first
    @errors = []
    erb :'admin/users/edit', layout: :'layouts/admin'
end 

# Update a user
post '/users/:id' do 
    @errors = validate_user(params[:username] ,params[:name], params[:email], params[:age], params[:phone], params[:country], params[:access], params[:id])

    # error photo variable check
    photo = params['photo']

    # Validate only if a new photo is provided
    @errors += validate_photo(photo) if photo && photo[:tempfile]

    photo_filename = nil 

    if @errors.empty? 
        # Handle file image upload
        if photo && photo[:tempfile]
            photo_filename = "#{Time.now.to_i}_#{photo[:filename]}"
            # Uploaded image to uploads folder
            File.open("./public/uploads/#{photo_filename}", 'wb') do |f|
                f.write(photo[:tempfile].read)
            end 
        end 

        # Flash Message
        session[:success] = "A User has been successfully updated."

        # Update the car in the database
        DB.execute("UPDATE profiles SET username = ?, name = ?, email = ?, age = ?, country = ?, phone = ?, photo = COALESCE(?, photo), access = ? WHERE id = ?",
        [params[:username], params[:name], params[:email], params[:age], params[:country], params[:phone], photo_filename, params[:access], params[:id]])

        redirect '/admin_page'

    else 
        # Handle validation errors and re-render the edit form
        original_user = DB.execute("SELECT * FROM profiles WHERE id = ?", [params[:id]]).first

        # Merge user input with original data to retain user edits
        @user = {
            'id' => params[:id],
            'username' => params[:username] || original_user['username'],
            'name' => params[:name] || original_user['name'],
            'email' => params[:email] || original_user['email'],
            'age' => params[:age] || original_user['age'],
            'country' => params[:country] || original_user['country'],
            'phone' => params[:phone] || original_user['phone'],
            'photo' => photo_filename || original_user['photo'],
            'access' => params[:access] || original_user['access']
        }
        erb :'admin/users/edit', layout: :'layouts/admin'
    end 
end 

# DELETE a user
post'/users/:id/delete' do 
    # Flash message
    session[:success] = "A User has been successfully deleted."

    DB.execute("DELETE FROM profiles WHERE id = ?", [params[:id]])
    redirect '/admin_page'
end 

get '/user_profile' do 
    redirect '/login' unless logged_in?

    @title = "User Profile"
    @profile = current_profile
    erb :'user/user_profile', layout: :'layouts/main'
end 

get '/edit_profile/:id' do 
    redirect '/login' unless logged_in?

    @title = "Edit Profile"
    @profile = DB.execute("SELECT * FROM profiles WHERE id = ?", [params[:id]]).first
    @errors = []
    erb :'user/edit_profile', layout: :'layouts/main'
end 

post '/edit_profile/:id' do 

    @errors = editing_user(params[:username], params[:name], params[:email], params[:age], params[:phone], params[:country], params[:id])

    # error photo variable check
    photo = params['photo']
    # Validate only if a new photo is provided
    @errors += validate_photo(photo) if photo && photo[:tempfile]
    
    photo_filename = nil 

    if @errors.empty? 
        # Handle file upload
        if photo && photo[:tempfile]
            photo_filename = "#{Time.now.to_i}_#{photo[:filename]}"
            File.open("./public/uploads/#{photo_filename}", 'wb') do |f|
                f.write(photo[:tempfile].read)
            end 
        end 

        # Flash message
        session[:success] = "Your Profile has been successfully updated"
        # Update the car in the database
        DB.execute("UPDATE profiles SET username = ?, name = ?, email = ?, age = ?, phone = ?, country = ?, photo = COALESCE(?, photo) WHERE id = ?",
        [params[:username], params[:name], params[:email], params[:age], params[:phone], params[:country], photo_filename, params[:id]])
        redirect '/user_profile'
    else 
        # Handle validation errors and re-render the edit form
        original_profile = DB.execute("SELECT * FROM profiles WHERE id = ?", [params[:id]]).first

        # Merge user input with original data to retain user edit
        @profile = {
            'id' => params[:id],
            'username' => params[:username] || original_profile['username'],
            'name' => params[:name] || original_profile['name'],
            'email' => params[:email] || original_profile['email'],
            'age' => params[:age] || original_profile['age'],
            'phone' => params[:phone] || original_profile['phone'],
            'country' => params[:country] || original_profile['country'],
            'photo' =>  photo_filename || original_profile['photo']
        }
        erb :'user/edit_profile', layout: :'layouts/main'
    end 
end 

def user_count
    result = DB.get_first_value("SELECT COUNT(*) FROM profiles")
    result.to_i
end 

def car_count 
    result = DB.get_first_value("SELECT COUNT(*) FROM cars")
    result.to_i
end 

get '/detail_car/:id' do 
    redirect '/login' unless logged_in?

    @car = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first
    @errors = []
    @title = "Car Detail"
    erb :'user/cars/detail', layout: :'layouts/main'
end 

get '/checkout/:id' do 
    redirect '/login' unless logged_in?

    @car = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first
    @errors = []
    @title = "Car Checkout"
    erb :'user/cars/checkout', layout: :'layouts/main'
end 

post '/checkout/:id' do 
    redirect '/login' unless logged_in?

    @car = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first

    # Check if the car exist
    if @car.nil? 
        session[:error] = "Car not found."

        # Redirect user back to main page listing or another relevant page
        redirect '/user_page'
    end 

    quantity = params[:quantity].to_i
    total_price = @car['price'].to_i * quantity
    transaction_date = Time.now.strftime("%Y-%m-%d %H:%M:%S")

    @errors = validate_transaction(params[:payment_method], params[:quantity], params[:account_number])

    photo = params['payment_photo']

    # Add photo validation errors 
    @errors += validate_photo(photo)

    photo_filename = nil 

    if @errors.empty?
        # Handle file upload
        if photo && photo[:tempfile]
            photo_filename = "#{Time.now.to_i}_#{photo[:filename]}"
            File.open("./public/uploads/payments/#{photo_filename}", 'wb') do |f|
                f.write(photo[:tempfile].read)
            end 
        end 

        # Flash Message
        session[:success] = "The Transaction has been successfully added."

        # Insert transaction into the database
        DB.execute("INSERT INTO transactions (profile_id, car_id, quantity, total_price, payment_method, account_number, payment_photo, payment_status, transaction_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [current_profile['id'], @car['id'], quantity, total_price, params[:payment_method], params[:account_number], photo_filename, "Pending", transaction_date])

        # Reduce Stock of the car
        DB.execute("UPDATE cars SET stock = stock - ? WHERE id = ?", [quantity, @car['id']])
        redirect '/waiting'
    else   
        if quantity > @car['stock']
            @errors = ["Not Enoght stock available."]
            return erb :'user/cars/checkout', layout: :'layouts/main'
        end  
        erb :'user/cars/checkout', layout: :'layouts/main'
    end 
end 

get '/waiting' do 
    redirect '/login' unless logged_in?
    @title = "Waiting Page"
    
    # Fetch only transactions waiting for approval
    @transactions = DB.execute(<<-SQL)
        SELECT transactions.*,
                cars.name AS car_name,
                cars.photo
        FROM transactions 
        JOIN cars ON transactions.car_id = cars.id
        WHERE transactions.payment_status = 'Pending';
    SQL

    erb :'user/cars/waiting', layout: :'layouts/main'
end 

get '/orders' do 
    redirect '/login' unless logged_in?
    @title = "Orders Page"
    @transactions = DB.execute(<<-SQL)
                    SELECT transactions.*, 
                        cars.name AS car_name, 
                        cars.photo
                        FROM transactions
                        JOIN cars ON transactions.car_id = cars.id
                        WHERE transactions.payment_status = 'Approved';
                        AND transactions.profile_id = #{current_profile['id']}
                    SQL

    erb :'user/cars/orders', layout: :'layouts/main'
end 

get '/rejected' do 
    redirect '/login' unless logged_in?
    @title = "Rejected Page"
    @transactions = DB.execute(<<-SQL)
                    SELECT transactions.*, 
                        cars.name AS car_name, 
                        cars.photo
                        FROM transactions
                        JOIN cars ON transactions.car_id = cars.id
                        WHERE transactions.payment_status = 'Rejected';
                        AND transactions.profile_id = #{current_profile['id']}
                    SQL

    erb :'user/cars/rejected', layout: :'layouts/main'
end 

get '/transactions' do 
    redirect '/login' unless logged_in?
    @title = "Your Transactions"
    @transactions = DB.execute("SELECT transactions.*, cars.name, cars.photo FROM transactions JOIN cars ON transactions.car_id = cars.id WHERE profile_id = ?", [current_profile['id']])

    # Ensure @transactions is always an array
    @transactions ||= []

    erb :'user/cars/waiting', layout: :'layouts/main'
end 

post '/transactions/:id/delete' do 
    # Ensure the user is logged in 
    unless session[:user_id].nil?
        session[:error] = "You must be logged in to delete transactions."
        redirect '/login'
    end 

    # Get transaction & user profile 
    transaction_id = params[:id].to_i
    transaction = DB.get_first_row("SELECT * FROM transactions WHERE id = ?", [transaction_id])
    profile = current_profile

    if transaction.nil?
        session[:error] = "Transaction not found."
    elsif profile.nil?
        session[:error] = "User not authenticated."
        redirect '/login'
    else 
        # Delete the transaction
        DB.execute("DELETE FROM transactions WHERE id = ?", [transaction_id])

        # Flash message
        session[:success] = "The transaction has been successfully deleted."

        # Redirect based on access level
        case profile['access']
        
        # Regular user
        when 0 then redirect '/waiting'
        
        # Admin
        when 1 then redirect '/transactions_lists'
        else 
            session[:error] = "Invalid access level."
        end 
    end 
end 

# Render the edit form for a transaction
get '/transaction_edit/:id' do 
    @title = "Edit A Transaction"

    # Fetch the transaction data by ID
    @transaction = DB.execute("
        SELECT transactions.*, 
                cars.name AS car_name, 
                cars.photo, 
                profiles.name AS buyer_name
            FROM transactions
            JOIN cars ON transactions.car_id = cars.id
            JOIN profiles ON transactions.profile_id = profiles.id
            WHERE transactions.id = ?", [params[:id]]).first

    # Handle case where transaction does not exist
    if @transaction.nil? 
        session[:error] = "Transaction not found!"
        redirect '/transactions_lists'
    end 

    @errors = []
    erb :'admin/transactions/edit', layout: :'layouts/admin'
end 

# Render the transaction form for database
post '/transaction_edit/:id' do 
    transaction_id = params[:id]
    payment_status = params[:payment_status]

    # Validate required fields
    @errors = editing_transaction(payment_status)

    if @errors.any?
        @transaction = DB.get_first_row("SELECT * FROM transactions WHERE id = ?", [transaction_id])
        erb :'admin/transactions/edit', layout: :'layouts/admin'
    else 
        DB.execute("UPDATE transactions SET payment_status = ? WHERE id = ?",  
            [payment_status, transaction_id])

        session[:success] = "Transaction updated successfully!"
        redirect '/transactions_lists'
    end 
end

# Read all cars 
get '/car_category' do 
    @title = "Car Category"
    @cars = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first
    erb :'admin/cars/views', layout: :'layouts/admin'
end 

# get '/edit_transaction/:id' do 
#     @title = "Edit A Transaction"
#     transaction_id = params[:id]

#     # Fetch the transaction data by ID
#     @transaction = DB.get_first_row(<<-SQL, [transaction_id])
#         SELECT transactions.*,
#             cars.name AS car_name,
#             cars.photo,
#             cars.brand,
#             cars.color,
#             cars.transmission,
#             cars.price,
#             cars.manufacture,
#             cars.seat,
#             cars.stock
#         FROM transactions
#         JOIN cars ON transactions.car_id = cars.id
#         WHERE transactions.id = ?
#     SQL

#     # Handle case where transaction does not exist
#     if @transaction.nil?
#         session[:error] = "Transaction not found!"
#         redirect '/waiting'
#     end

#     @errors = []
#     erb :'user/cars/edit_transaction', layout: :'layouts/main'
# end 

# post '/edit_transaction/:id' do 
#     transaction_id = params[:id]
#     new_quantity = params[:quantity].to_i
#     new_payment_method = params[:payment_method]
#     new_account_number = params[:account_number]
#     total_price = params[:total_price].to_i

#     @errors = editing_a_transaction(new_quantity, new_payment_method, new_account_number, transaction_id)

#     # Fetch the transaction from the database
#     transaction = DB.execute("SELECT * FROM transactions WHERE id = ?", [transaction_id]).first
#     if transaction.nil?
#         redirect '/error_page'
#     end 

#     car = DB.execute("SELECT * FROM cars WHERE id = ?", [transaction['car_id']]).first
#     if car.nil?
#         redirect '/error_page'
#     end 

#     # price_per_unit = transaction['price'].to_i
#     # total_price = price_per_unit * new_quantity

#     previous_quantity = transaction['quantity'].to_i
#     stock = car['stock'].to_i
    
#     if @errors.empty? 

#         # Adjust stock based on quantity change
#         if new_quantity > previous_quantity 
#             difference = new_quantity - previous_quantity
#             if stock >= difference
#                 stock -= difference
#             else 
#                 @errors = ["Not enough stock available."]
#                 return erb :'user/cars/edit_transaction', layout: :'layouts/main'
#             end
#         elsif new_quantity < previous_quantity
#             difference = previous_quantity - new_quantity
#             stock += difference
#         end 

#         # Flash Message
#         session[:success] = "A Transaction Has Been Updated successfully!"

#         # Update the stock in the database
#         DB.execute("UPDATE cars SET stock = ? WHERE id = ?", [stock, car['id']])
#         # Update transaction details 
#         DB.execute("UPDATE transactions SET quantity = ?, total_price = ?, payment_method = ?, account_number = ? WHERE id = ?",
#         [new_quantity, total_price, new_payment_method, new_account_number, transaction_id])
#         redirect '/waiting'
#     else 
#         erb :'user/cars/edit_transaction', layout: :'layouts/main'
#     end 
# end 

get '/edit_checkout/:id' do 
    redirect '/login' unless logged_in?
    @title = "Edit A Car Transaction"
    transaction_id = params[:id]

    # Fetch the transaction data by ID
    @transaction = DB.get_first_row(<<-SQL, [transaction_id])
        SELECT transactions.*,
            cars.name AS car_name,
            cars.photo AS car_photo,
            cars.brand AS car_brand,
            cars.color AS car_color,
            cars.transmission AS car_transmission,
            cars.price AS car_price,
            cars.manufacture AS car_manufacture,
            cars.seat AS car_seat,
            cars.stock AS car_stock
        FROM transactions 
        JOIN cars ON transactions.car_id = cars.id
        WHERE transactions.id = ?
    SQL

    # Handle case where transaction does not exist
    if @transaction.nil?
        session[:error] = "Transaction not found!"
        redirect '/waiting'
    end 

    @errors = []
    erb :'user/cars/edit_checkout', layout: :'layouts/main'
end 

# Edit a Car Transaction
post '/edit_checkout/:id' do 
    @errors = editing_a_transaction(params[:car_name], params[:car_brand], params[:car_color], params[:car_transmission], params[:car_price], params[:car_manufacture], params[:car_seat], params[:car_stock], params[:quantity], params[:payment_method], params[:account_number], params[:id]) 
    
    if @errors.empty?

        # Flash Message
        session[:success] = "A Car Transaction has been successfully updated." 

        # Update the car in the database
        DB.execute("UPDATE transactions SET quantity = ?, payment_method = ?, account_number = ? WHERE id = ?", [params[:quantity], params[:payment_method], params[:account_number], params[:id]])

        redirect '/waiting'
    else 
        # Handle validation errors and re-render the edit form 
        original_transaction = DB.execute("SELECT * FROM transactions WHERE id = ?", [params[:id]]).first

        # Merge validation errors and re-render the edit form
        @transaction = {
            'id' => params[:id],
            'car_name' => params[:car_name] || original_transaction['car_name'],
            'car_brand' => params[:car_brand] || original_transaction['car_brand'],
            'car_color' => params[:car_color] || original_transaction['car_color'],
            'car_transmission' => params[:car_transmission] || original_transaction['car_transmission'],
            'car_price' => params[:car_price] || original_transaction['car_price'],
            'car_manufacture' => params[:car_manufacture] || original_transaction['car_manufacture'],
            'car_seat' => params[:car_seat] || original_transaction['car_seat'],
            'car_stock' => params[:car_stock] || original_transaction['car_stock'],
            'quantity' => params[:quantity] || original_transaction['quantity'],
            'payment_method' => params[:payment_method] || original_transaction['payment_method'],
            'account_number' => params[:account_number] || original_transaction['account_number'],
        }
        erb :'user/cars/edit_checkout', layout: :'layouts/main'
    end 

end 