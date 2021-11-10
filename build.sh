#! /usr/bin/env bash

set -e

# this function is called when Ctrl-C is sent
function trap_ctrlc ()
{
    echo "### build cancelled..."
    exit 2
}

# initialise trap to call trap_ctrlc function
# when signal 2 (SIGINT) is received
trap "trap_ctrlc" 2

exit_code="0"

# cleanup
rm -rf ./bin
mkdir -p bin/efi/boot

# build
make -f ./makefile_aarch64 || exit_code="$?"
rm ./bin/uefi_bootstrap.obj

make -f ./makefile_x86_64  || exit_code="$?"
rm ./bin/uefi_bootstrap.obj

exit ${exit_code}
