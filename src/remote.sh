REMOTE_DIR="remote"
TO_DEPLOY_DIR="to_deploy"

KW_DEPLOY_REMOTE="/root/kw_deploy"

KW_DEPLOY_CMD="mkdir -p $KW_DEPLOY_REMOTE"

DISTRO_DEPLOY="$KW_DEPLOY_REMOTE/distro_deploy.sh"
DEPLOY_SCRIPT="$plugins_path/kernel_install/deploy.sh"

# This function is responsible for executing a command in a remote machine.
#
# @command Command to be executed inside the remote machine
# @user User in the host machine
# @ip Ip of the host machine
function cmd_remotely()
{
  local command=$1
  local remote=$2
  local port=$3
  local user=$4
  local composed_cmd=""

  if [[ -z "$command" ]]; then
    warning "No command specified"
    exit 0
  fi

  # Set default values if not specified
  remote=${remote:-"localhost"}
  port=${port:-"22"}
  user=${user:-"root"}

  composed_cmd="ssh -p $port $user@$remote \"$command\""
  cmd_manager HIGHLIGHT_CMD $composed_cmd
}

# @user User in the host machine
# @ip Ip of the host machine
# @src Origin of the file to be send
# @dst Destination for sending the file
function cp_host2remote()
{
  local src=$1
  local dst=$2
  local remote=$3
  local port=$4
  local user=$5

  remote=${remote:-"localhost"}
  port=${port:-"22"}
  user=${user:-"root"}

  src=${src:-"$kw_dir/to_deploy/*"}
  dst=${dst:-"/root/kw_deploy"}

  cmd_manager "rsync -e 'ssh -p $port' -La $src $user@$remote:$dst"
}

# This function prepares the directory ~/kw/ for receiving files to be sent for
# a remote machine.
function prepare_host_deploy_dir()
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
# machine and prepare it for deploy.
#
# @ip IP address of the target machine
function prepare_remote_dir()
{
  local ip=$1
  local port=$2

  cmd_remotely "$KW_DEPLOY_CMD" "$ip" "$port"

  # XXX: Gambi em decorrencia do bug em detect_distro
  distro_info=$(cmd_remotely "cat /etc/*-release | grep -w ID | cut -d = -f 2" "$ip" "$port")
  distro=$(detect_distro "/" "$distro_info")

  if [[ $distro =~ "none" ]]; then
    complain "Unfortunately, there's no support for the target distro"
    exit 95 # ENOTSUP
  fi

  # Send the specific deploy script as a root
  cp_host2remote "$plugins_path/kernel_install/$distro.sh" $DISTRO_DEPLOY $ip $port
  cp_host2remote "$DEPLOY_SCRIPT" $KW_DEPLOY_REMOTE/ $ip $port
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
