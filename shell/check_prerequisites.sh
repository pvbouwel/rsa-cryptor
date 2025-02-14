#!/bin/bash

OPENSSL="`which openssl`"
echo $OPENSSL | grep " not found$"
if [ "$?" == 0 ]
then 
    echo "No openssl found please install"
    read _does_not_matter
    exit 1
fi

SSHKEYGEN="`which ssh-keygen`"
echo $SSHKEYGEN  | grep " not found$"
if [ "$?" == 0 ]
then 
    echo "No ssh-keygen found please install"
    read _does_not_matter
    exit 1
fi