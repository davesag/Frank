#!usr/bin/ruby

require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'sinatra/r18n'
require 'sinatra/template_helpers'
require 'pony'
require 'logger'
require 'erb'
require 'haml'

module Sinatra
  module CommonHelpers

    def locale_available?(locale_code)
      r18n.available_locales.each do |locl|
        return true if locale_code == locl.code
      end
      return false
    end

    def is_blessed_role?(role)
      return ['admin', 'superuser'].include?(role.name)
    end

  end

  helpers CommonHelpers

end
