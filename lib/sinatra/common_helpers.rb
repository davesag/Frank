#!usr/bin/ruby

require 'bundler/setup'
require 'sinatra/base'
require 'sinatra/r18n'

module Sinatra
  module CommonHelpers

    def locale_available?(locale_code)
      r18n.available_locales.each do |locl|
        return true if locale_code == locl.code
      end
      return false
    end

    def language_options
      lo = []
      r18n.available_locales.each do |locl|
        lo << { :value => locl.code, :text => locl.title }
      end
      return lo
    end

    def role_options
      ro = [ { :value => '', :text => t.labels.no_role }]
      Role.all(:order => 'name').each do |r|
        ro << { :value => r.name, :text => r.name }
      end
      return ro
    end

    def is_blessed_role?(role)
      return ['admin', 'superuser'].include?(role.name)
    end

  end

  helpers CommonHelpers

end
