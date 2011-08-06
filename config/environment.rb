# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Anathief::Application.initialize! do |config|
  config.gem "jammit"
end
