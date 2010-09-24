You must remember this
----------------------

This project started life as a test project for learning about GIT, Ruby, Sinatra, and Active Record.

My original aim was to build a very simple web application that demonstrated a complete round-trip of user login, and log out.

It was fairly simple to do and an excellent learning experience as I have come from a Java world, but I found a out of gaps in other people's documentation and, in particular, no simple, canonical examples for how I would do such a simple thing.  I felt I had to work out far too much of this as I went.

Proposed Feature Set for v1
---------------------------
* Log in with username or email and password --> Logged in User screen (done)
* Log out (but remember who I am) --> Login screen (done)
* Log out completely --> Login screen (done)
* New User Registration --> sends verification email with link (done)
						--> 'Please check your email' screen. (done)
* New User Verification --> User is verified message on Logged in User screen (done)
* User Delete Self (done)
* User Edit own email, password and preferences (done)
* Forgot password --> Enter Email (done)
					--> send password reset link, or
					--> email not known
* Passwords must be stored securely (done)
* User roles (done - needs formal tests)
* terms and conditions (todo)
* privacy policy (todo)

Proposed features for v1.1
--------------------------
* oAuth authentication

Where are we now?
-----------------

The main application is a Sinatra app called frank.rb

Frank in turn will refer to handlers in the /handlers folder
This allows you to group your request handlers in smaller more modular files.
Right now there are only two groups, guest (all guest functions live here), and user, where the various user functions live.

Running Frank
-------------

Frank runs as a Rack application. To run Frank do the following

Step 0. -  Check dependencies
-----------------------------
* Ruby 1.8.7 or higher
* Various gems: rack, sinatra, haml, erb, active_record, bcrypt, logger, pony and of course rake.

Step 1. -  Get the code.
------------------------
%cd src # or wherever it is you keep your source files
% git clone git://github.com/davesag/Frank.git

Step 2. Init the data
---------------------
% cd Frank
% rake db:seed

Step 3. - Run the unit tests.
-----------------------------
% rake

Step 4 - Run the app.
---------------------
% rackup

then go to http://localhost:9292 with your favourite web browser

It will present a login screen

Enter 'root' and 'password' (without the quotes of course) and you will be logged in.  You can now log out.

if you enter anything other credentials you get bounced with a polite message.

You can register as a new user and an email will be sent with a verification link.  You can click that link (localhost only right now) and then log in.  You can then see your details and delete yourself.

If you try to register with an email address already in the system then that person will receive a warning email.

If you log out the system will remember your username unless you log out completely.

You can change your email, password or html_email preference.
If you change your email to someone else's existing email then they will be sent a warning message and your change rejected.
If you change your email successfully you will be sent an email confirmation link.  Once you log out you must click that link for your login to work.

If you log in as root you can't delete yourself as you can't delete 'admin' users. (ie users in the role 'admin')

If you register as an ordinary user and then log in you can delete yourself in a two step process.

If you have forgotten your password you can reset your password by entering your email address and clicking on the password reset link you get sent.

When the tests run the system doesn't bother sending out emails, but simply logs a debug message with who it constructed the message for, and what the subject was.

I want to be a part of it
-------------------------

So who is this project aimed at?  Me really, in that I need to build a web-app for a project I am doing and figure a great way to learn more about Sinatra and Ruby and so on is to polish up a more feature complete generic web app that does the very core of what I believe all 'user aware' web apps need to be able to do.

If you'd like to collaborate with me on this then please get in touch

I'd like to thank the people on the #sinatra IRC channel for their help.

Cheers

Dave

