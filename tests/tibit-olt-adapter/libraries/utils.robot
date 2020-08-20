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
Resource          ./etcd.robot
Resource          ./rest.robot

*** Keywords ***

Preprovision Tibit
    [Documentation]    Pre-test Setup for TibitOLT, but no enable

    #test for empty device list
    Test Empty Device List

    #create/preprovision device
    # TODO: Support passing discovery-disable to device on startup
    ${olt_device_id}=    Create Device Tibit   ${olt_mac}

    Set Suite Variable    ${olt_device_id}

    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN    ${olt_device_id}

Setup Tibit
    [Documentation]    Pre-test Setup for TibitOLT.  Non-HA recovery method
    ...
    ...                The initial enable (after preprovisioning) on a Tibit should
    ...                take less than 60 seconds.  The OLT goes through a reboot
    ...                after first being contacted wich takes ~ 10-15 seconds and
    ...                after recontact by the device adapter, the current state is
    ...                pulled down which should only take a couple of seconds
    ...
    ...                For HA (container restart/reconciliation), use a different
    ...                keyword since that will take longer based on what needs to
    ...                be reconciled in the new device adapter or on the hardware.
    [Arguments]       ${disable_discovery}=False

    ${method}=   Set Variable If    ${disable_discovery}    manual    periodic
    LOG  Discovery method will be ${method}

    # Create the device handler
    Preprovision Tibit

    # Enable the device
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds   10s    1s
    ...   Validate OLT Device    ENABLED   ACTIVATING   UNKNOWN   ${olt_device_id}

    # Make sure discovery is set how we want it for this test
    REST Set Discovery Method    ${olt_device_id}  ${method}

    # Wait until OLT reset and capabilities discovery have completed
    Wait Until Keyword Succeeds   60s    5s
    ...    Validate OLT Device    ENABLED   ACTIVE   REACHABLE   ${olt_device_id}

    ${logical_id}=       Get Logical Device ID From SN    ${olt_device_id}
    Set Suite Variable   ${logical_id}
