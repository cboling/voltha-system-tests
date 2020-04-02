# Copyright 2017 - present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

*** Settings ***
Documentation     Test various failure scenarios
Suite Setup       Setup Suite
Test Setup        Setup
Test Teardown     Teardown
#Suite Teardown    Teardown Suite
Library           Collections
Library           String
Library           OperatingSystem
Library           XML
Library           RequestsLibrary
Library           ../../libraries/DependencyLibrary.py
Resource          ../../libraries/onos.robot
Resource          ../../libraries/voltctl.robot
Resource          ../../libraries/voltha.robot
Resource          ../../libraries/utils.robot
Resource          ../../libraries/k8s.robot
Resource          ../../variables/variables.robot
Resource          ../../libraries/power_switch.robot

*** Variables ***
${POD_NAME}       flex-ocp-cord
${KUBERNETES_CONF}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
${KUBERNETES_CONFIGS_DIR}    ~/pod-configs/kubernetes-configs
#${KUBERNETES_CONFIGS_DIR}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
${KUBERNETES_YAML}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.yml
${HELM_CHARTS_DIR}    ~/helm-charts
${VOLTHA_POD_NUM}    8
${NAMESPACE}      voltha
# For below variable value, using deployment name as using grep for
# parsing radius pod name, we can also use full radius pod name
${RESTART_POD_NAME}    radius
${timeout}        60s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${teardown_device}    False
${scripts}        ../../scripts

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

*** Test Cases ***
Verify ONU after rebooting physically
    [Documentation]    Test the ONU functionality by physically turning on/off ONU.
    ...    Prerequisite : Subscriber are authenticated/DHCP/pingable state
    ...    Test case runs only on the PODs that are configured with PowerSwitch that
    ...    controls the power off/on ONUs/OLT remotely (simulating a physical reboot)
    ...    VOL-2634
    [Tags]    functional   PowerSwitch
    [Setup]    Run Keywords    Announce Message    START TEST ONUreboot_PowerSwitch
    ...        AND             Start Logging    ONUreboot_PowerSwitch
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    ONUreboot_PowerSwitch
    ...           AND             Announce Message    END TEST ONUreboot_PowerSwitch
    ...           AND             Delete Device and Verify
    # Add OLT device
    setup
    # Performing Sanity Test to make sure subscribers are all AUTH+DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    Power Switch Connection Suite    ${web_power_switch.ip}    ${web_power_switch.user}    ${web_power_switch.password}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Disable Switch Outlet    ${src['power_switch_port']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}

        Enable Switch Outlet    ${src['power_switch_port']}
        # Check ONU port is Enabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify EAPOL flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify Eapol Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword And Ignore Error    Collect Logs
    END
    # Deleting OLT after tests completes independently (as this test doesn't not run on each POD)
    #Run Keyword If    ${has_dataplane}    Delete Device and Verify

Verify OLT after rebooting physically
    [Documentation]    Test the physical reboot of the OLT
    ...    Prerequisite : Subscriber are authenticated/DHCP/pingable state
    ...    Test performs a physical reboot, performs "reboot" from the OLT CLI
    ...    VOL-1956
    [Tags]    functional   PhysicalOLTReboot
    [Setup]    Run Keywords    Announce Message    START TEST PhysicalOLTReboot
    ...        AND             Start Logging    PhysicalOLTReboot
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    PhysicalOLTReboot
    ...           AND             Announce Message    END TEST PhysicalOLTReboot
    ...           AND             Delete Device and Verify
    # Add OLT device
    setup
    # Performing Sanity Test to make sure subscribers are all AUTH+DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    # Reboot the OLT from the OLT CLI
    Run Keyword If    ${has_dataplane}    Login And Run Command On Remote System
    ...    sudo reboot    ${olt_ip}    ${olt_user}    ${olt_pass}   prompt=#
    Run Keyword And Ignore Error    Collect Logs
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    # Wait for the OLT to come back up
    Wait Until Keyword Succeeds    120s    10s    Check Remote System Reachability    True    ${olt_ip}
    # Waiting extra time for the ONUs to come up
    Sleep    60s
    Run Keyword And Ignore Error    Collect Logs
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    # Deleting OLT after test completes
    #Run Keyword If    ${has_dataplane}    Delete Device and Verify

Verify restart openolt-adapter container after subscriber provisioning
    [Documentation]    Restart openolt-adapter container after VOLTHA is operational.
    ...    Prerequisite : ONUs are authenticated and pingable.
    [Tags]    functional   VOL-1958   Restart-OpenOlt   released
    [Setup]    Run Keywords    Announce Message    START TEST Restart-OpenOlt
    ...        AND             Start Logging    Restart-OpenOlt
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    Restart-OpenOlt
    ...           AND             Announce Message    END TEST Restart-OpenOlt
    # Add OLT device
    setup
    # Performing Sanity Test to make sure subscribers are all AUTH+DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    ${waitforRestart}    Set Variable    120s
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBforRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${podName}    Set Variable     adapter-open-olt
    Restart Pod    ${NAMESPACE}    ${podName}
    Wait Until Keyword Succeeds    ${waitforRestart}    2s    Validate Pod Status    ${podName}    ${NAMESPACE}
    ...    Running
    # Wait for 1min after openolt adapter is restarted
    Sleep    60s
    Repeat Sanity Test
    Run Keyword and Ignore Error    Collect Logs
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBforRestart}
    Log to console    Pod ${podName} restarted and sanity checks passed successfully

Check OLT/ONU Authentication After Radius Pod Restart
    [Documentation]    After radius restart, triggers reassociation, checks status and
    ...    authentication, validates dhcp and ping. Note : wpa reassociate works only when
    ...    wpa supplicant is running in background hence it is recommended to remove
    ...    teardown from previous test or uncomment 'Teardown    None'.
    ...    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    [Tags]    functional    RadiusRestart    released
    [Setup]    Run Keywords    Announce Message    START TEST RadiusRestart
    ...        AND             Start Logging    RadiusRestart
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    RadiusRestart
    ...           AND             Announce Message    END TEST RadiusRestart
    ${waitforRestart}    Set Variable    120s
    Wait Until Keyword Succeeds    ${timeout}    15s    Restart Pod    ${NAMESPACE}    ${RESTART_POD_NAME}
    Wait Until Keyword Succeeds    ${waitforRestart}    2s    Validate Pod Status    ${RESTART_POD_NAME}   ${NAMESPACE}
    ...    Running
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify Eapol Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Validate Authentication After Reassociate    True    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU in AAA-Users    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Validate DHCP and Ping    True    True    ${src['dp_iface_name']}
        ...    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}
        ...    ${dst['pass']}    ${dst['container_type']}    ${dst['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Run Keyword And Continue On Failure
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error    Collect Logs
    END

Sanity E2E Test for OLT/ONU on POD With Core Fail and Restart
    [Documentation]    Deploys an device instance and waits for it to authenticate. After
    ...    authentication is successful the rw-core deployment is scaled to 0 instances to
    ...    simulate a POD crash. The test then scales the rw-core back to a single instance
    ...    and configures ONOS for access. The test succeeds if the device is able to
    ...    complete the DHCP sequence.
    [Tags]    functional    rwcore-restart    notready
    [Setup]    Run Keywords    Announce Message    START TEST RwCoreFailAndRestart
    ...        AND             Start Logging    RwCoreFailAndRestart
    ...        AND             Clear All Devices Then Create New Device
    [Teardown]   Run Keywords    Collect Logs
    ...          AND             Stop Logging    RwCoreFailAndRestart
    ...          AND             Announce Message    END TEST RwCoreFailAndRestart
    ...          AND             Delete Device and Verify
    Run Keyword and Ignore Error    Collect Logs
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        # Bring up the device and verify it authenticates
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${onu_device_id}    onu=True    onu_reason=omci-flows-pushed
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify Eapol Flows Added For ONU    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    ${onu_port}
        ${wpa_log}=    Run Keyword If    ${has_dataplane}    Catenate    SEPARATOR=.
        ...    /tmp/wpa    ${src['dp_iface_name']}    log
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate Authentication    True
        ...    ${src['dp_iface_name']}    wpa_supplicant.conf    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}    ${wpa_log}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU in AAA-Users    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}     ${onu_port}
    END

    # Scale down the rw-core deployment to 0 PODs and once confirmed, scale it back to 1
    Scale K8s Deployment    voltha    voltha-rw-core    0
    Wait Until Keyword Succeeds    ${timeout}    2s    Pod Does Not Exist    voltha    voltha-rw-core
    # Ensure the ofagent POD goes "not-ready" as expected
    Wait Until keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas    voltha    voltha-ofagent    0
    # Scale up the core deployment and make sure both it and the ofagent deployment are back
    Scale K8s Deployment    voltha    voltha-rw-core    1
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas    voltha    voltha-rw-core    1
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas    voltha    voltha-ofagent    1
    # For some reason scaling down and up the POD behind a service causes the port forward to stop working,
    # so restart the port forwarding for the API service
    Restart VOLTHA Port Foward    voltha-api-minimal
    # Ensure that the ofagent pod is up and ready and the device is available in ONOS, this
    # represents system connectivity being restored
    Wait Until Keyword Succeeds    ${timeout}    2s    Device Is Available In ONOS
    ...    http://karaf:karaf@${ONOS_REST_IP}:${ONOS_REST_PORT}    ${of_id}

    FOR    ${I}    IN RANGE    0    ${num_onus}
        # Add subscriber access and verify that DHCP completes to ensure system is still functioning properly
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Run Keyword And Continue On Failure
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
    END

Verify openolt adapter restart before subscriber provisioning
    [Documentation]    Deploys an device instance and waits for it to authenticate. After
    ...    authentication is successful the rw-core deployment is scaled to 0 instances to
    ...    simulate a POD crash. The test then scales the rw-core back to a single instance
    ...    and configures ONOS for access. The test succeeds if the device is able to
    ...    complete the DHCP sequence.
    [Tags]    functional    olt-adapter-restart
    [Setup]    Run Keywords    Announce Message    START TEST OltAdapterRestart
    ...        AND             Start Logging    OltAdapterRestart
    #...        AND             Clear All Devices Then Create New Device
    [Teardown]   Run Keywords    Collect Logs
    ...          AND             Stop Logging    OltAdapterRestart
    ...          AND             Announce Message    END TEST OltAdapterRestart
    # Add OLT and perform sanity test
    #setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    #Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    Set Global Variable    ${of_id}

    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}

        # Bring up the device and verify it authenticates
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device        ENABLED    ACTIVE    REACHABLE
        ...    ${onu_device_id}    onu=True    onu_reason=omci-flows-pushed
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify Eapol Flows Added For ONU    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    ${onu_port}
        ${wpa_log}=    Run Keyword If    ${has_dataplane}    Catenate    SEPARATOR=.
        ...    /tmp/wpa    ${src['dp_iface_name']}    log
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate Authentication    True
        ...    ${src['dp_iface_name']}    wpa_supplicant.conf    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}    ${wpa_log}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU in AAA-Users    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}     ${onu_port}
    END
    # Scale down the open OLT adapter deployment to 0 PODs and once confirmed, scale it back to 1
    Scale K8s Deployment    voltha    adapter-open-olt    0
    Wait Until Keyword Succeeds    ${timeout}    2s    Pod Does Not Exist    voltha    adapter-open-olt
    # Scale up the open OLT adapter deployment and make sure both it and the ofagent deployment are back
    Scale K8s Deployment    voltha   adapter-open-olt    1
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas    voltha    adapter-open-olt    1

    # Ensure the device is available in ONOS, this represents system connectivity being restored
    Wait Until Keyword Succeeds    ${timeout}    2s    Device Is Available In ONOS
    ...    http://karaf:karaf@${ONOS_REST_IP}:${ONOS_REST_PORT}    ${of_id}

    FOR    ${I}    IN RANGE    0    ${num_onus}
        # Add subscriber access and verify that DHCP completes to ensure system is still functioning properly
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Run Keyword And Continue On Failure
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
    END

Verify restart ofagent container after subscriber is provisioned
    [Documentation]    Restart ofagent container after VOLTHA is operational.
    ...    Prerequisite : ONUs are authenticated and pingable.
    #TODO: remove "notready" tag once olt reboot and ofagent restart work items are done
    [Tags]    functional   VOL-2409   ofagentRestart
    [Setup]    Run Keywords    Announce Message    START TEST ofagentRestart
    ...        AND             Start Logging    ofagentRestart
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    ofagentRestart
    ...           AND             Announce Message    END TEST ofagentRestart
    ...           AND             Scale K8s Deployment    ${NAMESPACE}    voltha-ofagent    1
    # set timeout value
    ${waitforRestart}    Set Variable    120s
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBforRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${podName}    Set Variable     ofagent
    Restart Pod    ${NAMESPACE}    ${podName}
    Sleep    60s
    Wait Until Keyword Succeeds    ${waitforRestart}    2s    Validate Pod Status    ofagent    ${NAMESPACE}
    ...    Running
    # Performing Sanity Test to make sure subscribers are all AUTH+DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBforRestart}
    # Scale Down the Of-Agent Deployment
    Scale K8s Deployment    ${NAMESPACE}    voltha-ofagent    0
    Sleep    30s
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword and Ignore Error    Collect Logs
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Check ONU port is Disabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Disabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify EAPOL flows are present for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify Eapol Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify ONU in AAA-Users
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Verify ONU in AAA-Users    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify DHCP-Allocations
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify Ping
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Check Ping    True
        ...    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error    Collect Logs
    END
    # Scale Up the Of-Agent Deployment
    Scale K8s Deployment    ${NAMESPACE}    voltha-ofagent    1
    Wait Until Keyword Succeeds    ${waitforRestart}    2s    Validate Pod Status    ofagent    ${NAMESPACE}
    ...    Running
    # Performing Sanity Test to make sure subscribers are all AUTH+DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    Log to console    Pod ${podName} restarted and sanity checks passed successfully

Check ONU adapter crash not forcing authentication again
    [Documentation]    After ONU adapter restart, checks wpa log for 'authentication started'
    ...    message count to make sure auth not started again and validates EAP status and ping.
    ...    Assuming that test1 or sanity was executed where all the ONUs are authenticated/DHCP/pingable
    [Tags]    functional    ONUAdaptCrash
    [Setup]    Run Keywords    Announce Message    START TEST ONUAdaptCrash
    ...        AND             Start Logging    ONUAdaptCrash
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    ONUAdaptCrash
    ...           AND             Announce Message    END TEST ONUAdaptCrash
    # Wait for adapter to resync
    Sleep    60s
    # Restart the onu
    ${podName}    Set Variable     adapter-open-onu
    Wait Until Keyword Succeeds    ${timeout}    15s    Restart Pod    ${NAMESPACE}    ${podName}
    # Validate ONU Ports
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Run Keyword And Continue On Failure    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    ${onu_port}
        ${output}=    Run Keyword If    ${has_dataplane}    Login And Run Command On Remote System
        ...    wpa_cli status | grep SUCCESS    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    ${has_dataplane}    Should Contain    ${output}    SUCCESS
    END
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pod Status    ${podName}    ${NAMESPACE}
    ...    Running
    # Wait for adapter to resync
    Sleep    60s
    Clean Up Linux
    # Perform all steps in Sanity Test except the subscriber addition
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword and Ignore Error    Collect Logs
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        # Check ONU port is Enabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify EAPOL flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify Eapol Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Perform Authentication
        ${wpa_log}=    Run Keyword If    ${has_dataplane}    Catenate    SEPARATOR=.
        ...    /tmp/wpa    ${src['dp_iface_name']}    log
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate Authentication    True
        ...    ${src['dp_iface_name']}    wpa_supplicant.conf    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}    ${wpa_log}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Verify ONU in AAA-Users    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify that no pending flows exist for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify No Pending Flows For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error    Collect Logs
    END

    Run Keyword and Ignore Error    Collect Logs

ONU Reboot
    [Documentation]    Reboot ONU and verify that ONU comes up properly
    [Tags]    VOL-1957    RebootONU   notready
    [Setup]    Run Keywords    Announce Message    START TEST RebootONU
    ...        AND             Start Logging    RebootONU
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    RebootONU
    ...           AND             Announce Message    END TEST RebootONU
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Reboot ONU    ${onu_device_id}   ${src}   ${dst}
        Verify ping is succesful except for given device     ${num_onus}    ${onu_device_id}
        # Check ONU port is Enabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify EAPOL flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify Eapol Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Verify pings are successful after reboot on the current ONU
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    #Run Keyword If    ${has_dataplane}    Clean Up Linux
    #Check after reboot that ONUs are active, authenticated/DHCP/pingable
    #Perform Sanity Test

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    #power_switch.robot needs it to support different vendor's power switch
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}

Clear All Devices Then Create New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Remove all devices from voltha and nos
    Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Setup
