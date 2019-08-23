. $src_script_path/vm.sh --source-only
. $src_script_path/kwlib.sh --source-only

function vm_modules_install
{
  # Attention: The vm code have to be loaded before this function.
  # Take a look at the beginning of kworkflow.sh.
  vm_mount

  if [ "$?" != 0 ] ; then
    complain "Did you check if your VM is running?"
    return 125 # ECANCELED
  fi

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

  case "$target" in
    --host)
      echo "sudo -E make modules_install"
      ;;
    *)
      echo "vm_modules_install"
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

  # We have to guarantee some values
  kernel_name=${kernel_name:-"nothing"}
  mkinitcpio_name=${mkinitcpio_name:-"nothing"}

  # Adapt variables for vm
  if [[ ! "$@" =~ "--host" ]]; then
   root_path=${configurations[mount_point]}
   boot_path=$(join_path $root_path $boot_path)
   mkinitcpio_path=$(join_path $root_path $mkinitcpio_path)
   kernel_name=${configurations[vm_kernel_name]}
   mkinitcpio_name=${configurations[vm_mkinitcpio_name]}
   host=""
  fi

  distro=$(detect_distro $root_path)

  if [[ $distro =~ "none" ]]; then
    complain "Unfortunately, there's no support for the target distro"
    exit 95 # ENOTSUP
  fi

  # Load the correct plugin
  . $plugins_path/kernel_install/$distro.sh --source-only

  distro_kernel_install $kernel_name $boot_path $mkinitcpio_name $mkinitcpio_path $host
}

function kernel_deploy
{
  modules_install $@
  kernel_install $@
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
