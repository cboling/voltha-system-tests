#
#  State change tests with ONUs present (but no flows)
#
#  Do many of the 'no onus' style tests after discovering (or in the process of
#  discovering) and activating at least one ONU.*** Settings ***
#
#  For DT use case, an OLT or PON port down will result in a call to 'delete' the
#  ONU.  So add a test for that if we cannot use any that are already written
#