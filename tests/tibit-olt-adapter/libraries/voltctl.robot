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
Resource          ../../../libraries/utils.robot


*** Keywords ***
Create Device Tibit
    [Arguments]    ${mac}     ${type}=tibit_olt
    [Documentation]    Creates a device in VOLTHA for the Tibit OLT with
    ...                a MAC Address of ${mac}
    #create/preprovision device
    ${rc}    ${device_id}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device create -t ${type} -m ${mac}
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${device_id}


Get OLT Ports
    [Documentation]    Parses the output of voltctl device port list ${olt_device_id} and matches the port types listed
    [Arguments]    ${device_id}   ${port_type}
    # Get the port numbers that match the port type
    ${rc}    ${results}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device port list ${device_id} --filter='Type=${port_type}' -m 8MB --format='{{.PortNo}}' -q
    Log    ${results}
    Should Be Equal As Integers    ${rc}    0

    Return from Keyword if  isinstance($results, list)   ${results}

    ${list_result}=    Create List
    Append To List        ${list_result}    ${results}
    Return From Keyword   ${list_result}


Validate Port Admin Status
    [Documentation]    Verifies the admin status of a specific port on an OLT device
    [Arguments]    ${device_id}   ${port_number}   ${admin_status}

    ${rc}    ${results}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device port list ${device_id} --filter='PortNo=${port_number}' -q --format='{{.AdminState}}'
    Log    ${results}
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${results} == ${admin_status}


Disable Port
    [Documentation]    Disable a port on the OLT
    [Arguments]    ${device_id}   ${port_number}
    ${rc}    ${port_numbers}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device port disable ${device_id} ${port_number}
    Should Be Equal As Integers    ${rc}    0


Enable Port
    [Documentation]    Enable a port on the OLT
    [Arguments]    ${device_id}   ${port_number}
    ${rc}    ${port_numbers}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device port enable ${device_id} ${port_number}
    Should Be Equal As Integers    ${rc}    0

