# Depends on AURORA_CLASS_PREFIX env var, which may be different in dev and
# production. The value of the var should be the dir with subdirs:
#
#   build icons libGIS libGUI ...
#
# Within these subdirs are .class and .jar files, as well as icons.
#
# This file defines two constants used in the Aurora module,
# DEPLOYMENT_FILES and CLASSPATH.

module Aurora
  CLASS_PREFIX = ENV["AURORA_CLASS_PREFIX"]
  
  # List of files under CLASS_PREFIX that need to be rsynced for deployment.
  # The target dir should be the CLASS_PREFIX on the deployment target host.
  DEPLOYMENT_FILES = %w{ build/aurora.jar icons libGIS libGUI libPDF libPPT }

  classpath_items = ["build/aurora.jar"]###, "lib*/*.jar"]

  # Classpath for java and jruby to run aurora.
  CLASSPATH = classpath_items.map {|rel|
    Dir[File.join(CLASS_PREFIX, rel)]
  }.join(":")
end
