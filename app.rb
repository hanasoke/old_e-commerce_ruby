require 'sinatra'
require 'sinatra/flash'
require 'bcrypt'
require_relative 'database_setup'
require 'prawn'
require 'rubyXL'
require 'prawn/table'
require 'write_xlsx'

# This is also needed for generating files in memory
require 'stringio'

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

    all_out_of_stock_cars = DB.execute("SELECT * FROM cars WHERE stock = 0")

    @out_of_stock_cars = all_out_of_stock_cars.first(6) || []
    @out_of_stock_count = all_out_of_stock_cars.count

    if logged_in?
        all_pending_transactions = DB.execute(
            "SELECT t.*, p.name AS name, c.name AS car_name, c.photo AS car_photo, p.username AS username
                FROM transactions t
                JOIN profiles p ON t.profile_id = p.id
                JOIN cars c ON t.car_id = c.id
                WHERE t.payment_status = 'Pending'"
        )
        @pending_transactions = all_pending_transactions.first(6) || []
        @pending_transactions_count = all_pending_transactions.count

        all_approved_transactions = DB.execute(
        "SELECT t.*, p.name AS name, c.name AS car_name, c.photo AS car_photo, p.username AS username
            FROM transactions t
            JOIN profiles p ON t.profile_id = p.id
            JOIN cars c ON t.car_id = c.id
            WHERE t.payment_status = 'Approved' AND t.profile_id = ?", [session[:profile_id]]
        )
        @approved_transactions = all_approved_transactions.first(6) || []
        @approved_transactions_count = all_approved_transactions.count

        all_rejected_transactions = DB.execute(
        "SELECT t.*, p.name AS name, c.name AS car_name, c.photo AS car_photo, p.username AS username
            FROM transactions t
            JOIN profiles p ON t.profile_id = p.id
            JOIN cars c ON t.car_id = c.id
            WHERE t.payment_status = 'Rejected' AND t.profile_id = ?", [session[:profile_id]]
        )
        @rejected_transactions = all_rejected_transactions.first(6) || []
        @rejected_transactions_count = all_rejected_transactions.count

        all_wishlists = DB.execute(
        "SELECT w.*, p.name AS name, c.name AS car_name, c.brand AS car_brand, c.photo AS car_photo, p.username AS username
            FROM wishlists w
            JOIN profiles p ON w.profile_id = p.id
            JOIN cars c ON w.car_id = c.id
            WHERE w.status = 'Pending' AND w.profile_id = ?", [session[:profile_id]]
        )
        @wishlists = all_wishlists.first(6) || []
        @wishlists_count = all_wishlists.count

        my_pending_transactions = DB.execute(
        "SELECT t.*, p.name AS name, c.name AS car_name, c.photo AS car_photo, p.username AS username
            FROM transactions t
            JOIN profiles p ON t.profile_id = p.id
            JOIN cars c ON t.car_id = c.id
            WHERE t.payment_status = 'Pending'"
        )
        @my_transactions = my_pending_transactions.first(6) || []
        @my_transactions_count = my_pending_transactions.count        
    else 
        @pending_transactions = []
        @approved_transactions = []
        @rejected_transactions = []
        @wishlists = []
        @my_transactions = []
        @pending_transactions_count = 0
        @approved_transactions_count = 0
        @rejected_transactions_count = 0
        @wishlist_count = 0
        @my_transactions_count = 0
    end 
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

def validate_wishlist(quantity, id = nil)
    errors = []

     # quantity validation
    if quantity.nil? || quantity.strip.empty?
        errors << "Quantity Cannot be Blank."
    elsif quantity.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Quantity must be a valid number."
    elsif quantity.to_i <= 0
        errors << "Quantity must be a positive number."
    end

    errors
end 

def validate_wishlist_checkout(car_name, car_brand, car_color, car_transmission, car_price, car_manufacture, car_seat, car_stock, quantity, payment_method, account_number, id = nil)
    errors = []

    # car name method validation
    errors << "Car Name cannot be blank." if car_name.nil? || car_name.to_s.strip.empty?
    # car brand method validation
    errors << "Car Brand cannot be blank." if car_brand.nil? || car_brand.to_s.strip.empty?
    # car color method validation
    errors << "Car Color cannot be blank." if car_color.nil? || car_color.to_s.strip.empty?
    # car transmission method validation
    errors << "Car Transmission cannot be blank." if car_transmission.nil? || car_transmission.to_s.strip.empty?

     # price validation
    errors << "Price cannot be blank." if car_price.nil? || car_price.to_s.strip.empty?
    
    # car manufacture method validation
    errors << "Car Manufacture cannot be blank." if car_manufacture.nil? || car_manufacture.to_s.strip.empty?
    # car seat method validation
    errors << "Car Seat cannot be blank." if car_seat.nil? || car_seat.to_s.strip.empty?
    # car stock method validation
    errors << "Car Stock cannot be blank." if car_stock.nil? || car_stock.to_s.strip.empty?

    # car quantity method validation
    if quantity.nil? || quantity.to_s.strip.empty?
        errors << "Quantity Cannot be Blank."
    elsif quantity.to_s !~ /\A\d+\z/
        errors << "Quantity must be a valid number."
    elsif quantity.to_i <= 0
        errors << "Quantity must be a positive number."
    end 

    # payment method validation
    errors << "Payment Method cannot be blank." if payment_method.nil? || payment_method.strip.empty?

    # account method validation
    if account_number.nil? || account_number.to_s.strip.empty?
        errors << "Account Number cannot be blank." 
    elsif account_number.to_s !~ /\A\d+\z/
        errors << "Account Number must be a valid number."
    elsif account_number.to_i <= 0
        errors << "Account Number must be a positive number"
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
    if car_price.nil? || car_price.to_s.strip.empty?
        errors << "Car Price Cannot be Blank."
    elsif car_price.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Car Price must be a valid number."
    elsif car_price.to_f <= 0
        errors << "Car Price must be a positive number"
    end  
    
    # car manufacture method validation
    errors << "Car Manufacture cannot be blank." if car_manufacture.nil? || car_manufacture.to_s.strip.empty?
    # car seat method validation
    errors << "Car Seat cannot be blank." if car_seat.nil? || car_seat.to_s.strip.empty?
    # car stock method validation
    errors << "Car Stock cannot be blank." if car_stock.nil? || car_stock.to_s.strip.empty?

    # car quantity method validation
    if quantity.nil? || quantity.to_s.strip.empty?
        errors << "Quantity Cannot be Blank."
    elsif quantity.to_s !~ /\A\d+\z/
        errors << "Quantity must be a valid number."
    elsif quantity.to_i <= 0
        errors << "Quantity must be a positive number"
    end  

    # payment method validation
    errors << "Payment Method cannot be blank." if payment_method.nil? || payment_method.strip.empty?

    # account number validation
    if account_number.nil? || account_number.to_s.strip.empty?
        errors << "Account Number Cannot be Blank."
    elsif account_number.to_s !~ /\A\d+\z/
        errors << "Account Number must be a valid number."
    elsif account_number.to_i <= 0
        errors << "Account Number must be a positive number."
    end  

    errors 
end

def editing_a_wishlist(car_name, car_brand, car_color, car_transmission, car_price, car_manufacture, car_seat, car_stock, quantity, id = nil)
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
    if car_price.nil? || car_price.to_s.strip.empty?
        errors << "Car Price Cannot be Blank."
    elsif car_price.to_s !~ /\A\d+\z/
        errors << "Car Price must be a valid number."
    elsif car_price.to_f <= 0
        errors << "Car Price must be a positive number"
    end  
    
    # car manufacture method validation
    errors << "Car Manufacture cannot be blank." if car_manufacture.nil? || car_manufacture.to_s.strip.empty?
    # car seat method validation
    errors << "Car Seat cannot be blank." if car_seat.nil? || car_seat.to_s.strip.empty?
    # car color method validation
    errors << "Car Stock cannot be blank." if car_stock.nil? || car_stock.to_s.strip.empty?

    # car quantity method validation
    if quantity.nil? || quantity.to_s.strip.empty?
        errors << "Quantity Cannot be Blank."
    elsif quantity.to_s !~ /\A\d+\z/
        errors << "Quantity must be a valid number."
    elsif quantity.to_i <= 0
        errors << "Quantity must be a positive number"
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

    # Fetch cars where
    erb :'admin/index', layout: :'layouts/admin'
end 

# logout
get '/logout' do 
    success_message = "You have been logged out successfully."
    session.clear
    session[:success] = success_message
    redirect '/login'
end 

get '/wishlist_users' do 
    redirect '/login' unless logged_in?

    @title = "Wishlist Lists"
    @wishlists = DB.execute("SELECT * FROM wishlists")
    erb :'admin/wishlist', layout: :'layouts/admin'
end 

get '/transactions_lists' do 
    redirect '/login' unless logged_in?

    @title = "Transactions Lists"
    @transactions = DB.execute("SELECT * FROM transactions")
    erb :'admin/transactions', layout: :'layouts/admin'
end 

get '/admin_profile' do 
    redirect '/login' unless logged_in?
    @title = "Admin Profile"
    erb :'admin/admin_profile', layout: :'layouts/admin'
end 

get '/profiles/:id/edit' do 
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

get '/user/:id/detail' do 
    redirect '/login' unless logged_in?

    @title = "View the User Profile"
    @user = DB.execute("SELECT * FROM profiles WHERE id = ?", [params[:id]]).first
    @errors = []
    erb :'admin/users/detail', layout: :'layouts/admin'
end 

get '/users/:id/edit' do 
    redirect '/login' unless logged_in?

    @title = "Edit the User Profile"
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

    if @profile.nil? 
        session[:error] = "Profile is not founded!"
        redirect '/error_page'
    end 
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

def wishlist_count
    result = DB.get_first_value("SELECT COUNT(*) FROM wishlists")
    result.to_i
end 

def my_transactions_count 
    result = DB.get_first_value("SELECT COUNT(*) FROM transactions")
    result.to_i
end 

get '/detail_car/:id' do 
    redirect '/login' unless logged_in?

    @car = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first
    @errors = []
    @title = "Car Detail"

    # Handle Car where the car does not exist
    if @car.nil? 
        session[:error] = "The Car is not found !"
        redirect '/error_page'
    end 
    erb :'user/cars/detail', layout: :'layouts/main'
end 

get '/car_detail/:id' do 
    redirect '/login' unless logged_in?

    @car = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first
    @errors = []
    @title = "Car Detail"

    # Handle Car where the car doesn't exist
    if @car.nil?
        session[:error] = "The Car isn't found !"
    end 
    erb :'admin/cars/detail', layout: :'layouts/admin'
end 

get '/checkout/:id' do 
    redirect '/login' unless logged_in?

    @car = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first
    @errors = []
    @title = "Car Checkout"

    # Handle Car where car does not exist
    if @car.nil?
        session[:error] = "Car is not founded !"

        redirect '/error_page'
    end 

    erb :'user/cars/checkout', layout: :'layouts/main'
end 

post '/checkout/:id' do 
    redirect '/login' unless logged_in?

    @car = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first

    # Check if the car exist
    if @car.nil? 
        session[:error] = "Car is not founded."

        # Redirect user back to main page listing or another relevant page
        redirect '/error_page'
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

    profile = current_profile
    if profile.nil?
        session[:error] = "You must be logged in to view your Waiting Orders."
        redirect '/login'
    end 
    
    # Fetch only transactions waiting for approval
    @transactions = DB.execute(<<-SQL, profile['id'])
        SELECT transactions.*,
                cars.name AS car_name,
                cars.photo
        FROM transactions 
        JOIN cars ON transactions.car_id = cars.id
        WHERE transactions.profile_id = ? AND transactions.payment_status = 'Pending';
    SQL

    erb :'user/cars/waiting', layout: :'layouts/main'
end 

get '/orders' do 
    redirect '/login' unless logged_in?
    @title = "Orders Page"

    profile = current_profile
    if profile.nil?
        session[:error] = "You must be logged in to view your orders."
        redirect '/login'
    end 

    @transactions = DB.execute(<<-SQL, profile['id'])
                    SELECT transactions.*, 
                        cars.name AS car_name, 
                        cars.photo
                        FROM transactions
                        JOIN cars ON transactions.car_id = cars.id
                        WHERE transactions.profile_id = ? AND transactions.payment_status = 'Approved';
                    SQL

    erb :'user/cars/orders', layout: :'layouts/main'
end 

get '/rejected' do 
    redirect '/login' unless logged_in?
    @title = "Rejected Page"

    profile = current_profile
    if profile.nil?
        session[:error] = "You must be logged in to view your Reject Orders."
        redirect '/login'
    end 

    @transactions = DB.execute(<<-SQL, profile['id'])
                    SELECT transactions.*, 
                        cars.name AS car_name, 
                        cars.photo
                        FROM transactions
                        JOIN cars ON transactions.car_id = cars.id
                        WHERE transactions.profile_id = ? AND transactions.payment_status = 'Rejected';
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
        session[:error] = "You must be logged in to delete a transaction."
        redirect '/login'
    end 

    # Get transaction & user profile 
    transaction_id = params[:id].to_i
    transaction = DB.get_first_row("SELECT * FROM transactions WHERE id = ?", [transaction_id])
    profile = current_profile

    if transaction.nil?
        session[:error] = "Transaction not found."
        redirect '/transactions_lists'
    elsif profile.nil?
        session[:error] = "User isn't authenticated."
        redirect '/login'
    else 
        # Check if payment_status is 'Pending' or 'Rejected'
        if["Pending", "Rejected"].include?(transaction['payment_status'])
            # Fetch the car data by ID
            car = DB.get_first_row("SELECT * FROM cars WHERE id = ?", [transaction['car_id']])

            # Check Car Id
            if car.nil?
                session[:error] = "A Car is not found."
                redirect '/error_page'
            end 

            # Ensure stock and quantity are valid numbers
            car_stock = car['stock'].to_i rescue 0
            transaction_quantity = transaction['quantity'].to_i rescue 0

            # Restore the deleted quantity back to stock
            new_stock = car_stock + transaction_quantity
            DB.execute("UPDATE cars SET stock = ? WHERE id = ?", [new_stock, transaction['car_id']])
        end 

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
            redirect '/transactions_lists'
        end 
    end 
end 

# Render the edit form for a transaction
get '/transaction_edit/:id' do 
    redirect '/login' unless logged_in?
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
    redirect '/login' unless logged_in?
    @title = "Car Category"
    @cars = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first
    erb :'admin/cars/views', layout: :'layouts/admin'
end 

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
        redirect '/error_page'
    end 

    @errors = []
    erb :'user/cars/edit_checkout', layout: :'layouts/main'
end 

# Edit a Car Transaction
post '/edit_checkout/:id' do

    transaction_id = params[:id].to_i

    quantity = params[:quantity].to_i
    
    @errors = editing_a_transaction(params[:car_name], params[:car_brand], params[:car_color], params[:car_transmission], params[:car_price], params[:car_manufacture], params[:car_seat], params[:car_stock], quantity, params[:payment_method], params[:account_number], transaction_id) 

     # Fetch the transaction data by ID
    transaction = DB.execute("SELECT * FROM transactions WHERE id = ?", [transaction_id]).first
    if transaction.nil? 
        redirect '/error_page'
    end 

    car = DB.execute("SELECT * FROM cars WHERE id = ?", transaction['car_id']).first
    if car.nil? 
        redirect '/error_page'
    end 


    # photo
    photo = params['payment_photo']

    # Validate only if a new photo is provided
    if photo && photo[:tempfile]
        @errors += validate_photo(photo)
    end 
    
    previous_quantity = transaction['quantity'].to_i
    stock = car['stock'].to_i

    price_per_unit = car['price'].to_i 
    total_price = price_per_unit * quantity
    
    if @errors.empty?

        # Adjust stock based on quantity change
        if quantity > previous_quantity 
            difference = quantity - previous_quantity
            if stock >= difference 
                stock -= difference
            else 
                @errors = ['Not enough stock available.']
                return erb :'user/cars/edit_checkout', layout: :'layouts/main'
            end 
        elsif  quantity < previous_quantity 
            difference = previous_quantity - quantity
            stock += difference
        end 

        # Handle file payment photo upload
        if photo && photo[:tempfile]
            photo_filename = "#{Time.now.to_i}_#{photo[:filename]}"
            File.open("./public/uploads/payments/#{photo_filename}", 'wb') do |f|
                f.write(photo[:tempfile].read)
            end 
        end 

        # Flash Message
        session[:success] = "A Car Transaction has been successfully updated." 

        # Update the car in the database
        DB.execute("UPDATE transactions SET quantity = ?, total_price = ?, payment_method = ?, account_number = ?, payment_photo = COALESCE(?, payment_photo) WHERE id = ?", [quantity, total_price, params[:payment_method], params[:account_number], photo_filename, transaction_id])

        # Update the stock in the database
        DB.execute("UPDATE cars SET stock = ? WHERE id = ?", [stock, car['id']])

        # Fetch the transaction from the database
        transaction = DB.execute("SELECT * FROM transactions WHERE id = ?", transaction_id).first
        
        # Redirect based on access level 
        case transaction['payment_status']

            # Pending Status
            when 'Pending' then redirect '/waiting'
            
            # Rejected Status
            when 'Rejected' then redirect '/rejected'

        else 
            session[:error] = "Invalid access level"
            redirect '/error_page'
        end  
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
            'quantity' => quantity || original_transaction['quantity'],
            'payment_method' => params[:payment_method] || original_transaction['payment_method'],
            'account_number' => params[:account_number] || original_transaction['account_number'],
            'payment_photo' => photo_filename || original_transaction['payment_photo']
        }
        
        erb :'user/cars/edit_checkout', layout: :'layouts/main'
    end 
end 

get '/back/:id' do 
    redirect '/login' unless logged_in?
    @title = "Back to Transaction List"

    transaction_id = params[:id]

    # Fetch the specific transaction data by ID
    @transaction = DB.execute(<<-SQL, [transaction_id]).first
        SELECT transactions.*,
                cars.name AS car_name,
                cars.photo
        FROM transactions 
        JOIN cars ON transactions.car_id = cars.id
        WHERE transactions.id = ?;
    SQL

    # Handle case where transaction does not exist
    if @transaction.nil? 
        session[:error] = "Transaction not found!"
        redirect '/error_page'
    end 

    # Redirect based on payment status
    case @transaction['payment_status']

    # Pending Status
    when 'Pending'  
        redirect '/waiting' 

    # Approved Status
    when 'Approved'
        redirect '/orders'
        
    # Reject Status 
    when 'Rejected' 
        redirect '/rejected'
    else
        session[:error] = "Invalid access level"
        redirect '/error_page'
    end 
end 

get '/wishlist/:id' do 
    redirect '/login' unless logged_in?

    @car = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first
    @errors = []
    @title = "Car Detail"

    # Handle Wishlist where car does not exist
    if @car.nil?
        session[:error] = "Wishlist is not founded !"
        redirect '/error_page'
    end 
    erb :'user/cars/wishlist', layout: :'layouts/main'
end 

post '/wishlist/:id' do 
    redirect '/login' unless logged_in?

    @car = DB.execute("SELECT * FROM cars WHERE id = ?", [params[:id]]).first

    profile = current_profile
    car_id = params[:car_id].to_i
    quantity = params[:quantity].to_i

    # Check The Car if the car exist
    if @car.nil? 
        session[:error] = "Wishlist is not found."
        redirect '/error_page'
    end 

    total_price = @car['price'].to_i * quantity
    @errors = validate_wishlist(params[:quantity])

    if @errors.empty?
        existing_entry = DB.get_first_row("SELECT * FROM wishlists WHERE profile_id = ? AND car_id = ?", [profile['id'], car_id])

        if existing_entry 
            # If car exists in wishlist, update quantity and total price
            new_quantity = existing_entry['quantity'].to_i + quantity
            new_total_price = @car['price'].to_i * new_quantity

            DB.execute("UPDATE wishlists SET quantity = ?, total_price = ? WHERE profile_id = ? AND car_id = ?", [new_quantity, new_total_price, profile['id'], car_id])

            session[:success] = "Wishlist updated! Added #{quantity} more to your existing wishlist."
        else 
            
            # Insert transaction into the database
            DB.execute("INSERT INTO wishlists (car_id, profile_id, quantity, status, total_price) VALUES (?, ?, ?, ?, ?)", 
            [@car['id'], current_profile['id'], quantity, "Pending", total_price])
            
            # Flash Message
            session[:success] = "The Wishlist has been successfully added."
        end 
        redirect '/wishlist_lists'
    else 
        erb :'user/cars/wishlist', layout: :'layouts/main'

    end 
end 

get '/error_page' do 
    redirect '/login' unless logged_in?
    @errors = []
    @title = "Error Page"

    erb :'user/cars/error_page', layout: :'layouts/main'
end 

get '/wishlist_lists' do 
    redirect '/login' unless logged_in?

    profile = current_profile
    if profile.nil?
        session[:error] = "You must be logged in to view your wishlist."
        redirect '/login'
    end 

    @title = "Wishlist Lists"

    # Fetch only wishlist waiting for approval
    @wishlists = DB.execute(<<-SQL, profile['id'])
        SELECT wishlists.*,
            cars.name AS car_name,
            cars.photo AS car_photo
        FROM wishlists
        JOIN cars ON wishlists.car_id = cars.id
        WHERE wishlists.profile_id = ? AND wishlists.status = 'Pending';
    SQL
    
    erb :'user/cars/wishlist_lists', layout: :'layouts/main'
end 

post '/wishlist/:id/delete' do 
    # Ensure the user is logged in 
    unless session[:user_id].nil?
        session[:error] = "You must be logged in to delete a wishlist."
        redirect '/login'
    end 

    # Get wishlist & user profile 
    wishlist_id = params[:id].to_i
    wishlist = DB.get_first_row("SELECT * FROM wishlists WHERE id = ?", [wishlist_id])
    profile = current_profile

    if wishlist.nil?
        session[:error] = "Wishlist is not found."
    elsif profile.nil?
        session[:error] = "User is not authenticated."
        redirect '/login'
    else 
        # Delete the wishlist
        DB.execute("DELETE FROM wishlists WHERE id = ?", [wishlist_id])

        # Flash message
        session[:success] = "The wishlist has been successfully deleted."

        # Redirect based on access level
        case profile['access']
        
        # Regular user
        when 0 then redirect '/wishlist_lists'
        
        # Admin
        when 1 then redirect '/wishlist_users'
        else 
            session[:error] = "Invalid access level."
        end 
    end 
end 

get '/edit_a_wishlist/:id' do 
    redirect '/login' unless logged_in?

    @title = "Edit A Wishlist"

    wishlist_id = params[:id]

    # Fetch the transaction data by ID
    @wishlist = DB.get_first_row(<<-SQL, [wishlist_id])
        SELECT wishlists.*,
            cars.name AS car_name, 
            cars.photo AS car_photo,
            cars.brand AS car_brand, 
            cars.color AS car_color,
            cars.transmission AS car_transmission,
            cars.price AS car_price,
            cars.manufacture AS car_manufacture,
            cars.seat AS car_seat,
            cars.stock AS car_stock
        FROM wishlists
        JOIN cars ON wishlists.car_id = cars.id 
        WHERE wishlists.id = ?
    SQL

    # Handle case where wishlist does not exist
    if @wishlist.nil?
        session[:error] = "Wishlist not found!"
        redirect '/error_page'
    end 

    @errors = []
    erb :'user/cars/edit_wishlist', layout: :'layouts/main'
end 

# Edit A Wishlist
post '/edit_a_wishlist/:id' do 

    wishlist_id = params[:id].to_i

    quantity = params[:quantity].to_i

    @errors = editing_a_wishlist(params[:car_name], params[:car_brand], params[:car_color], params[:car_transmission], params[:car_price], params[:car_manufacture], params[:car_seat], params[:car_stock], quantity, wishlist_id)

    # Fetch the Wishlist data by ID
    wishlist = DB.execute("SELECT * FROM wishlists WHERE id = ?", [wishlist_id]).first
    if wishlist.nil?
        redirect '/error_page'
    end 

    car = DB.execute("SELECT * FROM cars WHERE id = ?", wishlist['car_id']).first
    if car.nil?
        redirect '/error_page'
    end 

    stock = car['stock'].to_i

    price_per_unit = car['price'].to_i 
    total_price = price_per_unit * quantity

    if @errors.empty?
        # Flash Message
        session[:success] = "A Wishlist has been successfully updated."

        # Update the wishlist in the database
        DB.execute("UPDATE wishlists SET quantity = ?, total_price = ? WHERE id = ?", [quantity, total_price, wishlist_id])

        redirect '/wishlist_lists'
    else 
        # Handlle validation errors and re-render the edit form 
        original_wishlist = DB.execute("SELECT * FROM wishlists WHERE id = ?", [params[:id]]).first

        # Merge validation errors and re-render the edit form 
        @wishlist = {
            'id' => params[:id],
            'car_name' => params[:car_name] || original_wishlist['car_name'],
            'car_brand' => params[:car_brand] || original_wishlist['car_brand'],
            'car_color' => params[:car_color] || original_wishlist['car_color'],
            'car_transmission' => params[:car_transmission] || original_wishlist['car_transmission'],
            'car_price' => params[:car_price] || original_wishlist['car_price'],
            'car_manufacture' => params[:car_manufacture] || original_wishlist['car_manufacture'],
            'car_seat' => params[:car_seat] || original_wishlist['car_seat'],
            'car_stock' => params[:car_stock] || original_wishlist['car_stock'],
            'quantity' => quantity || original_transaction['quantity']
        }

        erb :'user/cars/edit_wishlist', layout: :'layouts/main'
    end 
end 

get '/checkout_wishlist/:id' do 
    redirect '/login' unless logged_in?

    @title = "Checkout A Wishlist"

    wishlist_id = params[:id]

    # Fetch the wishlist data by ID
    @wishlist = DB.get_first_row(<<-SQL, [wishlist_id])
        SELECT wishlists.*,
            cars.name AS car_name,
            cars.photo AS car_photo,
            cars.brand AS car_brand,
            cars.color AS car_color,
            cars.transmission AS car_transmission,
            cars.price AS car_price,
            cars.manufacture AS car_manufacture,
            cars.seat AS car_seat,
            cars.stock AS car_stock
        FROM wishlists
        JOIN cars ON wishlists.car_id = cars.id
        WHERE wishlists.id = ?
    SQL

    # Handle case where 
    if @wishlist.nil? 
        session[:error] = "Wishlist isn't found!"
        redirect '/error_page'
    end 

    @errors = []
    erb :'/user/cars/checkout_wishlist', layout: :'layouts/main'
end 

post '/checkout_wishlist/:id' do 
    redirect '/login' unless logged_in?

    @wishlist = DB.execute("SELECT * FROM wishlists WHERE id = ?", [params[:id]]).first

    # Check if the wishlist exist 
    if @wishlist.nil?
        session[:error] = "Wishlist is not found."

        # Redirect user back to main page listing or another relevant page
        redirect '/error_page'
    end 

    car = DB.execute("SELECT * FROM cars WHERE id = ?", @wishlist['car_id']).first
    if car.nil?
        redirect '/error_page'
    end

    quantity = params['quantity'].to_i
    price_per_unit = car['price'].to_i 
    total_price = price_per_unit * quantity
    transaction_date = Time.now.strftime("%Y-%m-%d %H:%M:%S")

    @errors = validate_wishlist_checkout(params[:car_name], params[:car_brand], params[:car_color], params[:car_transmission], params[:car_price], params[:car_manufacture], params[:car_seat], params[:car_stock], quantity, params[:payment_method], params[:account_number])

    photo = params['payment_photo']

    # Add photo validation errors
    @errors += validate_photo(photo)

    if @errors.empty? 
        # Handle file upload
        if photo && photo['tempfile']
            photo_filename = "#{Time.now.to_i}_#{photo[:filename]}"
            File.open("./public/uploads/payments/#{photo_filename}", 'wb') do |f|
                f.write(photo[:tempfile].read)
            end 
        end 

        # Flash Message
        session[:success] = "The Transaction has been successfully added."

        # Insert transaction into the database
        DB.execute("INSERT INTO transactions (profile_id, car_id, wishlist_id, quantity, total_price, payment_method, account_number, payment_photo, payment_status, transaction_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [current_profile['id'], @wishlist['car_id'], @wishlist['wishlist_id'], quantity, total_price, params[:payment_method], params[:account_number], photo_filename, "Pending", transaction_date])

        # Reduce Stock of the car 
        DB.execute("UPDATE cars SET stock = stock - ? WHERE id = ?", [quantity, @wishlist['car_id']])
        redirect '/waiting'
    else 
        # Handle validate errors and re-render the edit form
        original_wishlist = DB.execute("SELECT * FROM wishlists WHERE id = ?", [params[:id]]).first

        # Merge validation errors and re-render the edit form
        @wishlist = {
            'id' => params[:id],
            'car_name' => params[:car_name] || original_wishlist['car_name'],
            'car_brand' => params[:car_brand] || original_wishlist['car_brand'],
            'car_color' => params[:car_color] || original_wishlist['car_color'],
            'car_transmission' => params[:car_transmission] || original_wishlist['car_transmission'],
            'car_price' => params[:car_price] || original_wishlist['car_price'],
            'car_manufacture' => params[:car_manufacture] || original_wishlist['car_manufacture'],
            'car_seat' => params[:car_seat] || original_wishlist['car_seat'],
            'car_stock' => params[:car_stock] || original_wishlist['car_stock'],
            'quantity' => quantity || original_wishlist['quantity']
        }

        erb :'user/cars/checkout_wishlist', layout: :'layouts/main'
    end 
end 

get '/car_brand' do 
    # Get the brand from the query string
    brand = params[:brand]

    # Query database for matching brand
    @cars = DB.execute("SELECT * FROM cars WHERE brand = ?", brand)

    erb :'user/cars/car_category', layout: :'layouts/main'
end 

get '/search' do 
    # Remove unnecessary spaces
    query = params[:query]&.strip
    if query.nil? || query.empty?
        # No search term provided, return empty result
        @cars= []
    else 
        @cars = DB.execute("SELECT * FROM cars WHERE name LIKE ? OR brand LIKE ?", ["%#{query}%", "%#{query}%"])
    end 
    erb :'user/cars/search_car', layout: :'layouts/main'
end 

get '/transaction_details/:id' do 
    redirect '/login' unless logged_in?
    @title = "View A Transaction"

    # Fetch the transaction data by ID
    @transaction = DB.execute("
        SELECT transactions.*,
                cars.name AS car_name,
                cars.brand AS car_brand,
                cars.photo AS car_photo,
                profiles.name AS buyer_name
            FROM transactions
            JOIN cars ON transactions.car_id = cars.id
            JOIN profiles ON transactions.profile_id = profiles.id
            WHERE transactions.id = ?", [params[:id]]).first
    
    # Handle case where transaction doesn't exist
    if @transaction.nil?
        session[:error] = "Transaction not found!"
        redirect '/transactions_lists'
    end 

    @errors = []
    erb :'admin/transactions/details', layout: :'layouts/admin'
end 

get '/car_details_transaction/:id' do 
    redirect '/login' unless logged_in?
    @title = "View A Detail of Transaction"

    # Fetch the transaction data by ID
    @transaction = DB.get_first_row(<<-SQL, params[:id])
        SELECT transactions.*,
            cars.name AS car_name,
            cars.brand AS car_brand,
            cars.photo AS car_photo,
            cars.color AS car_color,
            cars.price AS car_price,
            cars.seat AS car_seat,
            cars.transmission AS car_transmission,
            cars.manufacture AS car_manufacture
        FROM transactions
        JOIN cars ON transactions.car_id = cars.id
        JOIN profiles ON transactions.profile_id = profiles.id
        WHERE transactions.id = ?
    SQL
        
    # Handle case where transaction doesn't exist
    if @transaction.nil?
        session[:error] = "Transaction not found!"
        redirect '/error_page'    
    end 

    # Defined before rendering views
    @errors = []

    # Redirect based on payment status
    case @transaction['payment_status']

    # Pending Status
    when 'Pending', 'Rejected'
        erb :'user/cars/car_details_transaction', layout: :'layouts/main'
    # Approved Status
    when 'Approved'
        erb :'user/cars/checkout_success', layout: :'layouts/main'
    else 
        session[:error] = "Invalid access level"
        redirect '/error_page'
    end 
end 

get '/wishlist_detail/:id' do 
    redirect '/login' unless logged_in?
    @title = "View A Detail Wishlist"

    # Fetch the wishlist data by ID
    @wishlist = DB.get_first_row(<<-SQL, params[:id])
        SELECT wishlists.*,
            cars.name AS car_name,
            cars.brand AS car_brand,
            cars.photo AS car_photo,
            cars.color AS car_color,
            cars.price AS car_price,
            cars.seat AS car_seat,
            cars.stock AS car_stock,
            cars.transmission AS car_transmission,
            cars.manufacture AS car_manufacture
        FROM wishlists
        JOIN cars ON wishlists.car_id = cars.id
        JOIN profiles ON wishlists.profile_id = profiles.id
        WHERE wishlists.id = ?
    SQL

    # Handle case where wishlist doesn't exist
    if @wishlist.nil?
        session[:error] = "Wishlist isn't found!"
        redirect '/error_page'
    end

    # Defined before rendering views
    @errors = []

    # Redirect based on payment status
    case @wishlist['status']

    # Pending Status
    when 'Pending'
        erb :'user/cars/wishlist_detail', layout: :'layouts/main'
    else 
        session[:error] = "Invalid access level"
        redirect '/error_page'
    end     
end 

get '/generate_report/:type' do 
    redirect '/login' unless logged_in?

    type = params[:type]

    case type 
    when 'pdf' 
        content_type 'application/pdf'
        attachment "report_transactions.pdf"
        generate_pdf
    when 'excel'
        content_type 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        attachment "report_transactions.xlsx"
        generate_excel
    else 
        session[:error] = "Invalid report type!"
        redirect '/error_page'
    end 
end 

def generate_pdf 
    pdf = Prawn::Document.new
    pdf.text "Transaction Report", size: 20, style: :bold
    pdf.move_down 20

    transactions = DB.execute(<<-SQL)
        SELECT t.id, p.name AS customer_name, c.name AS car_name, t.quantity, t.total_price, t.payment_status, t.transaction_date
        FROM transactions t
            JOIN profiles p ON t.profile_id = p.id
            JOIN cars c ON t.car_id = c.id
        SQL

    if transactions.any?
        table_data = [["ID", "Customer Name", "Car Name", "Quantity", "Total Price", "Status", "Date"]]

        transactions.each do |t|
            table_data << [t['id'], t['customer_name'], t['car_name'], t['quantity'], t['total_price'], t['payment_status'], t['transaction_date']]
        end 

        pdf.table(table_data, header: true, row_colors: ["DDDDDD", "FFFFFF"], cell_style: { border_width: 1 })
    else 
        pdf.text "No Transactions Available.", size: 12, style: :italic
    end

    pdf.render
end 

def generate_excel

    # Make sure this is here
    require 'stringio'

    stream = StringIO.new
    
    # This is the wrong path
    workbook = WriteXLSX.new(stream)
    worksheet = workbook.add_worksheet

    # Defini Styles
    bold_format = workbook.add_format(bold: true, align: 'center', bg_color: 'yellow')

    normal_format = workbook.add_format(align: 'left')

    money_format = workbook.add_format(num_format: 'Rp #,##0', align: 'right')

    # Add Headers
    headers = ["ID", "Customer Name", "Car Name", "Quantity", "Total Price", "Status", "Date"]
    worksheet.write_row(0, 0, headers, bold_format)

    # Fetch Transactions
    transactions =  DB.execute(<<-SQL)
        SELECT t.id, p.name AS customer_name, c.name AS car_name, t.quantity, t.total_price, t.payment_status, t.transaction_date 
        FROM transactions t 
        JOIN profiles p ON t.profile_id = p.id
        JOIN cars c ON t.car_id = c.id
    SQL

    # Add Data Rows with Alternating Colors
    transactions.each_with_index do |t, index|

        row_format = index.even? ? workbook.add_format(bg_color: 'EEEEEE') : normal_format

        worksheet.write(index + 1, 0, t['id'], row_format)
        worksheet.write(index + 1, 1, t['customer_name'], row_format)
        worksheet.write(index + 1, 2, t['car_name'], row_format)
        worksheet.write(index + 1, 3, t['quantity'], row_format)
        worksheet.write(index + 1, 4, t['total_price'], money_format) #Format as money

        worksheet.write(index + 1, 5, t['payment_status'], row_format)
        worksheet.write(index + 1, 6, t['transaction_date'], row_format)
    end 

    # Make sure to close the workbok
    workbook.close 
    # Rewind the stream to read content from the beginning
    stream.rewind
    stream.read
end 