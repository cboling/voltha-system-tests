

#  TODO: During a hard reboot test, make the OLT not available for long enough that
#        the inband network interface recovery logic kicks in so that we begin to
#        hunt for the proper path to the OLT.

#  TODO: Include a test that during an OLT hard reboot, the rw-core restarts or is
#        not available for a short period of time (30+ seconds) to see how we
#        recover.  May wish it to be greater than OLT inband-management reset/restart
#        so that we can test that as well.