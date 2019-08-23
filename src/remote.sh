REMOTE_DIR="remote"
TO_DEPLOY_DIR="to_deploy"

KW_DEPLOY_REMOTE="/root/kw_deploy"

KW_DEPLOY_CMD="mkdir -p $KW_DEPLOY_REMOTE"

# This function prepares the directory ~/kw/ for receiving files to be sent for
# a remote machine.
function prepare_deploy_dir()
{
  # We should expect the setup.sh script create the directory $HOME/kw.
  # However, does not hurt check for it and create in any case
  if [[ ! -d $kw_dir ]]; then
    mkdir $kw_dir
  fi

  if [[ ! -d $kw_dir/$REMOTE_DIR ]]; then
    mkdir $kw_dir/$REMOTE_DIR
  fi

  if [[ ! -d $kw_dir/$TO_DEPLOY_DIR ]]; then
    mkdir $kw_dir/$TO_DEPLOY_DIR
  fi
}

# This function creates a "/root/kw_deploy" directory inside the remote
# machine.
#
# @ip IP address of the target machine
function prepare_remote_dir()
{
  local ip=$1

  cmd_remotely "$KW_DEPLOY_CMD" "root" "$ip"
}

# This function generates a tarball file to be sent to the target machine.
# Notice that we rely on the directory "~/kw/remote".
#
# @files_path Point to the directory with the modules files to be deployed.
# @kernel_release Kernel release name
function generate_tarball()
{
  local files_path=$1
  local kernel_release=$2
  local tarball_name=""
  local ret

  files_path=${files_path:-"$kw_dir/$REMOTE_DIR/lib/modules/"}
  kernel_release=${kernel_release:-"no_release"}
  tarball_name="$kernel_release.tar"

  tar -C $files_path -cf $kw_dir/$TO_DEPLOY_DIR/$tarball_name "$kernel_release"
  ret=$?

  if [[ "$ret" != 0 ]]; then
    complain "Error archiving modules."
    exit $ret
  fi
}
