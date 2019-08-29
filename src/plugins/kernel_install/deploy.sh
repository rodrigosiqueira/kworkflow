#!/bin/bash

# This script will be executed via ssh, because of this, I can't see any good
# reason (until now) for making things complicated here. For simplicity sake,
# this script will execute from "$HOME/kw_deploy".
cd $HOME/kw_deploy

# Load specific distro script
. distro_deploy.sh --source-only

case $1 in
  --modules)
    shift # Get rid of --modules
    install_modules $@
    ;;
  --kernel_update)
    shift # Get rid of --kernel_update
    install_kernel $@
    ;;
  *)
    echo "Unknown operation"
    ;;
esac
