unless Capistrano::Configuration.respond_to?(:instance)
  abort "capistrano/ext/multistage requires Capistrano 2"
end

require 'drupistrano/recipe'
require 'drupistrano/hooks'
