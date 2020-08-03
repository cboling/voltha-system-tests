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

*** Test Cases ***

OLT Adapter Preprovisioning
    [Documentation]    Validates the Tibit OLT Device adapter can be pre-provisioned
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTPreprovisionTest
    ...    AND    Delete All Devices and Verify
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Preprovision step
    Preprovision Tibit

    # Delete devices as part of test here. Normal teardown does a disable first and
    # and the core does not allow a 'preprovisioned' device to be disabled
    [Teardown]    Run Keywords    Delete Devices In Voltha    Root=true
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTPreprovisionTest

OLT Adapter Can Be Enabled and Deleted
    [Documentation]    Validates the Tibit OLT Device adapter can be enabled
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTSingleEnableTest
    ...    AND    Delete All Devices and Verify
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Create and enable it.  Should provide us with a logical device ID once we
    # up and running.
    Setup Tibit    ${disable_discovery}

    # TODO: Run through a few of the kv-store items (ResourceMgr, Logging, ...)
    #       and make sure there is something in the KV-store

    # Delete it
    Delete Device    ${olt_device_id}

    # TODO: Verify kv-store is scrubbed of OLT handler specific items

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTSingleEnableTest

OLT Adapter Can Be Disabled and Deleted
    [Documentation]    Validates the Tibit OLT Device adapter can be disabled after
    ...                previously being enabled and then deleted
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTSingleDisableTest
    ...    AND    Clear All Devices Then Create New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Disable
    Disable Device  ${olt_device_id}

    # Delete it while disabled
    Delete Device    ${olt_device_id}

    # TODO: Verify kv-store is scrubbed of OLT handler specific items

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTSingleDisableTest

OLT Adapter Cleans up kv-store on Delete
    [Documentation]    Validates after delete of and OLT, kv-store is scrubbed
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTSingleDeleteTest
    ...    AND    Clear All Devices Then Create New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux

    # Start test
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    # Let it run for a little bit so that most all processes have done
    # something by now
    Sleep     60s

    # Delete it
    Delete Device    ${olt_device_id}

    # TODO: Verify kv-store is scrubbed of OLT handler specific items

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTSingleDeleteTest

# TODO: A list of future tests to try (with no onus)
#
#  - Reboot while enabled
#  - Reboot while disabled
#  - Reboot while enabled, but disable before reboot completes
#  - Reboot while disabled, but enable before reboot completes
#  - Reboot while enabled, but delete before reboot completes
#  - Reboot while disabled, but delete before reboot completes
#  - PON Port Disable/Enable while enabled
#  - PON Port Disable/Enable while disabled
#  - PON Port Disable  - Repeat 6 reboot tests above with PON port disbled
#
#################
# TODO: In a separate failures suite for NO ONUs, *** test cases ***
#  - Enable but OLT never discovered (no network connectivity)
#  - Enable but OLT MAC address is invalid format
#  - Enable but OLT is in EPON mode
#  - Enable but OLT is in auto boot mode

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
