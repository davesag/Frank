#!usr/bin/ruby

require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'sinatra/r18n'
require 'logger'
require 'erb'
require 'haml'

module Sinatra
  module TemplateHelpers

    # we use haml to create HTML rendered email, in which case we need to avoid using the web-facing templates
    # if the user is logged in then use /in/layout.haml as a layout template.
    # all templates within /views/in/ need to use their local (ie /in/layout.haml) layout template.
    # if it's not a chunk template then change the template path depending on avaialable locales.
    # however templates in the 'views/chunks' folder are just chunks and are only to be injected into other haml templates, so use no layout
    def haml(template, options = {}, *)
      
      # template will either be the name of a template or the body of a template.
      # if it's the body then it will contain a "%" symbol and so we can skip any processing
      
      template_name = template.to_s
      do_not_localise = false
      if template_name.include?('%')
#        @@log.debug("haml: Aboout to render a chunk of haml content")
        # it's actually the template content we have here, not a template name
        super
      else
#        @@log.debug("haml: Aboout to render an haml template called #{template_name}")
        # it's a template name we have here.
        # note layout.haml files must never hold untranslated text
        if template_name.include?('chunks/')
          options[:layout] ||= false
          do_not_localise = true
#          @@log.debug("haml: It's a chunk so don't attempt to localise and don't use a layout.")
        elsif template_name.include?('mail/')
          options[:layout] ||= false
#          @@log.debug("haml: It's an email so don't use a layout.")
        elsif is_logged_in? || template_name.include?('in/')
          options[:layout] ||= :'in/layout'
#          @@log.debug("haml: Use the logged in layout.")
        end

        # now if template_bits[0] is a locale code then just pass through
        if do_not_localise
          # "Don't bother localising chunks.
#          @@log.debug("haml: Nothing to localise so proceed as normal.")
          super
        else
          # there is no locale code in front of the template name
          # now make an adjustment to the template path depending on locale.
          local_template_file = "views/#{r18n.locale.code.downcase}/#{template_name}.haml"
          if File.exists? local_template_file
            # Found a localised template so we'll use that one
            local_template = File.read(local_template_file)
#            @@log.debug("haml: found #{local_template_file} so will recurse and load that.")
            return haml(local_template, options)
          elsif r18n.locale.sublocales != nil && r18n.locale.sublocales.size > 0
            # Couldn't find a template for that specific locale.
#            @@log.debug("haml: could not find anything called #{local_template_file} so will dig deeper.")
            local_template_file = "views/#{r18n.locale.sublocales[0].downcase}/#{template_name}.haml"
            if File.exists? local_template_file
              # but there is a more generic language file so use that.
              # note if I really wanted to I could loop through in case sublocales[0] doesn't exist but other one does.
              # too complicated for now though and simply not needed.  TODO: polish this up later.
              local_template = File.read(local_template_file)
#              @@log.debug("haml: Found a more generic translation in #{local_template_file} so will recurse and use that.")
              return haml(local_template, options)
            else
              # No localsied version of this template exists. Okay use the template we were supplied.
#              @@log.debug("haml: No localised versions of that template exist so use #{template_name}")
              super
            end
          else
            # That locale has no sublocales so just use the template we were supplied.
#            @@log.debug("haml: That's as deep as we can look for a localised file.  Using #{template_name}")
            super
          end
        end
      end
    end

    # we use erb to create plain text rendered email and
    # change the template path depending on the active locale.
    def erb(template, options = {}, *)
      # template will either be the name of a template or the body of a template.
      # if it's the body then it will contain a "%" symbol and so we can skip any processing
      
      template_name = template.to_s
      
      if template_name.include?('%')
        # it's actually the template content we have here, not a template name
        super
      else
        # it's a template name we have here.

        # now make an adjustment to the template path depending on locale.
        local_template_file = "views/#{r18n.locale.code.downcase}/#{template_name}.erb"
        if File.exists? local_template_file
          # Found a localised template so we'll use that one
          local_template = File.read(local_template_file)
          return erb(local_template, options)
        elsif r18n.locale.sublocales != nil && r18n.locale.sublocales.size > 0
          # Couldn't find a template for that specific locale.
          local_template_file = "views/#{r18n.locale.sublocales[0].downcase}/#{template_name}.erb"
          if File.exists? local_template_file
            # but there is a more generic language file so use that.
            # note if I really wanted to I could loop through in case sublocales[0] doesn't exist but other one does.
            # too complicated for now though and simply not needed.  TODO: polish this up later.
            local_template = File.read(local_template_file)
            return erb(local_template, options)
          else
            # No localsied version of this template exists. Okay use the template we were supplied.
            super
          end
        else
          # That locale has no sublocales so just use the template we were supplied.
          super
        end
      end
    end


  end

  helpers TemplateHelpers

end
