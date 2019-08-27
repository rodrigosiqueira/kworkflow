# Kworkflow treats this script as a plugin for installing a new Kernel or
# module on ArchLinux. It is essential to highlight that this file follows an
# API that can be seen in the "deploy.sh" file, if you make any change here,
# you have to do it inside the install_modules() and install_kernel().

# Install modules
function install_modules()
{
  local module_target=$1
  local ret

  if [[ ! -z "$module_target" ]]; then
    module_target=*.tar
  fi

  tar -C /lib/modules -xf $module_target
  ret="$?"

  if [[ "$ret" != 0 ]]; then
    echo "Warning: Couldn't extract module archive."
  fi
}

# Install kernel
function install_kernel()
{
  # Copy kernel image
  if [[ -f /boot/vmlinuz-kw ]]; then
    cp /boot/vmlinuz-kw /boot/vmlinuz-kw.old
  fi

  cp -v vmlinuz-kw /boot/vmlinuz-kw
  # Update mkinitcpio
  cp -v kw.preset /etc/mkinitcpio.d/
  mkinitcpio -p kw

  # Update grub
  grub-mkconfig -o /boot/grub/grub.cfg

  # Reboot
  echo "REBOOTTT"
}
