# TODO: IMPROVE IT
# It is required to be a root in order to install new modules and kernel
# version in a target machine, with this idea in mind and for simplicity sake,
# we rely on "/root" directory. Base on that, this preparation step in the
# remote machine hardcoded the "/root" directory.

. $src_script_path/vm.sh --source-only
. $src_script_path/kwlib.sh --source-only
. $src_script_path/remote.sh --source-only

function modules_install_to()
{
  local install_to=$1

  if ! is_kernel_root "$PWD"; then
    complain "Execute this command in a kernel tree."
    exit 125 # ECANCELED
  fi

  say "make INSTALL_MOD_PATH=$install_to modules_install"
  make INSTALL_MOD_PATH=$install_to modules_install
  release=$(make kernelrelease)
  say $release
}

function vm_modules_install
{
  # Attention: The vm code have to be loaded before this function.
  # Take a look at the beginning of kworkflow.sh.
  vm_mount

  if [ "$?" != 0 ] ; then
    complain "Did you check if your VM is running?"
    return 125 # ECANCELED
  fi

  # XXX: This code is a duplication from modules_install_to()
  # Just delete replace the below code by the function modules_install_to().
  set +e
  make INSTALL_MOD_PATH=${configurations[mount_point]} modules_install
  release=$(make kernelrelease)
  say $release
  vm_umount
}

# This function expects a parameter that could be '--host' or anything else; in
# the first case, the host machine is the target, and otherwise the virtual
# machine.
#
# @target Target machine
function modules_install
{
  local target=$1

  if ! is_kernel_root "$PWD"; then
    complain "Execute this command in a kernel tree."
    exit 125 # ECANCELED
  fi

  ret=$(parser_command $@)
  case "$?" in
    1) # VM_TARGET
      echo "vm_modules_install"
      ;;
    2) # LOCAL_TARGET
      echo "sudo -E make modules_install"
      ;;
    3) # REMOTE_TARGET
      prepare_host_deploy_dir
      prepare_remote_dir $ret
      modules_install_to $kw_dir/remote/
      generate_tarball "" $release

      cp_host2remote "root" $ret "$kw_dir/to_deploy/$release.tar" $KW_DEPLOY_REMOTE

      # Execute script
      cmd_remotely "bash $KW_DEPLOY_REMOTE/deploy.sh --modules $release.tar" "root" "$ret"
      ;;
  esac
}

# kw i --name=drm-misc-next
# This function aims to validate some essential variables and based on that,
# invoke the correct plugin responsible for installing a new kernel version in
# the host or the virtual machine
#
# @: Check if the parameter has the flag '--host'
#
# Note:
# Take a look at the available kernel plugins at: src/plugins/kernel_install
function kernel_install
{
  local root_path="/"
  local host="--host"
  local distro="none"
  local boot_path="/boot"
  local mkinitcpio_path="/etc/mkinitcpio.d/"
  local kernel_name=${configurations[kernel_name]}
  local mkinitcpio_name=${configurations[mkinitcpio_name]}
  local reboot=$1
  local name=$2

  if ! is_kernel_root "$PWD"; then
    complain "Execute this command in a kernel tree."
    exit 125 # ECANCELED
  fi

  # We have to guarantee some values
  kernel_name=${kernel_name:-"nothing"}
  mkinitcpio_name=${mkinitcpio_name:-"nothing"}

  shift 2 # We have to get rid of reboot and name variable
  ret=$(parser_command $@)
  case "$?" in
    1) # VM_TARGET
      echo "VM"
      # Adapt variables for vm
     # root_path=${configurations[mount_point]}
     # boot_path=$(join_path $root_path $boot_path)
     # mkinitcpio_path=$(join_path $root_path $mkinitcpio_path)
     # kernel_name=${configurations[vm_kernel_name]}
     # mkinitcpio_name=${configurations[vm_mkinitcpio_name]}
     # host=""
    ;;
    2) # LOCAL_TARGET
      echo "TODO"
    ;;
    3) # REMOTE_TARGET
      if [[ ! -f "$kw_dir/to_deploy/$name.preset" ]]; then
        template_mkinit="$etc_files_path/template_mkinitcpio.preset"
        cp $template_mkinit $kw_dir/to_deploy/$name.preset
        sed -i "s/NAME/$name/g" $kw_dir/to_deploy/$name.preset
      fi

      cp_host2remote "root" $ret "$kw_dir/to_deploy/$name.preset" $KW_DEPLOY_REMOTE
      cp_host2remote "root" $ret "arch/x86_64/boot/bzImage" $KW_DEPLOY_REMOTE/vmlinuz-$name
      cmd_remotely "bash $KW_DEPLOY_REMOTE/deploy.sh --kernel_update $name" "root" "$ret"

      # TODO: Talvez seja melhor deixar o reboot no script especifico
      [[ "$reboot" = "1" ]] && cmd_remotely "reboot" "root" "$ret"
    ;;
  esac
}

function kernel_deploy
{
  local reboot=0
  local name=${name:-"kw"}

  for arg do
    shift
    [[ "$arg" =~ ^(--reboot|-r) ]] && reboot=1 && continue
    [[ "$arg" =~ ^(--name|-n)= ]] && name=$(echo $arg | cut -d = -f2) && continue
    set -- "$@" "$arg"
  done

  # NOTE: If we deploy a new kernel image that does not match with the modules,
  # we can break the boot. For security reason, every time we want to deploy a
  # new kernel version we also update all modules; maybe one day we can change
  # it, but for now this looks the safe option.
  modules_install $@
  kernel_install $reboot $name $@
}

function mk_build
{
  local PARALLEL_CORES=1

  if [ -x "$(command -v nproc)" ] ; then
    PARALLEL_CORES=$(nproc --all)
  else
    PARALLEL_CORES=$(grep -c ^processor /proc/cpuinfo)
  fi

  PARALLEL_CORES=$(( $PARALLEL_CORES * 2 ))

  say "make -j$PARALLEL_CORES $MAKE_OPTS"
  make -j$PARALLEL_CORES $MAKE_OPTS
}

# FIXME: Here is a legacy code, however it could be really nice if we fix it
function mk_send_mail
{
  echo -e " * checking git diff...\n"
  git diff
  git diff --cached

  echo -e " * Does it build? Did you test it?\n"
  read
  echo -e " * Are you using the correct subject prefix?\n"
  read
  echo -e " * Did you need/review the cover letter?\n"
  read
  echo -e " * Did you annotate version changes?\n"
  read
  echo -e " * Is git format-patch -M needed?\n"
  read
  echo -e " * Did you review --to --cc?\n"
  read
  echo -e " * dry-run it first!\n"


  SENDLINE="git send-email --dry-run "
  while read line
  do
    SENDLINE+="$line "
  done < emails

  echo $SENDLINE
}

# FIXME: Here we have a legacy code, check if we can remove it
function mk_export_kbuild
{
  say "export KBUILD_OUTPUT=$BUILD_DIR/$TARGET"
  export KBUILD_OUTPUT=$BUILD_DIR/$TARGET
  mkdir -p $KBUILD_OUTPUT
}

function parser_command()
{
  case $1 in
    --vm)
      return $VM_TARGET
      ;;
    --local)
      return $LOCAL_TARGET
      ;;
    --remote)
      shift # Skip '--remote' option
      # TODO: Segundo retorno com o ip pode ser -> echo "$1"
      echo $@
      return $REMOTE_TARGET
      # TODO
      # - IF [IP] next to --remote
      # - ELSEIF [IP in config file]
      # - ELSE [error]
      ;;
    *)
      # By default we use VM
      return $TARGET
      ;;
  esac
}
