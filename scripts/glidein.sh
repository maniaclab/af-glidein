#!/bin/bash

TMPDIR=$(mktemp -d /scratch/vc3-glidein.XXXX)

cp vc3-glidein osgvo-node-advertise wrapper.sh condor_password spt-config $TMPDIR
pushd $TMPDIR

./vc3-glidein -c condor.grid.uchicago.edu -p condor_password -e spt-config -W wrapper.sh -P osgvo-node-advertise -t -d -m 16384 -D 8

popd
