function distro_kernel_install()
{
  local name=$1
  local boot_path=$2
  local mkinitcpio_name=$3
  local mkinitcpio_path=$4
  local vm=1

  [[ "$@" =~ "--host" ]] && vm=0

  if ! is_kernel_root "$PWD"; then
    complain "Execute this command in a kernel tree."
    exit 125 # ECANCELED
  fi

  # Validate kernel name
  if [[ -z $name || $name =~ "nothing" ]]; then
    name=$(ask_input "There's no kernel name specified. Type a name: ")

    if [[ -z $name ]]; then
      complain "No name specified, operation aborted"
      exit 22 # EINVAL
    fi
    say "New Kernel name: $name"
  fi

  # Validate boot path
  if [[ ! -d $boot_path ]]; then
    if [[ $(ask_yN "Boot path does not exists. Use /boot?") =~ "0" ]]; then
      boot_path="/boot"
    else
      exit 125 # ECANCELED
    fi
  fi

  # Validate path to mkinitcpio
  if [[ ! -d $mkinitcpio_path ]]; then
    complain "You need to specify a valid mkinitcpio path"
    exit 22 # EINVAL
  fi

#  update_kernel_img $name $boot_path $vm
#  handle_mkinitcpio $mkinitcpio_name $mkinitcpio_path $name $vm
#  update_grub $vm
}

function update_kernel_img()
{
  local name=$1
  local path=$2
  local vm=$3

  if [[ $vm == 1 ]]; then
    # TODO: VM
    return 0
  fi

  # Just for security sake, make a backup
  cmd_manager "sudo -E cp $path/$name $path/$name.old"
  cmd_manager "sudo -E cp -v arch/x86_64/boot/bzImage $path/$name"
}

function handle_mkinitcpio()
{
  local mkinitcpio_name=$1.preset
  local mkinitcpio_path=$2
  local name=$3.preset
  local vm=$4
  local target_mkinitcpio=$(path_concat $mkinitcpio_path $mkinitcpio_name)
  local bkp_mkinitcpio=$(path_concat $mkinitcpio_path $name)

  # Validate mkinitcpio name
  if [[ ! -f $target_mkinitcpio ]]; then
    if [[ ! -f $bkp_mkinitcpio ]]; then
      if [[ $(ask_yN "There's no mkinitcpio specified. Create $bkp__mkinitcpio?") =~ "0" ]]; then
        cmd_manager "sudo -E cp $etc_files_path/default_mkinitcpio.preset $bkp_mkinitcpio"
        cmd_manager "sudo -E sed -i "s/TARGET/$name/g" $bkp_mkinitcpio.preset"
        mkinitcpio_name=$name
      else
        exit 125 # ECANCELED
      fi
    else
      mkinitcpio_name=$name
    fi
  fi

  if [[ $vm == 1 ]]; then
    # TODO: VM
    return 0
  fi

  # Host
  #sudo -E cp /etc/mkinitcpio.d/linux.preset /etc/mkinitcpio.d/linux-[NAME].preset
  cmd_manager "sudo -E mkinitcpio -p ${mkinitcpio_name//.preset}"
}

function update_grub()
{
  local vm=$1

  if [[ $vm == 1 ]]; then
    # TODO: VM
    return 0
  fi

  # Host
  cmd_manager "sudo grub-mkconfig -o /boot/grub/grub"
}
