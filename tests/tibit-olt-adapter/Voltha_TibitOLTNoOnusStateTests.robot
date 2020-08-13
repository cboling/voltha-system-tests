*** Settings ***
Documentation     Tests various states and conditions a Tibit OLT can be in without ONUs
...               being present.
...
...               This test suite does not perform HA testing, those are handled
...               in other suites specific to the HA failure reason.
Suite Setup       Setup Suite
Suite Teardown    Teardown Suite
Test Setup        Setup
Test Teardown     Teardown
Library           Collections
Library           String
Library           OperatingSystem
Library           XML
Library           RequestsLibrary
Library           ../../libraries/DependencyLibrary.py
Resource          ../../libraries/onos.robot                # TODO: ONOS not yet supported
Resource          ../../libraries/voltctl.robot
Resource          ../../libraries/voltha.robot
Resource          ../../libraries/utils.robot
Resource          ../../libraries/k8s.robot
Resource          ../../variables/variables.robot

# The following are similar to the resources above, but they have
# tibit versions of the files

Resource          ./libraries/utils.robot
Resource          ./libraries/voltctl.robot

*** Variables ***
${POD_NAME}                 cb-office-net
${KUBERNETES_CONF}          ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
${KUBERNETES_CONFIGS_DIR}   ../tibit-olt-adapter/data
${KUBERNETES_YAML}          ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.yml
${HELM_CHARTS_DIR}          ~/k8s/helm
${VOLTHA_POD_NUM}           8
${NAMESPACE}                voltha

# For below variable value, using deployment name as using grep for
# parsing radius pod name, we can also use full radius pod name
${RESTART_POD_NAME}  radius
${timeout}           30s                #  was -> 60s
${of_id}             0
${logical_id}        0
${has_dataplane}     False              #  was -> True
${external_libs}     True
${teardown_device}   True
${scripts}           ../../scripts

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

# state test variablse, can be passed via the command line too
${porttest}             True
${disable_discovery}    True
${debugmode}            False
${logging}              False
${pausebeforecleanup}   False

# Timeouts so they are consistent. These are times without ONUs or flows present
${enable_timeout}       15s     # OLT disable time to competion
${disable_timeout}      15s     # OLT disable time to competion
${reboot_window}         8s     # Time between reboot request and OLT finishing reboot
${reboot_pause}         15s     # Wait before we start checking
${reboot_timeout}       30s     # Reboot completed and back fully into enabled/disabled state
${port_timeout}         15s     # Enable/disable port time to completion

*** Test Cases ***

OLT Adapter Preprovisioning
    [Documentation]    Validates the Tibit OLT Device adapter can be pre-provisioned.  When
    ...                in the PreProvisoned state, the OLT device handler has not been instantiated
    ...                by the OLT Device Adapter.  Verify this by no ports being present
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTPreprovisionTest
    ...    AND    Delete All Devices and Verify
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Preprovision step
    Preprovision Tibit

    # TODO: Get OLT NNI Ports.  Should be None at this point
    # TODO: Get OLT PON Ports.  Should be None at this point

    # Delete devices as part of test here. Normal teardown does a disable first and
    # and the core does not allow a 'preprovisioned' device to be disabled
    [Teardown]    Run Keywords    Delete Devices In Voltha    Root=true
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTPreprovisionTest

OLT Adapter Can Be Enabled and Deleted
    [Documentation]    Validates the Tibit OLT Device adapter can be enabled
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTNoOnuEnableTest
    ...    AND    Delete All Devices and Verify
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Create and enable it.  Should provide us with a logical device ID once we
    # up and running.
    # TODO: Change the 'Setup Tibit' to look for the AdminState going to 'Enabled'
    #       when first enabled and the Operating State to at least be briefly in
    #       the 'Activating' state'.
    Setup Tibit    ${disable_discovery}

    # TODO: Get OLT NNI Ports.  Should be one or more at this point
    # TODO: Get OLT PON Ports.  Should be one or more at this point

    # TODO: Run through a few of the kv-store items (ResourceMgr, Logging, ...)
    #       and make sure there is something in the KV-store.  REST call to check
    #       various subsystem states are fully running would be good to perform.
    #
    # TODO: Move a subset of the REST checks into our own 'Create New Device' *** keywords ***
    #       so that all tests that need to run on a fully enabled and running OLT can do so
    #
    # Delete it
    Delete Device    ${olt_device_id}

    # TODO: Verify kv-store is scrubbed of OLT handler specific items

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTNoOnuEnableTest

OLT Adapter Can Be Disabled and Deleted
    [Documentation]    Validates the Tibit OLT Device adapter can be disabled after
    ...                previously being enabled and then deleted
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTNoOnuDisableTest
    ...    AND    Clear All Devices Then Create New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # TODO: Run through a few of the kv-store items (ResourceMgr, Logging, ...)
    #       and make sure there is something in the KV-store.  REST call to check
    #       various subsystem states are fully running would be good to perform.
    #
    # TODO: Move a subset of the REST checks into our own 'Create New Device' *** keywords ***
    #       so that all tests that need to run on a fully enabled and running OLT can do so
    #
    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Disable (note device is still reachable in 'disabled' state
    Disable Device   ${olt_device_id}
    Wait Until Keyword Succeeds   ${disable_timeout}   5s  Validate OLT Device  DISABLED  UNKNOWN  REACHABLE
    ...    ${olt_device_id}

    # TODO: Validate device port states.   OperStatus = UNKNOWN (close enough to INACTIVE)
    # TODO: Validate PON laser is still ON after an OLT disable
    # TODO: Validate that the OLT heartbeat is still operational and running

    # Delete it while disabled
    Delete Device    ${olt_device_id}

    # TODO: Verify kv-store is scrubbed of OLT handler specific items

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTNoOnuDisableTest

OLT Adapter Cleans up kv-store on Delete
    [Documentation]    Validates after delete of and OLT, kv-store is scrubbed
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTNoOnuDeleteTest
    ...    AND    Clear All Devices Then Create New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Let it run for a little bit so that most all processes have done
    # something by now
    Sleep     40s

    # Delete it
    Delete Device    ${olt_device_id}

    # TODO: Verify kv-store is scrubbed of OLT handler specific items

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTNoOnuDeleteTest

OLT Adapter Soft Reboot while Enabled
    [Documentation]    An OLT can be rebooted while it is enabled.
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTNoOnuRebootEnabledTest
    ...    AND    Clear All Devices Then Create New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # TODO: Move a subset of the REST checks into our own 'Create New Device' *** keywords ***
    #       so that all tests that need to run on a fully enabled and running OLT can do so
    Sleep   30s       # For now, just do a time delay

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Reboot the OLT using "voltctl device reboot" command
    Reboot Device    ${olt_device_id}
    Sleep    1s
    Wait Until Keyword Succeeds   ${reboot_window}   2s    Validate OLT Device   ENABLED  UNKNOWN  UNREACHABLE
    ...    ${olt_device_id}

    # TODO: Validate device port states changed as well 'during' reboot.
    #  OperStatus = UNKNOWN (close enough to INACTIVE)


    #  TODO: On OLT reset, SQA flags are reset right after the command is sent, since
    #        we are in the No-ONU state, disable discovery so we do not search for ONUs
    #        once we come back up and enable.

    # Tibit OLT reboots within 8-10 seconds:
    #  TODO: the NNI port will move to OperState Unknown
    #  TODO: PON port is left alone, have it go to OperState UNKNOWN as well
    #  TODO: the OLT OperState goes to UNKNOWN, and connect status to Unreachable
    Sleep   ${reboot_pause}      # For now, pause long enough for reboot

    # Will need to finish re-enable
    Wait Until Keyword Succeeds  ${reboot_timeout}   5s    Validate OLT Device   ENABLED  ACTIVE  REACHABLE
    ...    ${olt_device_id}

    # TODO: Validate device port states changed back to their ACTIVE states

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTNoOnuRebootEnabledTest

OLT Adapter Soft Reboot while Disabled
    [Documentation]    An OLT can be rebooted while it is enabled
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTNoOnuRebootDisabledTest
    ...    AND    Clear All Devices Then Create New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # TODO: Move a subset of the REST checks into our own 'Create New Device' *** keywords ***
    #       so that all tests that need to run on a fully enabled and running OLT can do so
    Sleep   30s       # For now, just do a time delay

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Disable
    Disable Device   ${olt_device_id}
    Wait Until Keyword Succeeds   ${disable_timeout}  5s   Validate OLT Device   DISABLED  UNKNOWN  REACHABLE
    ...    ${olt_device_id}

    # Reboot the OLT using "voltctl device reboot" command
    Reboot Device    ${olt_device_id}
    Sleep    1s
    Wait Until Keyword Succeeds   ${reboot_window}   2s    Validate OLT Device   DISABLED  UNKNOWN  UNREACHABLE
    ...    ${olt_device_id}

    # TODO: Validate device port states remained in their inactive (UNKNOWN) state

    #  TODO: On OLT reset, SQA flags are reset right after the command is sent, since
    #        we are in the No-ONU state, disable discovery so we do not search for ONUs
    #        once we come back up and enable.

    # Tibit OLT reboots within 8-10 seconds:
    #  TODO: the OLT OperState goes to UNKNOWN, and connect status to Unreachable
    #        which may be the state before.*** Test Cases ***
    #  TODO: Some REST accessible stats of commands (reboots, enables, disables, ...) would
    #        be useful.
    Sleep  ${reboot_pause}      # For now, pause long enough for reboot

    # Will need to finish re-enable
    Wait Until Keyword Succeeds    ${reboot_timeout}   5s    Validate OLT Device    DISABLED  UNKNOWN  REACHABLE
    ...    ${olt_device_id}
    # TODO: Validate device port states remained in their inactive (UNKNOWN) state

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTNoOnuRebootDisabledTest

OLT Adapter Disable During Soft Reboot
    [Documentation]    Reboot while enabled, but disable before reboot completes
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTNoOnuDisableDuringRebootTest
    ...    AND    Clear All Devices Then Create New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # TODO: Move a subset of the REST checks into our own 'Create New Device' *** keywords ***
    #       so that all tests that need to run on a fully enabled and running OLT can do so
    Sleep  30s       # For now, just do a time delay

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Reboot the OLT using "voltctl device reboot" command
    Reboot Device    ${olt_device_id}
    Sleep    1s
    Wait Until Keyword Succeeds   ${reboot_window}   2s   Validate OLT Device   ENABLED  UNKNOWN  UNREACHABLE
    ...    ${olt_device_id}

    # Disable while reboot is in progress
    Disable Device   ${olt_device_id}

    #  TODO: On OLT reset, SQA flags are reset right after the command is sent, since
    #        we are in the No-ONU state, disable discovery so we do not search for ONUs
    #        once we come back up and enable.
    # For now, pause long enough for reboot to complete
    Sleep  ${reboot_pause}

    # Did it come back up as Disabled?
    Wait Until Keyword Succeeds   ${reboot_timeout}   5s   Validate OLT Device   DISABLED  UNKNOWN  REACHABLE
    ...    ${olt_device_id}
    # TODO: Validate device port states remained in their inactive (UNKNOWN) state

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTNoOnuDisableDuringRebootTest

OLT Adapter Enable During Soft Reboot
    [Documentation]    Reboot while disabled, but enable before reboot completes
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTNoOnuEnableDuringRebootTest
    ...    AND    Clear All Devices Then Create New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # TODO: Move a subset of the REST checks into our own 'Create New Device' *** keywords ***
    #       so that all tests that need to run on a fully enabled and running OLT can do so
    Sleep   30s       # For now, just do a time delay

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Disable
    Disable Device   ${olt_device_id}
    Wait Until Keyword Succeeds   ${disable_timeout}  5s   Validate OLT Device   DISABLED  UNKNOWN  REACHABLE
    ...    ${olt_device_id}

    # Reboot the OLT using "voltctl device reboot" command
    Reboot Device    ${olt_device_id}
    Sleep    1s
    Wait Until Keyword Succeeds   ${reboot_window}   2s   Validate OLT Device   DISABLED  UNKNOWN  UNREACHABLE
    ...    ${olt_device_id}

    # Enable while reboot is in progress
    Enable Device   ${olt_device_id}

    #  TODO: On OLT reset, SQA flags are reset right after the command is sent, since
    #        we are in the No-ONU state, disable discovery so we do not search for ONUs
    #        once we come back up and enable.
    # For now, pause long enough for reboot to complete
    Sleep  ${reboot_pause}

    # Did the OLT (and ports) come back up as enabled?
    Wait Until Keyword Succeeds   ${reboot_timeout}  5s    Validate OLT Device  ENABLED  ACTIVE  REACHABLE
    ...    ${olt_device_id}
    # TODO: Validate device port states recovered to their ACTIVE states here

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTNoOnuEnableDuringRebootTest

OLT Adapter Delete During Soft Reboot while Enabled
    [Documentation]    Reboot while enabled, but delete before reboot completes
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTNoOnuDeleteDuringEnabledReboot
    ...    AND    Clear All Devices Then Create New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # TODO: Move a subset of the REST checks into our own 'Create New Device' *** keywords ***
    #       so that all tests that need to run on a fully enabled and running OLT can do so
    Sleep   30s       # For now, just do a time delay

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Reboot the OLT using "voltctl device reboot" command
    Reboot Device    ${olt_device_id}
    Sleep    1s
    Wait Until Keyword Succeeds   ${reboot_window}   2s   Validate OLT Device   ENABLED  UNKNOWN  UNREACHABLE
    ...    ${olt_device_id}

    # Delete it while it is rebooting
    Delete Device    ${olt_device_id}

    # TODO: Verify kv-store is scrubbed of OLT handler specific items

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTNoOnuDeleteDuringEnabledReboot

OLT Adapter Delete During Soft Reboot while Disabled
    [Documentation]    Reboot while disabled, but delete before reboot completes
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTNoOnuDeleteDuringDisabledReboot
    ...    AND    Clear All Devices Then Create New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # TODO: Move a subset of the REST checks into our own 'Create New Device' *** keywords ***
    #       so that all tests that need to run on a fully enabled and running OLT can do so
    Sleep   30s       # For now, just do a time delay

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Disable
    Disable Device   ${olt_device_id}
    Wait Until Keyword Succeeds  ${disable_timeout}  5s   Validate OLT Device   DISABLED  UNKNOWN  REACHABLE
    ...    ${olt_device_id}

    # Reboot the OLT using "voltctl device reboot" command
    Reboot Device    ${olt_device_id}
    Sleep    1s
    Wait Until Keyword Succeeds   ${reboot_window}   2s   Validate OLT Device   DISABLED  UNKNOWN  UNREACHABLE
    ...    ${olt_device_id}

    # Delete it while it is rebooting
    Delete Device    ${olt_device_id}

    # TODO: Verify kv-store is scrubbed of OLT handler specific items

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTNoOnuDeleteDuringDisabledReboot

OLT Adapter PON Port Disable and Enable
    [Documentation]    Verify that the PON Port(s) can be enabled and disabled. THe
    ...                PON optics are independent of the OLT state.
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTNoOnuPonPortEnableDisable
    ...    AND    Clear All Devices Then Create New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # TODO: Move a subset of the REST checks into our own 'Create New Device' *** keywords ***
    #       so that all tests that need to run on a fully enabled and running OLT can do so
    Sleep   30s       # For now, just do a time delay

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    ${port_numbers}=  Get OLT Ports  ${olt_device_id}   PON_OLT
    FOR    ${port_number}    IN    @{port_numbers}
        # Should be enabled by default
        Wait Until Keyword Succeeds  10s  2s   Validate Port Admin Status
        ...    ${olt_device_id}   ${port_number}    ENABLED

        # TODO: For tibit, validate PON laser is on by default when OLT is first enabled

        # Disable the port
        Disable Port   ${olt_device_id}   ${port_number}
        Wait Until Keyword Succeeds  ${port_timeout}  5s   Validate Port Admin Status
        ...    ${olt_device_id}   ${port_number}    DISABLED

        # TODO: For tibit, validate PON laser is turned off

        # Enable the port
        Enable Port   ${olt_device_id}   ${port_number}
        Wait Until Keyword Succeeds  ${port_timeout}   5s   Validate Port Admin Status
        ...    ${olt_device_id}   ${port_number}    ENABLED

        # TODO: For tibit, validate PON laser is turned back on
    END

    # Do the same with the OLT device disabled
    Disable Device   ${olt_device_id}
    Wait Until Keyword Succeeds   ${disable_timeout}  5s    Validate OLT Device  DISABLED  UNKNOWN  REACHABLE
    ...    ${olt_device_id}

    ${port_numbers}=  Get OLT Ports  ${olt_device_id}   PON_OLT
    FOR    ${port_number}    IN    @{port_numbers}
        # Should be not be disabled initially just because the OLT was disabled
        Wait Until Keyword Succeeds   10s  2s   Validate Port Admin Status
        ...    ${olt_device_id}   ${port_number}    ENABLED
        # TODO: For tibit, validate PON laser is still on

        # Disable the port, which should turn off the optics
        Disable Port   ${olt_device_id}   ${port_number}
        Wait Until Keyword Succeeds   ${port_timeout}   5s   Validate Port Admin Status
        ...    ${olt_device_id}   ${port_number}    DISABLED

        # TODO: For tibit, validate PON laser is turned off

        # Enable the port (while OLT is still disabled) and optics should be back on
        Enable Port   ${olt_device_id}   ${port_number}
        Wait Until Keyword Succeeds   ${port_timeout}   5s   Validate Port Admin Status
        ...    ${olt_device_id}   ${port_number}    ENABLED

        # TODO: For tibit, validate PON laser is turned back on
    END

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTNoOnuPonPortEnableDisable

OLT Adapter PON Port Disable and Reboot
    [Documentation]    Verify that the PON Port(s) stays disabled across a reboot
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTNoOnuPonPortAndReboot
    ...    AND    Clear All Devices Then Create New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # TODO: Move a subset of the REST checks into our own 'Create New Device' *** keywords ***
    #       so that all tests that need to run on a fully enabled and running OLT can do so
    Sleep   30s       # For now, just do a time delay

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Disable all of the PON ports.  OLT state is enabled
    ${port_numbers}=  Get OLT Ports  ${olt_device_id}   PON_OLT
    FOR    ${port_number}    IN    @{port_numbers}
        # Should be enabled by default
        Wait Until Keyword Succeeds   10s  2s   Validate Port Admin Status
        ...    ${olt_device_id}   ${port_number}    ENABLED

        # TODO: For tibit, validate PON laser is on by default when OLT is first enabled

        # Disable the port
        Disable Port   ${olt_device_id}   ${port_number}
        Wait Until Keyword Succeeds   ${port_timeout}   5s   Validate Port Admin Status
        ...    ${olt_device_id}   ${port_number}    DISABLED

        # TODO: For tibit, validate PON laser is turned off
    END
    # Reboot the OLT using "voltctl device reboot" command
    Reboot Device    ${olt_device_id}
    Sleep  ${reboot_pause}     # For now, pause long enough for reboot

    # Will need to finish re-enable
    Wait Until Keyword Succeeds  ${reboot_timeout}   5s    Validate OLT Device   ENABLED  ACTIVE  REACHABLE
    ...    ${olt_device_id}

    FOR    ${port_number}    IN    @{port_numbers}
        # Make sure the PON port is disabled still
        Wait Until Keyword Succeeds    ${port_timeout}   5s   Validate Port Admin Status
        ...    ${olt_device_id}   ${port_number}    DISABLED

        # TODO: For tibit, validate PON laser is turned off
    END

    # Do the same with the OLT device disabled
    Disable Device   ${olt_device_id}
    Wait Until Keyword Succeeds  ${disable_timeout}  5s   Validate OLT Device   DISABLED  UNKNOWN  REACHABLE
    ...    ${olt_device_id}

    FOR    ${port_number}    IN    @{port_numbers}
        # Make sure the PON port is disabled still
        Wait Until Keyword Succeeds   ${port_timeout}   5s   Validate Port Admin Status
        ...    ${olt_device_id}   ${port_number}    DISABLED

        # TODO: For tibit, validate PON laser is turned off
    END
    # Reboot the OLT using "voltctl device reboot" command
    Reboot Device    ${olt_device_id}
    Sleep  ${reboot_pause}      # For now, pause long enough for reboot

    # Will need to finish re-enable
    Wait Until Keyword Succeeds   ${reboot_timeout}   5s    Validate OLT Device   DISABLED  UNKNOWN  REACHABLE
    ...    ${olt_device_id}

    FOR    ${port_number}    IN    @{port_numbers}
        # Make sure the PON port is disabled still
        Wait Until Keyword Succeeds   ${port_timeout}  5s   Validate Port Admin Status
        ...    ${olt_device_id}   ${port_number}    DISABLED

        # TODO: For tibit, validate PON laser is turned off
    END
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTNoOnuPonPortAndReboot

# TODO: A list of future tests to try (with no onus)
#  - PON Port Disable  - Repeat 6 reboot tests above with PON port disabled
#
#  - Disable-enable, enable-disable, disable-reboot, reboot-disable, and so on
#    with very little or not time between them, say 0 to 5 seconds in .25 second
#    increments.  Goal is to make sure functions getting canceled/started/restarted
#    occur properly.  For instance, during enable, if off waiting on an async call
#    to finish we get a disable request, that request should be canceled and we stop
#    doing any more enabling, but instead, let disable proceed as it should.   This
#    should first be with no ONUs so we can really get that logic solid.  Once ONUs
#    and flows are added and become more numerous, may want to do this with those
#    setups and with a longer max time than 5 seconds...
#
#
#
#################
# TODO: In a separate failures suite for NO ONUs, *** test cases ***
#  - Enable but OLT never discovered (no network connectivity)
#  - Enable but OLT MAC address is invalid format
#  - Enable but OLT is in EPON mode
#  - Enable but OLT is in auto boot mode
#  - Enabled Failed Tests.  On an enable (both initial and ones later on), make the
#    OLT handler oper-status go to failed (for various reasons).  Then correct that
#    issue and do a disable / enable and see if it goes back to OperStatus = Active

#################
# TODO: In a separate suite, *** test cases ***
#  - PM Stats during various states
#  - Audit recovery test cases

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
#    Common Test Suite Setup
    Set Global Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Global Variable    ${VOLTCTL_CONFIG}    export VOLTCONFIG=%{VOLTCONFIG}
    ${k8s_node_ip}=    Evaluate    ${nodes}[0].get("ip")
    ${ONOS_REST_IP}=    Get Environment Variable    ONOS_REST_IP    ${k8s_node_ip}
    ${ONOS_SSH_IP}=     Get Environment Variable    ONOS_SSH_IP     ${k8s_node_ip}
    Set Global Variable    ${ONOS_REST_IP}
    Set Global Variable    ${ONOS_SSH_IP}
    ${k8s_node_user}=    Evaluate    ${nodes}[0].get("user")
    ${k8s_node_pass}=    Evaluate    ${nodes}[0].get("pass")
#    Check CLI Tools Configured
#    ${onos_auth}=    Create List    karaf    karaf
#    ${HEADERS}    Create Dictionary    Content-Type=application/json
#    Create Session    ONOS    http://${ONOS_REST_IP}:${ONOS_REST_PORT}    auth=${ONOS_AUTH}
    ${olt_mac}=    Evaluate    ${olts}[0].get("mac")
    ${olt_serial_number}=    Evaluate    ${olts}[0].get("serial")
    ${num_onus}=    Get Length    ${hosts.src}
    ${num_onus}=    Convert to String    ${num_onus}
#    #send sadis file to onos
#    ${sadis_file}=    Get Variable Value    ${sadis.file}
#    Log To Console    \nSadis File:${sadis_file}
#    Run Keyword Unless    '${sadis_file}' == '${None}'    Send File To Onos    ${sadis_file}    apps/
    Set Suite Variable    ${num_onus}
    Set Suite Variable    ${olt_serial_number}
    Set Suite Variable    ${olt_mac}
    @{container_list}=    Create List    adapter-tibit-olt  adapter-open-olt    adapter-open-onu    voltha-api-server
    ...    voltha-ro-core    voltha-rw-core-11    voltha-rw-core-12    voltha-ofagent
    Set Suite Variable    ${container_list}
    ${datetime}=    Get Current Date
    Set Suite Variable    ${datetime}

    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}

    # Start the test suite with a clean slate
    Delete All Devices and Verify
    # TODO: verify a clean kv-store to start with


Clear All Devices Then Preprovision New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS and preprovision a
    ...                Tibit OLT, but do not enable
    # Remove all devices from voltha and onos
    Delete All Devices and Verify

    # TODO: Verify that kv-store is clean

    # Preprovision step
    Preprovision Tibit    ${disable_discovery}

Clear All Devices Then Create New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS and preprovision and
    ...                enable a device
    # Remove all devices from voltha and ONOS an preprovision the OLT
    Delete All Devices and Verify

    # Execute normal test Setup Keyword
    Setup Tibit    ${disable_discovery}

#Setup Test
#    [Documentation]    Pre-test Setup
#    # test for empty device list
#    Test Empty Device List
#
#    #create/preprovision device
#    ${olt_device_id}=    Create Device Tibit   ${olt_mac}
#    Set Suite Variable    ${olt_device_id}
#
#    #validate olt states
#    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN
#    ...    ${olt_device_id}
#    Sleep    1s
