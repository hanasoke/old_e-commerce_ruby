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