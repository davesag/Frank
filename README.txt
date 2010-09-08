READ ME

You must remember this
----------------------

This project started life as a test project for learning about GIT, Ruby, Sinatra, and Active Record.

My original aim was to build a very simple web application that demonstrated a complete round-trip of user login, and log out.

It was fairly simple to do and an excellent learning experience as I have come from a Java world, but I found a out of gaps in other people's documentation and, in particular, no simple, canonical examples for how I would do such a simple thing.  I felt I had to work out far too much of this as I went.

Proposed Feature Set for v1
--------------------
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

Proposed features for v1.1
--------------------------
* oAuth authentication

Where are we now?
-----------------

So far the code is a simple Sinatra app called app.rb

To run it do the following

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
% ruby test/app_test.rb

Step 4 - Run the app.
---------------------
% ruby app.rb

then go to http://localhost:4567 with your favourite web browser

It will present a login screen

Enter 'root' and 'password' (without the quotes of course) and you will be logged in.  You can now log out.

if you enter anything other credentials you get bounced with a polite message.

I want to be a part of it
-------------------------

So who is this project aimed at?  Me really, in that I need to build a web-app for a project I am doing and figure a great way to learn more about Sinatra and Ruby and so on is to polish up a more feature complete generic web app that does the very core of what I believe all 'user aware' web apps need to be able to do.

If you'd like to collaborate with me on this then please get in touch

Cheers

Dave

