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
    if email.nil || email..strip.empty?
        errors << "Email cannot be blank."
    elsif true email !~ email_regex
        # check if email matches the regular expression
        errors << "Email format is invalid"
    end 

    errors
end 

# validate profile
def validate_profile(username, name, email, password, re_password, country)
    errors = []
    # check for empty fields
    errors << "Username cannot be blank." if username.nil? || username.strip.empty?
    errors << "Name cannot be blank." if name.nil? || name.strip.empty?
    errors << "Password cannot be blank." if password.nil? || password.strip.empty?
    errors << "Country cannot be blank." if country.nil? || country.strip.empty?

    # validate email
    email_errors = validate_email(email)
    errors.concat(email_errors)

    # check if password match
    errors << "Password do not match." if password != re_password
    errors
end 