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
# robot test functions

*** Settings ***
Documentation     Library for various utilities
Library           SSHLibrary
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem
Library           CORDRobot
Library           ImportResource    resources=CORDRobot

Resource          ../../../libraries/utils.robot

*** Keywords ***

Preprovision Tibit
    [Documentation]    Pre-test Setup for TibitOLT, but no enable
    #test for empty device list
    Test Empty Device List

    Run Keyword If    ${has_dataplane}    Sleep    230s
    #create/preprovision device
    ${olt_device_id}=    Create Device Tibit   ${olt_mac}

    Set Suite Variable    ${olt_device_id}

    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN    ${olt_device_id}

Setup Tibit
    [Documentation]    Pre-test Setup for TibitOLT
    Preprovision Tibit

    # Enable the device
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    380s    5s
    ...    Validate OLT Device    ENABLED    ACTIVE    REACHABLE    ${olt_serial_number}
    ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
    Set Suite Variable    ${logical_id}


Setup Tibit 2
    [Documentation]    Pre-test Setup for TibitOLT
    #test for empty device list
    Test Empty Device List

    Run Keyword If    ${has_dataplane}    Sleep    230s
    #create/preprovision device
    ${olt_device_id}=    Create Device Tibit   ${olt_mac}

    Set Suite Variable    ${olt_device_id}

    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN    ${olt_device_id}
    Sleep    5s
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    380s    5s
    ...    Validate OLT Device    ENABLED    ACTIVE    REACHABLE    ${olt_serial_number}
    ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
    Set Suite Variable    ${logical_id}