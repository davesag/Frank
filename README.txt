READ ME

I am using this project as a way of learning about GIT, Ruby, Rails, Sinatra, and so on.

There is really very little to see here right now but as I mess about the code base is sure to expand.

So far the code is a simple Sinatra app called app.rb

% ruby app.rb

then go to http://localhost:4567

It will present a login screen

enter root and password and you will be logged in.  you can log out.

if you enter anything else you get bounced.

uses active records

This is unit tested via

% ruby tests/app_test.rb

though the tests are incomplete

see the rake file for db:migrate and db:seed

Cheers

Dave

