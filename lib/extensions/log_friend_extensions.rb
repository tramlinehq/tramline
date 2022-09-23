# LogFriend makes it easy to do quick, easy logging in dev/test with output that includes
# the name of object being logged.
# For example:
#   arg = "42"
#   @ivar = "Hello"
#   dbg arg
#   dbg @ivar
# Outputs:
#   ["arg", "42"]
#   ["@ivar", "Hello"]
#
module LogFriendExtensions
  if Rails.env.development? || Rails.env.test?
    # This Regexp is used to find the name of the thing being logged, so that we can then
    # print out the name along with the value of the object logged.
    CALL_SITE_REGEXP = /^\s*d\s*\(?(.*)\)?\s*$/

    def d(msg)
      location = caller_locations(1..1).first
      path = location.absolute_path
      line = Pathname(path).readlines[location.lineno - 1]

      arg_name =
        if (match = line.match(CALL_SITE_REGEXP))
          match[1]
        else
          "error finding arg name"
        end
      pp [arg_name, msg]
    end
  else
    # Shim a noop method for non dev / test environments
    def d(_msg)
    end
  end
end
