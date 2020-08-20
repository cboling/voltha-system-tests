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
Documentation     Library for various operating system types of commands
Library           SSHLibrary
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

*** Keywords ***
Restart VOLTHA Port Forward Tibit
    [Documentation]    Uses a script to restart a kubectl port-forward for TIBIT REST
    ${cmd}	Catenate
    ...    ps -efw | grep port-forward | grep kubectl | grep -v grep |
    ...              grep -i --color=never tibit | awk '{print $2}'
    ${rc}    ${results}    Run And Return Rc And Output    ${cmd}
    Should Be Equal as Integers    ${rc}    0

    @{pids}=   Split String   ${results}
    FOR   ${pid}   IN   @{pids}
        Run Keyword If    '${pid}' != ''    Run And Return Rc    kill -9 ${pid}
        Should Be Equal as Integers    ${rc}    0
    END
