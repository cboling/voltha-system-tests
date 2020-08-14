#Copyright 2017-present Open Networking Foundation
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
Documentation     Library for various etcd / kv-store utilities
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

Resource          ../../../libraries/utils.robot


*** Variables ***
${ETCD_namespace}      default
${ETCD_name}           etcd-0

*** Keywords ***
ETCD Get Voltha Service Values
    [Documentation]   Retrieve keys and values from the ETCD kv-store for service/voltha
    [Arguments]       ${path}=${EMPTY}

    ${full_path}=       Set Variable     service/voltha/${path}
    ${rc}  ${results}=  Run and Return Rc and Output
    ...    kubectl exec -it -n ${ETCD_namespace} ${ETCD_name} -- etcdctl get ${full_path} --prefix
    Should Be Equal As Integers    ${rc}    0
    LOG   ${results}

    [Return]    ${results}


ETCD Get Voltha Service Keys
    [Documentation]   Retrieve keys only from the ETCD kv-store for service/voltha.  Unlike the
    ...               'ETCD Get Voltha Service Values' Keywork, this keyword will split the key
    ...               output into a list where each list row is a found key entry.  An empty list
    ...               is returned if the command completed successfully but no entries were found.
    [Arguments]       ${path}=${EMPTY}

    ${full_path}=      Set Variable     service/voltha/${path}
    ${rc}  ${output}=  Run and Return Rc and Output
    ...    kubectl exec -it -n ${ETCD_namespace} ${ETCD_name} -- etcdctl get ${full_path} --prefix --keys-only
    Should Be Equal As Integers    ${rc}    0
    # LOG   ${output}
    ${out_length}=   Get Length  ${output}
    @{results}=      Run Keyword If  ${out_length} > 0  Split To Lines  ${output}
    ...              ELSE                               Create List
    # LOG   ${results}
    [Return]    ${results}


ETCD Delete Voltha Service
    [Documentation]  Delete information from the ETCD kv-store for service/voltha keys.
    ...              This keyword returns the number of keys on the first line. If you
    ...              specify '--prev-kv' as the ${opt_args}, it will return the deleted
    ...              items on following lines.
    [Arguments]      ${path}  ${opt_args}=${EMPTY}

    ${full_path}=  Set Variable      service/voltha/${path}
    ${full_path}=  Get Length        '${path}'.strip()
    Should Not Be Equal As Integers  ${length}    0
    Should Not Be Equal As Integers  ${length}    len('service/voltha/')

    ${rc}  ${rows}=  Run and Return Rc and Output
    ...    kubectl exec -it -n ${ETCD_namespace} ${ETCD_name} -- etcdctl del ${full_path} --prefix ${opt_args}
    Should Be Equal As Integers    ${rc}    0
    LOG   ${rows}
    # TODO How need to weed out the status row and only return the deleted items or other output..

    [Return]    ${rows}


ETCD Startup Scrub
    [Documentation]  Deletes several known sets of keys that have a tendendency of hanging
    ...              around if a previous test did not clean things up.

    @{cleanup_list}=  Create List   omci_mibs   resource_manager

    FOR  ${PATH}  IN  @{cleanup_list}
        ${full_path}=    Set Variable      service/voltha/${PATH}
        ${rc}  ${rows}=  Run and Return Rc and Output
        ...    kubectl exec -it -n ${ETCD_namespace} ${ETCD_name} -- etcdctl del ${full_path} --prefix
        Should Be Equal As Integers    ${rc}    0
        # LOG   ${rows}
    END


ETCD Verify Adapter Cleaned Up
    [Documentation]  Checks for various keys that should be removed on adapter delete. For
    ...              some of the keys below, some adapters may never create them, which is
    ...              okay as we are looking for them 'not' being there.
    ...
    ...              Note there are some keys (logging for example) that are initialized when
    ...              an adapter first runs and are not cleaned up on device adapter exist.
    [Arguments]      ${device_id}

    @{key_list}=  Create List   omci_mibs   resource_manager/xgspon   devices

    FOR  ${PATH}  IN  @{key_list}
        ${remaining}=   ETCD Get Voltha Service Keys  ${PATH}/${device_id}
        ${out_length}=  Get Length   ${remaining}
        Should Be Equal As Integers  ${out_length}   0
    END