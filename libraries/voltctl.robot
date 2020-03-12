# Copyright 2017-present Open Networking Foundation
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
# voltctl common functions

*** Settings ***
Documentation     Library for various utilities
Library           SSHLibrary
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

*** Keywords ***
Test Empty Device List
    [Documentation]    Verify that there are no devices in the system
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    Should Be Equal As Integers    ${length}    0

Create Device
    [Arguments]    ${ip}    ${port}
    [Documentation]    Creates a device in VOLTHA
    #create/preprovision device
    ${rc}    ${device_id}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device create -t openolt -H ${ip}:${port}
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${device_id}

Enable Device
    [Arguments]    ${device_id}
    [Documentation]    Enables a device in VOLTHA
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device enable ${device_id}
    Should Be Equal As Integers    ${rc}    0

Disable Device
    [Arguments]    ${device_id}
    [Documentation]    Disables a device in VOLTHA
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device disable ${device_id}
    Should Be Equal As Integers    ${rc}    0

Delete Device
    [Arguments]    ${device_id}
    [Documentation]    Deletes a device in VOLTHA
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device delete ${device_id}
    Should Be Equal As Integers    ${rc}    0

Disable Devices In Voltha
    [Documentation]    Disables all the known devices in voltha
    [Arguments]    ${filter}
    ${arg}=    Set Variable    ${EMPTY}
    ${arg}=    Run Keyword If    len('${filter}'.strip()) != 0    Set Variable    --filter ${filter}
    ${rc}    ${devices}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device list ${arg} --orderby Root -q | xargs echo -n
    Should Be Equal As Integers    ${rc}    0
    ${rc}    ${output}=    Run Keyword If    len('${devices}') != 0    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device disable ${devices}
    Run Keyword If    len('${devices}') != 0    Should Be Equal As Integers    ${rc}    0

Test Devices Disabled In Voltha
    [Documentation]    Tests to verify that all devices in VOLTHA are disabled
    [Arguments]    ${filter}
    ${rc}    ${count}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device list --filter '${filter},AdminState!=DISABLED' -q | wc -l
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${count}    0

Delete Devices In Voltha
    [Documentation]    Disables all the known devices in voltha
    [Arguments]    ${filter}
    ${arg}=    Set Variable    ${EMPTY}
    ${arg}=    Run Keyword If    len('${filter}'.strip()) != 0    Set Variable    --filter ${filter}
    ${rc}    ${devices}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device list ${arg} --orderby Root -q | xargs echo -n
    Should Be Equal As Integers    ${rc}    0
    ${rc}    ${output}=    Run Keyword If    len('${devices}') != 0    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device delete ${devices}
    Run Keyword If    len('${devices}') != 0    Should Be Equal As Integers    ${rc}    0

Get Device Flows from Voltha
    [Arguments]    ${device_id}
    [Documentation]    Gets device flows from VOLTHA
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device flows ${device_id}
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${output}

Get Logical Device Output from Voltha
    [Arguments]    ${device_id}
    [Documentation]    Gets logicaldevice flows and ports from VOLTHA
    ${rc1}    ${flows}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl logicaldevice flows ${device_id}
    ${rc2}    ${ports}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl logicaldevice port list ${device_id}
    Log    ${flows}
    Log    ${ports}
    Should Be Equal As Integers    ${rc1}    0
    Should Be Equal As Integers    ${rc2}    0

Get Device Output from Voltha
    [Arguments]    ${device_id}
    [Documentation]    Gets device flows and ports from VOLTHA
    ${rc1}    ${flows}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device flows ${device_id}
    ${rc2}    ${ports}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device port list ${device_id}
    Log    ${flows}
    Log    ${ports}
    Should Be Equal As Integers    ${rc1}    0
    Should Be Equal As Integers    ${rc2}    0

Get Device List from Voltha
    [Documentation]    Gets Device List Output from Voltha
    ${rc1}    ${devices}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device list
    Log    ${devices}
    Should Be Equal As Integers    ${rc1}    0

Validate Device
    [Documentation]
    ...    Parses the output of "voltctl device list" and inspects a device ${id}, specified as either
    ...    the serial number or device ID. Arguments are matched for device states of: "admin_state",
    ...    "oper_status", and "connect_status"
    [Arguments]    ${admin_state}    ${oper_status}    ${connect_status}
    ...    ${id}=${EMPTY}    ${onu_reason}=${EMPTY}    ${onu}=False
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    ${length}=    Get Length    ${jsondata}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${astate}=    Get From Dictionary    ${value}    adminstate
        ${opstatus}=    Get From Dictionary    ${value}    operstatus
        ${cstatus}=    Get From Dictionary    ${value}    connectstatus
        ${sn}=    Get From Dictionary    ${value}    serialnumber
        ${devId}=    Get From Dictionary    ${value}    id
        ${mib_state}=    Get From Dictionary    ${value}    reason
        ${matched}=    Set Variable If    '${sn}' == '${id}' or '${devId}' == '${id}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match found for ${id} to validate device
    Log    ${value}
    Should Be Equal    '${astate}'    '${admin_state}'    Device ${sn} admin_state != ${admin_state}
    ...    values=False
    Should Be Equal    '${opstatus}'    '${oper_status}'    Device ${sn} oper_status != ${oper_status}
    ...    values=False
    Should Be Equal    '${cstatus}'    '${connect_status}'    Device ${sn} conn_status != ${connect_status}
    ...    values=False
    Run Keyword If    '${onu}' == 'True'    Should Be Equal    '${mib_state}'    '${onu_reason}'
    ...    Device ${sn} mib_state incorrect (${mib_state}) values=False

Validate OLT Device
    [Arguments]    ${admin_state}    ${oper_status}    ${connect_status}    ${id}=${EMPTY}
    [Documentation]    Parses the output of "voltctl device list" and inspects device ${id}, specified
    ...    as either its serial numbner or device ID. Match on OLT Serial number or Device Id and inspect states
    Validate Device    ${admin_state}    ${oper_status}    ${connect_status}    ${id}

Validate ONU Devices
    [Arguments]    ${admin_state}    ${oper_status}    ${connect_status}    ${List_ONU_Serial}
    [Documentation]    Parses the output of "voltctl device list" and inspects device    ${List_ONU_Serial}
    ...    Iteratively match on each Serial number contained in ${List_ONU_Serial} and inspect
    ...    states including MIB state
    FOR    ${serial_number}    IN    @{List_ONU_Serial}
        Validate Device    ${admin_state}    ${oper_status}    ${connect_status}    ${serial_number}
        ...    onu_reason=omci-flows-pushed    onu=True
    END

Validate Device Port Types
    [Documentation]
    ...    Parses the output of voltctl device port list <device_id> and matches the port types listed
    [Arguments]    ${device_id}    ${pon_type}    ${ethernet_type}
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device port list ${device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${astate}=    Get From Dictionary    ${value}    adminstate
        ${opstatus}=    Get From Dictionary    ${value}    operstatus
        ${type}=    Get From Dictionary    ${value}    type
        #Should Be Equal    '${astate}'    'ENABLED'    Device ${device_id} port admin_state != ENABLED    values=False
        #Should Be Equal    '${opstatus}'    'ACTIVE'    Device ${device_id} port oper_status != ACTIVE    values=False
        Should Be True    '${type}' == '${pon_type}' or '${type}' == '${ethernet_type}'
        ...    Device ${device_id} port type is neither ${pon_type} or ${ethernet_type}
    END

Validate OLT Port Types
    [Documentation]    Parses the output of voltctl device port list ${olt_device_id} and matches the port types listed
    [Arguments]    ${pon_type}    ${ethernet_type}
    Validate Device Port Types    ${olt_device_id}    ${pon_type}    ${ethernet_type}

Validate ONU Port Types
    [Arguments]    ${List_ONU_Serial}    ${pon_type}    ${ethernet_type}
    [Documentation]    Parses the output of voltctl device port list for each ONU SN listed in ${List_ONU_Serial}
    ...    and matches the port types listed
    FOR    ${serial_number}    IN    @{List_ONU_Serial}
        ${onu_dev_id}=    Get Device ID From SN    ${serial_number}
        Validate Device Port Types    ${onu_dev_id}    ${pon_type}    ${ethernet_type}
    END

Validate Device Flows
    [Arguments]    ${device_id}    ${flow_count}=${EMPTY}
    [Documentation]    Parses the output of voltctl device flows <device_id> and expects flow count > 0
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device flows ${device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    Log    'Number of flows = ' ${length}
    Run Keyword If    '${flow_count}' == '${EMPTY}'    Should Be True    ${length} > 0
    ...    Number of flows for ${device_id} was 0
    ...    ELSE    Should Be True    ${length} == ${flow_count}
    ...    Number of flows for ${device_id} was not ${flow_count}

Validate OLT Flows
    [Arguments]    ${flow_count}=${EMPTY}
    [Documentation]    Parses the output of voltctl device flows ${olt_device_id}
    ...    and expects flow count == ${flow_count}
    Validate Device Flows    ${olt_device_id}    ${flow_count}

Validate ONU Flows
    [Arguments]    ${List_ONU_Serial}    ${flow_count}=${EMPTY}
    [Documentation]    Parses the output of voltctl device flows for each ONU SN listed in ${List_ONU_Serial}
    ...    and expects flow count == ${flow_count}
    FOR    ${serial_number}    IN    @{List_ONU_Serial}
        ${onu_dev_id}=    Get Device ID From SN    ${serial_number}
        Validate Device Flows    ${onu_dev_id}    ${flow_count}
    END

Validate Logical Device
    [Documentation]    Validate Logical Device is listed
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl logicaldevice list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${devid}=    Get From Dictionary    ${value}    id
        ${rootdev}=    Get From Dictionary    ${value}    rootdeviceid
        ${sn}=    Get From Dictionary    ${value}    serialnumber
        Exit For Loop
    END
    Should Be Equal    '${rootdev}'    '${olt_device_id}'    Root Device does not match ${olt_device_id}    values=False
    Should Be Equal    '${sn}'    '${BBSIM_OLT_SN}'    Logical Device ${sn} does not match ${BBSIM_OLT_SN}
    ...    values=False
    [Return]    ${devid}

Validate Logical Device Ports
    [Arguments]    ${logical_device_id}
    [Documentation]    Validate Logical Device Ports are listed and are > 0
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl logicaldevice port list ${logical_device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    Should Be True    ${length} > 0    Number of ports for ${logical_device_id} was 0

Validate Logical Device Flows
    [Arguments]    ${logical_device_id}
    [Documentation]    Validate Logical Device Flows are listed and are > 0
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl logicaldevice flows ${logical_device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    Should Be True    ${length} > 0    Number of flows for ${logical_device_id} was 0

Retrieve Peer List From OLT
    [Arguments]    ${olt_peer_list}
    [Documentation]    Retrieve the list of peer device id list from port list
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device port list ${olt_device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${type}=    Get From Dictionary    ${value}    type
        ${peers}=    Get From Dictionary    ${value}    peers
        ${matched}=    Set Variable If    '${type}' == 'PON_OLT'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No PON port found for OLT ${olt_device_id}
    ${length}=    Get Length    ${peers}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${peers}    ${INDEX}
        ${peer_id}=    Get From Dictionary    ${value}    deviceid
        Append To List    ${olt_peer_list}    ${peer_id}
    END

Validate OLT Peer Id List
    [Arguments]    ${olt_peer_id_list}
    [Documentation]    Match each entry in the ${olt_peer_id_list} against ONU device ids.
    FOR    ${peer_id}    IN    @{olt_peer_id_list}
        Match OLT Peer Id    ${peer_id}
    END

Match OLT Peer Id
    [Arguments]    ${olt_peer_id}
    [Documentation]    Lookup the OLT Peer Id in against the list of ONU device Ids
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${devid}=    Get From Dictionary    ${value}    id
        ${matched}=    Set Variable If    '${devid}' == '${olt_peer_id}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    Peer id ${olt_peer_id} does not match any ONU device id

Validate ONU Peer Id
    [Arguments]    ${olt_device_id}    ${List_ONU_Serial}
    [Documentation]    Match each ONU peer to that of the OLT device id
    FOR    ${onu_serial}    IN    @{List_ONU_Serial}
        ${onu_dev_id}=    Get Device ID From SN    ${onu_serial}
        Match ONU Peer Id    ${onu_dev_id}
    END

Match ONU Peer Id
    [Arguments]    ${onu_dev_id}
    [Documentation]    Match an ONU peer to that of the OLT device id
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device port list ${onu_dev_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${type}=    Get From Dictionary    ${value}    type
        ${peers}=    Get From Dictionary    ${value}    peers
        ${matched}=    Set Variable If    '${type}' == 'PON_ONU'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No PON port found for ONU ${onu_dev_id}
    ${length}=    Get Length    ${peers}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${peers}    ${INDEX}
        ${peer_id}=    Get From Dictionary    ${value}    deviceid
    END
    Should Be Equal    '${peer_id}'    '${olt_device_id}'
    ...    Mismatch between ONU peer ${peer_id} and OLT device id ${olt_device_id}    values=False

Get Device ID From SN
    [Arguments]    ${serial_number}
    [Documentation]    Gets the device id by matching for ${serial_number}
    ${rc}    ${id}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device list --filter=SerialNumber=${serial_number} --format='{{.Id}}'
    Should Be Equal As Integers    ${rc}    0
    Log    ${id}
    [Return]    ${id}

Get Logical Device ID From SN
    [Arguments]    ${serial_number}
    [Documentation]    Gets the device id by matching for ${serial_number}
    ${rc}    ${id}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl logicaldevice list --filter=SerialNumber=${serial_number} --format='{{.Id}}'
    Should Be Equal As Integers    ${rc}    0
    Log    ${id}
    [Return]    ${id}

Build ONU SN List
    [Arguments]    ${serial_numbers}
    [Documentation]    Appends all ONU SNs to the ${serial_numbers} list
    FOR    ${INDEX}    IN RANGE    0    ${num_onus}
        Append To List    ${serial_numbers}    ${hosts.src[${INDEX}].onu}
    END

Get SN From Device ID
    [Arguments]    ${device_id}
    [Documentation]    Gets the device id by matching for ${device_id}
    ${rc}    ${sn}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device list --filter=Id=${device_id} --format='{{.SerialNumber}}'
    Should Be Equal As Integers    ${rc}    0
    Log    ${sn}
    [Return]    ${sn}

Get Parent ID From Device ID
    [Arguments]    ${device_id}
    [Documentation]    Gets the device id by matching for ${device_id}
    ${rc}    ${pid}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device list --filter=Id=${device_id} --format='{{.ParentId}}'
    Should Be Equal As Integers    ${rc}    0
    Log    ${pid}
    [Return]    ${pid}

Validate Device Removed
    [Arguments]    ${id}
    [Documentation]    Verifys that device, ${serial_number}, has been removed
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    @{ids}=    Create List
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${device_id}=    Get From Dictionary    ${value}    id
        Append To List    ${ids}    ${device_id}
    END
    List Should Not Contain Value    ${ids}    ${id}

Reboot ONU
    [Arguments]    ${onu_id}    ${src}   ${dst}
    [Documentation]   Using voltctl command reboot ONU and verify that ONU comes up to running state
    ${rc}    ${devices}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device reboot ${onu_id}
    Should Be Equal As Integers    ${rc}    0
    Run Keyword and Ignore Error    Wait Until Keyword Succeeds    60s   1s    Validate Device
    ...    ENABLED    DISCOVERED    UNREACHABLE   ${onu_id}    onu=True
