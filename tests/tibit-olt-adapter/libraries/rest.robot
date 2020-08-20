# --------------------------------------------------------------#
# Copyright (C) 2020 - present by Tibit Communications, Inc.    #
# All rights reserved.                                          #
#                                                               #
#    _______ ____  _ ______                                     #
#   /_  __(_) __ )(_)_  __/                                     #
#    / / / / __  / / / /                                        #
#   / / / / /_/ / / / /                                         #
#  /_/ /_/_____/_/ /_/                                          #
#                                                               #
# --------------------------------------------------------------#

*** Settings ***
Documentation     Library for various Tibit REST utilities
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

Resource          ../../../libraries/utils.robot


*** Variables ***
${rest_node}        localhost
${rest_port}        8888
${rest_username}    admin
${rest_password}    admin
${rest_timeout}     10
&{basic_headers}    Content-Type=application/json  Authorization=Basic ABCDEF==

*** Keywords ***
REST Get Value
    [Documentation]   Retrieve JSON information via a REST GET request
    [Arguments]       ${path}=/

    ${auth}          Create List  ${rest_username}   ${rest_password}
    Create Session   alias=tibit   url=http://${rest_node}:${rest_port}
    ...              auth=${auth}  headers=${basic_headers}   timeout=${rest_timeout}

    ${resp}=          Get Request   tibit      ${path}
    Status Should Be  200           ${resp}

    LOG         ${resp}
    [Return]    ${resp.json()}

REST Set Value
    [Documentation]   Retrieve JSON information via a REST GET request
    [Arguments]       ${path}=/  ${value}=${EMPTY}

    ${auth}          Create List  ${rest_username}   ${rest_password}
    Create Session   alias=tibit   url=http://${rest_node}:${rest_port}
    ...              auth=${auth}  headers=${basic_headers}   timeout=${rest_timeout}

    ${resp}=          Put Request   tibit      ${path}    data=${value}
    Status Should Be  200           ${resp}

REST Get Build Info
    [Documentation]   Retrieve JSON build information via a REST GET request

    ${data}=    REST Get Value      /build_info
    LOG         ${data}
    [Return]    ${data}

REST Set Discovery Method
    [Documentation]  Set an OLT's PON Port discovery method to either "manual" or "periodic"
    [Arguments]      ${device_id}  ${method}

    &{value}=     Create Dictionary  method=${method}
    ${results}=   REST Set Value     /device/${device_id}/pon/discovery  ${value}

REST Get Active ONUs
    [Documentation]  Get a dictionary of ONU IDs/Serial Numbers for an OLTs active
    ...              ONUs as seen by the OLT. This is from the OLT device adapter itself
    ...              and may be different from what is reported in VOLCTL.  This allows
    ...              for validation that internal to the OLT, one or more ONUs have been
    ...              deleted based upon OLT state, PON port state, ...
    [Arguments]      ${device_id}

    &{onus}=    Create Dictionary
    ${data}=    REST Get Value      /device/${device_id}/pon/onus
    LOG         ${data}
    [Return]    ${data}