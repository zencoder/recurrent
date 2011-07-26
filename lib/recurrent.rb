require 'ice_cube'
begin
  require 'active_support/time'
rescue LoadError
  require 'active_support'
end
require 'recurrent/ice_cube_extensions'

require 'recurrent/scheduler'
require 'recurrent/task'
require 'recurrent/version'
