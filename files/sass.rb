unless %w[development test].include? RAILS_ENV
  Sass::Plugin.options[:style] = :compressed
end
Sass::Plugin.options[:template_location] = "#{RAILS_ROOT}/app/stylesheets"
Sass::Plugin.options[:css_location] = "#{RAILS_ROOT}/public/stylesheets"