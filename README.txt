You must remember this
----------------------

This project started life as a test project for learning about GIT, Ruby, Sinatra, and Active Record.

My original aim was to build a very simple web application that demonstrated a complete round-trip of user login, and log out.

It was fairly simple to do and an excellent learning experience as I have come from a Java world, but I found a out of gaps in other people's documentation and, in particular, no simple, canonical examples for how I would do such a simple thing.  I felt I had to work out far too much of this as I went.

Proposed Feature Set for v1
---------------------------
* Log in with username or email and password --> Logged in User screen
* Log out (but remember who I am) --> Login screen
* Log out completely --> Login screen
* New User Registration --> sends verification email with link
						--> 'Please check your email' screen.
* New User Verification --> User is verified message on Logged in User screen
* Forgot password --> Enter Email
					--> either reset password and send password reset link, or
					--> email not known
* terms and conditions
* privacy policy

* Passwords must be stored securely

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
* Various gems: rack, sinatra, haml, active_record, bcrypt, logger, and of course rake.

Step 1. -  Get the code.
------------------------
%cd src # or wherever it is you keep your source files
% git clone git://github.com/davesag/Frank.git

Step 2. Init the data
---------------------
% cd Frank
% rake db:migrate
% rake db:seed

Step 3. - Run the unit tests.
-----------------------------
% rake test

Step 4 - Run the app.
---------------------
% rackup

then go to http://localhost:9292 with your favourite web browser

It will present a login screen

Enter 'root' and 'password' (without the quotes of course) and you will be logged in.  You can now log out.

if you enter anything other credentials you get bounced with a polite message.

You can register as a new user and then log in.  You can then see your details and delete yourself.

When you register it will claim to be emailing you but I've not done that bit yet.

I want to be a part of it
-------------------------

So who is this project aimed at?  Me really, in that I need to build a web-app for a project I am doing and figure a great way to learn more about Sinatra and Ruby and so on is to polish up a more feature complete generic web app that does the very core of what I believe all 'user aware' web apps need to be able to do.

If you'd like to collaborate with me on this then please get in touch

I'd like to thank the people on the #sinatra IRC channel for their help.

Cheers

Dave

