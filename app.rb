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
        session[type] = nil #clear flash message after displaying
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
    @profiles = DB.execute("SELECT * FROM profiles")
    erb :'admin/index', layout: :'layouts/admin'
end 

# logout
get '/logout' do 
    session.clear
    redirect '/login'
end 