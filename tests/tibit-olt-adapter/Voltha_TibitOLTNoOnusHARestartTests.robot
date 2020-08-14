

# TODO: During OLT container restart, trigger a hard-reboot of the OLT so that
#       we give proper info to ONOS and flows/onu activations occur again.

# TODO: Besides OLT container restarts, also add some rw-core restarts here and
#       test how our adapter recovers.  Include restarts of both olt and rwcore
#       at the same time (and staggered/overlapping times).  Also include olt
#       adapter coming up and rw-core not arriving for many (30+ seconds)