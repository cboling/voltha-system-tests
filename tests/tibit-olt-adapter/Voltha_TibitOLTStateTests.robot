*** Settings ***
Documentation     Tests various states and conditions a Tibit OLT can be in without ONUs present
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
${KUBERNETES_CONFIGS_DIR}   ../tibit-olt-adapter
${KUBERNETES_YAML}          ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.yml
${HELM_CHARTS_DIR}          ~/k8s/helm
${VOLTHA_POD_NUM}           8
${NAMESPACE}                voltha

# For below variable value, using deployment name as using grep for
# parsing radius pod name, we can also use full radius pod name
${RESTART_POD_NAME}  radius
${timeout}           60s
${of_id}             0
${logical_id}        0
${has_dataplane}     False              #  was -> True
${external_libs}     True
${teardown_device}   True
${scripts}           ../../scripts

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

# state to test variable, can be passed via the command line too
${state2test}           6
${testmode}             SingleState
${porttest}             True
${debugmode}            False
${logging}              False
${pausebeforecleanup}   False

*** Test Cases ***

OLT Adapter Preprovisioning
    [Documentation]    Validates the Tibit OLT Device adapter can be pre-provisioned
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTPreprovisionTest
    ...    AND    Clear All Devices Then Preprovision New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    Test Empty Device List

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTPreprovisionTest

OLT Adapter Can Be Enabled
    [Documentation]    Validates the Tibit OLT Device adapter can be enabled
    [Tags]    statetest    tibitolttest
    [Setup]    Run Keywords    Start Logging    OLTSingleEnableTest
    ...    AND    Clear All Devices Then Create New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Enable Device     ${olt_device_id}
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}

    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    OLTSingleEnableTest

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
#    ${olt_ip}=    Evaluate    ${olts}[0].get("ip")
#    ${olt_ssh_ip}=    Evaluate    ${olts}[0].get("sship")
#    ${olt_user}=    Evaluate    ${olts}[0].get("user")
#    ${olt_pass}=    Evaluate    ${olts}[0].get("pass")
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
#    Set Suite Variable    ${olt_ip}
#    Set Suite Variable    ${olt_ssh_ip}
#    Set Suite Variable    ${olt_user}
#    Set Suite Variable    ${olt_pass}
    @{container_list}=    Create List    adapter-tibit-olt  adapter-open-olt    adapter-open-onu    voltha-api-server
    ...    voltha-ro-core    voltha-rw-core-11    voltha-rw-core-12    voltha-ofagent
    Set Suite Variable    ${container_list}
    ${datetime}=    Get Current Date
    Set Suite Variable    ${datetime}


    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}

Clear All Devices Then Preprovision New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Remove all devices from voltha and nos
    Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Preprovision Tibit

Clear All Devices Then Create New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Remove all devices from voltha and nos
    Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Setup Tibit


Setup Test
    [Documentation]    Pre-test Setup
    #test for empty device list
    Test Empty Device List
    Sleep    60s
    #create/preprovision device
    #read all bbsims
    ${rc}    ${num_bbsims}    Run And Return Rc And Output    kubectl get pod -n voltha | grep bbsim | wc -l
#    Should Be Equal As Integers    ${rc}    0
#    Should Not Be Empty    ${num_bbsims}
#    Should Not Be Equal As Integers    ${num_bbsims}    0
#    Run Keyword Unless    ${has_dataplane}    Set Suite Variable    ${num_olts}    ${num_bbsims}
#    FOR    ${I}    IN RANGE    0    ${num_olts}
#        ${olt_device_id}=    Create Device    ${list_olts}[${I}][ip]    ${OLT_PORT}
#        Set Suite Variable    ${olt_device_id}
#        #validate olt states
#        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN
#        ...    ${olt_device_id}
#        Sleep    5s
#        Enable Device    ${olt_device_id}
#        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
#        ...    ${olt_serial_number}
#        ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
#        Set Suite Variable    ${logical_id}
#    END

