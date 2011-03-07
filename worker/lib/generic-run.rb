require 'worker/run'

### match stdout or stderr to get progress
### use tmpfile to pass files on cmdline
### grab created tmpfile and send back on completion

# Worker for controlling a child process that does the real work. Parameters to
# the generic worker determine how to pass command line args to the child and
# how to interpret the stdout/stderr of the child, for example to scan for
# progress information.
class GenericRun < Run
end
