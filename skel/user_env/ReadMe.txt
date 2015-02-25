#############################################################################
# This directory (~/user_env) is an example of user-specific configuration;
# things normally in ~logname/.bashrc instead go in user_env/user-{logname}.env
#
# If multiple users share common env settings (e.g: dev, sales, support, etc),
# then a common "org" env file can be used. For example, for users "sam" & "sue",
#
#  $ grep USER_ORG user-sam.env user-sue.env
#  user-sue.env: USER_ORG=dba,dev,foo
#  user-sam.env: USER_ORG=support,foo
#
# This causes the following env files to be sourced (in order):
#   user-sue.env => org-dba.env => org-dev.env => org-foo.env
#   user-sam.env => org-support.env => org-foo.env
#
# See also ~/host_env for per-server configuration examples.
#############################################################################

