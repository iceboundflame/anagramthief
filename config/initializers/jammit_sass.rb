# http://mpov.timmorgan.org/auto-compile-sass-with-jammit
# hack to auto compile sass when Jammit runs in Dev/Test mode

require 'haml/util'
require 'sass/engine'

module Jammit
  module Helper
    SASS_TIMESTAMPS = {}

    def include_stylesheets_with_sass(*packages)
      unless Rails.env.production?
        paths = Dir[Rails.root.join('public/stylesheets/*.scss')].select do |path|
          next if path =~ %r{/_[^/]+$} # skip partials
          t = File.mtime(path)
          if SASS_TIMESTAMPS[path] == t
            false
          else
            SASS_TIMESTAMPS[path] = t
          end
        end
        paths.each do |path|
          Rails.logger.info("Compiling #{path} with SASS.")
          engine = Sass::Engine.new(
            File.read(path),
            :load_paths => [Rails.root.join('public/stylesheets')],
            :cache      => false,
            :syntax     => :scss
          )
          File.open(path.sub(/scss$/, 'css'), 'w') { |f| f.write(engine.render) }
        end
      end
      include_stylesheets_without_sass(*packages)
    end

    alias_method_chain :include_stylesheets, :sass
  end
end
