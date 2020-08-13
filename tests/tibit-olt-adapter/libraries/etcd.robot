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
Library           SSHLibrary
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

Resource          ../../../libraries/utils.robot


*** Variables ***
${timeout}        120s
${adapter_namespace}   voltha
${ETCD_namespace}      default
${ETCD_resources}      statefulsets
${ETCD_name}           etcd

*** Keywords ***
ETCD Get Voltha Service
    [Documentation]    Retrieve information from the ETCD kv-store for service/voltha keys
    [Arguments]    ${namespace} ${path}=${EMPTY} ${keys_only}=False

    ${full_path}=       Set Variable      service/voltha/${path}
    ${opt_args}=        Set Variable If   --keys-only
    ${rc}  ${results}=  Run and Return Rc and Output
    ...    kubectl exec -it -n ${namespace} ${ETCD_name} -- etcdctl get ${full_path} --prefix ${opt_args}
    Should Be Equal As Integers    ${rc}    0
    LOG   ${results}
    [Return]    ${results}


ETCD Delete Voltha Service
    [Documentation]    Delete information from the ETCD kv-store for service/voltha keys.
    ...                This keyword returns the number of keys on the first line. If you
    ...                specify '--prev-kv', it will return the deleted items on following
    ...                lines.
    [Arguments]    ${namespace} ${path} ${opt_args}=${EMPTY}

    ${full_path}=       Set Variable      service/voltha/${path}

    ${length}=    Get Length         ${path}
    Should Not Be Equal As Integers   ${length}    0

    ${rc}  ${rows}=  Run and Return Rc and Output
    ...    kubectl exec -it -n ${namespace} ${ETCD_name} -- etcdctl del ${full_path} --prefix ${opt_args}
    Should Be Equal As Integers    ${rc}    0
    LOG   ${rows}

    [Return]    ${rows}

ETCD Startup Scrub
    [Documentation]    Deletes several known sets of keys that have a tendendency of hanging
    ...                around if a previous test did not clean things up
    [Arguments]    ${namespace}

    @{cleanup_list}=    Create List    omci_mibs resource_manager

    for    ${path}   IN    @{cleanup_list}
        ${rc}  ${rows}=  Run and Return Rc and Output
        ...    kubectl exec -it -n ${namespace} ${ETCD_name} -- etcdctl del ${path} --prefix
        Should Be Equal As Integers    ${rc}    0
        LOG   ${rows}
    END

ETCD Adapter Cleaned Up
    [Documentation]    Checks for various keys that should be removed on adapter delete. For
    ...                some of the keys below, some adapters may never create them, which is
    ...                okay as we are looking for them 'not' being there.
    [Arguments]    ${namespace}  ${device_id}

    @{key_list}=    Create List    omci_mibs  resource_manager/xgspon  devices

    for    ${path}   IN    @{key_list}
        ${rc}  ${rows}=  Run and Return Rc and Output
        ...    kubectl exec -it -n ${namespace} ${ETCD_name} -- etcdctl get ${path}/${device_id} --prefix --get-keys
        Should Be Equal As Integers    ${rc}     0
        # Should Be Equal As Integers    ${rows}   0          # TODO: Needs debugging.
        LOG   ${rows}
    END