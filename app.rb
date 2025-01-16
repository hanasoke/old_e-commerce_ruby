require 'sinatra'
require 'bcrypt'
require_relative 'database_setup'

enable :sessions

# Helper methods
def logged_in?
    session[:profile_id] != nil 
end 

def current_profile
    @current_profile ||= DB.execute("SELECT * FROM profiles WHERE id = ?", [session[:profile_id]]).first if logged_in?
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
def validate_profile(username, name, email, password, re_password, age, phone, country, access)
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

def editing_profile(name, username, email, age, phone, country, editing: false)
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

def validate_car(name, type, brand, transmission, seat, machine, power, price, stock, manufacture id = nil)
    errors = []
    # check for empty fields
    errors << "Name cannot be blank." if name.nil? || name.strip.empty?

    # Check for unique name
    query = id ? "SELECT id FROM cars WHERE LOWER(name) = ? AND id != ?" : "SELECT id FROM cars WHERE LOWER(name) = ?"
    existing_car = DB.execute(query, id ? [name.downcase, id] : [name.downcase]).first
    errors << "Name already exist. Please choose a different name." if existing_car

    # Other Validation 
    errors << "type cannot be blank." if type.nil? || type.strip.empty?

    # brand validation
    errors << "brand cannot be blank." if brand.nil? || brand.strip.empty?

    # transmission validation
    errors << "transmission cannot be blank." if transactions.nil? || transactions.strip.empty?

    # seat validation
    if seat.nil? || seat.to_i < 1 || seat.to_i > 10
        errors << "Seat must be a number between 1 to 10."
    end

    # machine validation
    errors << "machine cannot be blank." if machine.nil? || machine.strip.empty?

    # power validation
    errors << "power cannot be blank." if power.nil? || power.strip.empty?    

    # price validation
    if price.nil? || price.strip.empty?
        errors << "price cannot be blank."
    
    elsif price.to_f <= 0
        errors << "Price must be a positive number" 

    elsif price.to_s !~ /\A\d+(\.\d{1,2})?\z/
        errors << "Price must be a valid number"
    end 

    # power validation
    errors << "stock cannot be blank." if stock.nil? || stock.strip.empty?

    # Validate manufacture date
    if manufacture.nil? || manufacture.strip.empty? || !manufacture.match(/^\d{4}-\d{2}-\d{2}$/)
        errors << "Manufacture date must be a valid date (YYYY-MM-DD)."
    end 

    errors
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

        # Flash message
        session[:success] = "Your Account has been registered."

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
    session.clear
    redirect '/login'
end 

get '/payment_lists' do 
    @title = "Payment Lists"
    erb :'admin/payments', layout: :'layouts/admin'
end 

get '/transactions_lists' do 
    @title = "Transactions Lists"
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
    @errors = editing_profile(params[:name], params[:username], params[:email], params[:age], params[:phone], params[:country], editing: false)

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
        DB.execute("UPDATE profiles SET name = ?, username = ?, email = ?, age = ?, country = ?, photo = COALESCE(?, photo) WHERE id = ?", [params[:name], params[:username], params[:email], params[:age], params[:country], photo_filename, params[:id]])
        redirect '/admin_profile'
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
            'photo' => photo_filename || original_profile['photo']
        }
        erb :'admin/edit_admin_profile', layout: :'layouts/sign'
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
        reset_url = "http://localhost:4567/reset_password/#{reset_token}"
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
# post '/add' do 
#     @errors = validate_car()