Current Status
-------------
Hovering around version 0.9.x.  See the TODO: lists below and in the body of the sourcecode.

Background and History
----------------------
This project started life, back in the first week of September 2010, as a test project for me to learning about GIT, Ruby, Sinatra, Active Record and the like.

My original aim was to build a very simple web application that demonstrated a complete round-trip of user login, and log out.

It was fairly simple to do and an excellent learning experience as I have come from a Java world, but I found a out of gaps in other people's documentation and, in particular, no simple, canonical examples for how I would do such a simple thing.

So, using Sinatra as a simple base, and with the collaboration of a few friends and with some excellent help from people on the #rolo, #sinatra and #git IRC channels, this project started to get a little more ambitious.

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
* terms and conditions (done - insert your own text here. Terms must be accepted for registration to work)
* privacy policy (done - insert your own text here.)
* Simple and consistent navigation system using haml layouts. (done)
** include examples of injecting chunks of haml into other haml templates.
* Support for Internationalisation and Localisation using r18n. (mostly done - my French is poor. Added translations for en, en-GB, en-AU, en-US and fr and now save locale settings to the database if editing yourself, or registering.) Location codes are either like 'fr' or 'en-us' etc.
** You have two choices with localisation and I suggest you use both
*** Firstly create locale specific yml files in i18n folder for the various small bits of text in the site.
*** but for large blocks of text as haml for whole pages or html email and erb for plain-text emails, simply put the view templates into views/{location_code}/.. and they will be loaded
    automatically if they exist.
*** EG if Frank is looking for haml template hello and the location is 'en-au', it will
**** first look for 'views/en-au/hello.haml
**** If that's not there it will look for 'views/en/hello.haml'
**** and if that's no there it will load views/hello.haml as per normal for a Sinatra app.
* User roles (done)
* Simple admin functions (done.  if you are logged in as an admin you can edit other users.  You can't delete any superusers though.  Simple user and role creation, editing and deletion works.)
* >90% test coverage of all handlers, models and views (done according to rcov.  Of course there may be missing features that are not being tested for, the unknown unknowns.)
** localising of emailed erb plain text templates is not tested as we don't send email in tests. I know it works though.
* Deploy to Heroku as http://frank-demo.heroku.com (done)
* modularised handlers (done)
* form validations (done for login, registration and contact)
** ((( javascript form validation is not working yet )))

TODO: V1.0
----------
* Pretty up the use of CSS
* explore the unknown unknowns
* code review and polish
* flatten migrations for 1.0 release

Proposed features for v1.1
--------------------------
* oAuth authentication
* RESTful API allowing logged in Admins to add, edit and delete Users and Roles via AJaX components.
  * safeguards preventing deletion of superuser by anyone

Where are we now?
-----------------
The main application is a Sinatra app called frank.rb

Run with RACK_ENV=test or normally the rake task db:seed will run the various migrations in db/migrate and execute the code in db/seeds.rb to create three standard roles, 'superuser', 'admin' and 'user'.
Run with RACK_ENV=production db:seed will only create the root user.  This typically only gets run once (or after a hard db reset) on Heroku.

Superuser and Admin are 'blessed' roles in that they may not be renamed or deleted.  You can use the admin screens to create new roles and users and assign roles to users.

The views folder is broken down as follows
	chunks/ 			# a special folder for translation independent haml chunks that can be injected into other haml templates without being wrapped in a layout.haml
	en/						# 'plain' English translations
	en-au/				# Australian English translations
	fr/						# French translations (done by me using Google.  I don't speak French so please excuse me. If you do speak French and want to contribute better translations please fork and send me a pull request.)
	in/						# templates in here are restricted to people who are logged in.  They use the 'logged in' layout.haml local to the 'in' folder.
	mail/					# haml and erb templates used to construct email messages.  haml for HTML email and erb for plain text email.

Within each translation file you may place further 'in/' and 'mail/' subfolders with their own localised versions of haml and erb templates.

Running Frank
-------------
Frank runs as a Rack application. To run Frank do the following

Step 0. -  Check dependencies
-----------------------------
* Ruby 1.8.7 or higher
* Various gems: rack, sinatra, sinatra-r18n, haml, erb, activerecord (version 3.0.0 or better), bcrypt-ruby, logger, pony and of course rake.
* If you want to use rcov install that too.
# see the .gems file for the formal details we supply to Heroku.

Step 1. -  Get the code.
------------------------
%cd src # or wherever it is you keep your source files
% git clone git://github.com/davesag/Frank.git

or fork it via GitHub.

Step 2. Init the data in test and development databases.
--------------------------------------------------------
% cd Frank
% rake db:seed
% RACK_ENV=test rake db:seed

Step 3. - Run the unit tests.
-----------------------------
% RACK_ENV=test rake

Step 3.1 - If you are keen and have rcov installed run
% RACK_ENV=test rcov test/*_test.rb --exclude /gems/,/Library/,/usr/

	(if anyone can tell me why the RCov task in my rakefile doesn't work I'd be happy to hear from them.)

Step 4 - Run the app locally.
-----------------------------
% rackup

Frank will run by default against the development database.  If you wish to run the webapp against production or test databases then set RACK_ENV=test or RACK_ENV=production when you rackup.
eg
% RACK_ENV=test rackup
But ideally you won't do this.

go to http://localhost:9292 with your favourite web browser

It will present a login screen

Enter 'root' and 'password' (without the quotes of course) and you will be logged in.  You can list and edit the default test users and roles, admire the privacy policy and legals, and log out.

Enter 'nobody' and 'password' and you will be logged in.  You can admire the privacy policy etc but nobody is not an admin and can't edit anything but themselves.

if you enter any other credentials you get bounced with a polite message.

If you are logged out completely you can register as a new user and an email will be sent with a verification link.  You can click that link (localhost only right now) and then log in.  You can then see your details and delete yourself.

If you try to register with an email address already in the system then that person will receive a warning email.

If you log out the system will remember your username unless you log out completely.

You can change your email, password or html_email preference.
If you change your email to someone else's existing email then they will be sent a warning message and your change rejected.
If you change your email successfully you will be sent an email confirmation link.  Once you log out you must click that link for your login to work.

If you log in as root you can't delete yourself as you can't delete 'admin' users. (ie users in the role 'admin')

Logging in as root also shows you the various admin functions.

If you register as an ordinary user and then log in you can delete yourself in a two step process.

If you have forgotten your password you can reset your password by entering your email address and clicking on the password reset link you get sent.

When the tests run the system doesn't bother sending out emails, but simply logs a debug message with who it constructed the message for, and what the subject was.

When you are logged in the haml template system will always use the layout in views/in/ thus presenting consistent navigation options even for pages outside of userland.

Step 5 - Push to Heroku (optional)
----------------------------------
If you have a Heroku account you can push this project to Heroku
Assuming you've done that, seed the production database.  Note edit db/production_seeds.rb to change the default production data.
%> heroku rake db:seed
%> heroku open

then log in as root and change your root password.  Then you should not have to run db:seed again.  If you add migrations run
%> heroku rake db:migrate

I want to be a part of it
-------------------------
So who is this project aimed at?  Me really, in that I need to build a web-app for a project I am doing and figure a great way to learn more about Sinatra and Ruby and so on is to polish up a more feature complete generic web app that does the very core of what I believe all 'user aware' web apps need to be able to do.

If you'd like to collaborate with me on this then please get in touch

I'd like to thank the people on the #sinatra IRC channel for their help.

Cheers

Dave

