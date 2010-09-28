#!usr/bin/ruby

require 'frank'
require 'test/unit'
require 'rack/test'
require 'rack/builder'
require 'models/user'
require 'test/handler_test_base'

class ModelTest < HandlerTestBase

  def test_adding_nonexistant_role_to_user_doesnt_break_anything
    george = setup_dummy_user("George")
    george.add_role('some-nonsense')
    george.add_role('admin')
    
    assert george.has_role?('admin')
    assert !george.has_role?('some-nonsense')
    
    george.destroy
  end

end
