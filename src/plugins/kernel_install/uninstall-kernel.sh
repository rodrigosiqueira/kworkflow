#!/bin/bash

function uninstall-kernel()
{
  local target=$1
  local kernelpath="/boot/vmlinuz-$target"
  local initrdpath="/boot/initrd.img-$target"
  local modulespath="/lib/modules/$target"
  local libpath="/var/lib/initramfs-tools/$target"

  if [ -z "$target" ]; then
    echo "No parameter, nothing to do"
    exit 0
  fi

  local today=$(date "+%Y-%m-%d-%T")

  if [ -f "$kernelpath" ]; then
    echo "Removing: $kernelpath"
    mv $kernelpath /tmp
  else
    echo "Can't find $kernelpath"
  fi

  if [ -f "$initrdpath" ]; then
    echo "Removing: $initrdpath"
    mv $initrdpath /tmp 
  else
    echo "Can't find: $initrdpath"
  fi

  if [ -d "$modulespath" ]; then
    echo "Removing: $modulespath"
    mv $modulespath /tmp/$today
  else
    echo "Can't find $modulespath"
  fi

  if [ -d "$libpath" ]; then
    echo "Removing: $libpath"
    mv $libpath /tmp/$today
  else
    echo "Cant't find $libpath"
  fi
}

uninstall-kernel $@
