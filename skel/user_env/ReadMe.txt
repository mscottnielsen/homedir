#############################################################################
#
# This directory is for user-specific env files; things that would
# normally go in a specific user's ~/.bashrc would instead go into
#    user-{logname}.env
#
# If multiple users all have the same common env settings, based on
# their organization (dev, sales, support, etc), then those users
# can set the following in their env file:
#
#  $ grep USER_ORG user-johnny.env
#  USER_ORG=org1,dev,support
#
# this causes the following env files to be sourced (after user-*.env)
#     . org-org1.env
#     . org-dev.env
#     . org-support.env
#
#############################################################################

