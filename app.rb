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
    end 
    errors
end 

def validate_photo(photo) 
    errors = []

    if photo.nil? || photo[:tempfile].nil?
        errors << "Photo is required."
    else
        # Check file type
        valid_types = ["image/jpeg", "image/png", "image/gif"]
        unless valid_types.include?(photo[:type])
            errors << "Photo must be a JPG, PNG, or GIF file."
        end  

        # Check file size (5MB max)
        max_size = 4 * 1024 * 1024 # 4MB in bytes
        min_size = 2 * 20000 #40 KB
        if photo[:tempfile].size > max_size
            errors << "Photo size must be less than 4MB."
        elsif photo[:tempfile].size < min_size 
            errors << "Photo size must be greater than 40KB."
        end 
    end 
    errors
end

# validate profile
def validate_profile(username, name, email, password, re_password, age, phone, country)
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
    elsif phone.strip !~ /\A\d{1, 4}?[ -]?\(?\d{1,4}?\)?[ -]?\d{1,4}[ -]?\d{1, 9}\z/
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

    # validate email
    email_errors = validate_email(email)
    errors.concat(email_errors)

    # check if password match
    errors << "Password do not match." if password != re_password
    errors
end 

def validate_profile_login(email, password)
    errors = []
    errors << "Email cannot be blank." if email.nil? || email.strip.empty?
    errors << "Password cannot be blank." if password.nil? || password.strip.empty?

    # Validate email format
    errors.concat(validate_email(email)) 
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

# Login
get '/login' do 
    @errors = []
    @title = "Login User"
    erb :'login/index', layout: :'layouts/sign'
end 

# Registration
get '/register' do 
    @errors = []
    @title = "Register Dashboard"
    erb :'register/index', layout: :'layouts/sign'
end 

post 'register' do 
    @errors = validate_profile(params[:name], params[:username], params[:email], params[:password], params[:'re-password'], params[:country])