. $src_script_path/commons.sh --source-only
. $src_script_path/kwlib.sh --source-only
# We include remote.sh on fetch_config . $src_script_path/remote.sh --source-only

declare -r metadata_dir="metadata"
declare -r configs_dir="configs"

# This function handles the save operation of kernel's '.config' file. It
# checks if the '.config' exists and saves it using git (dir.:
# <kw_install_path>/configs)
#
# @force Force option. If it is set and the current name was already saved,
#        this option will override the '.config' file under the 'name'
#        specified by '-n' without any message.
# @name This option specifies a name for a target .config file. This name
#       represents the access key for .config.
# @description Description for a config file, de descrition from '-d' flag.
function save_config_file()
{
  local ret=0
  local -r force=$1
  local -r name=$2
  local -r description=$3
  local -r original_path=$PWD
  local -r dot_configs_dir="$config_files_path/configs"

  if [[ ! -f $original_path/.config ]]; then
    complain "There's no .config file in the current directory"
    exit 2 # ENOENT
  fi

  if [[ ! -d $dot_configs_dir ]]; then
    mkdir $dot_configs_dir
    cd $dot_configs_dir
    git init --quiet
    mkdir $metadata_dir $configs_dir
  fi

  cd $dot_configs_dir

  # Check if the metadata related to .config file already exists
  if [[ ! -f $metadata_dir/$name ]]; then
    touch $metadata_dir/$name
  elif [[ $force != 1 ]]; then
    if [[ $(ask_yN "$name already exists. Update?") =~ "0" ]]; then
      complain "Save operation aborted"
      cd $original_path
      exit 0
    fi
  fi

  if [[ ! -z $description ]]; then
    echo $description > $metadata_dir/$name
  fi

  cp $original_path/.config $dot_configs_dir/$configs_dir/$name
  git add $configs_dir/$name $metadata_dir/$name
  git commit -m "New config file added: $USER - $(date)" > /dev/null 2>&1

  if [[ "$?" == 1 ]]; then
    warning "Warning: $name: there's nothing new in this file"
  else
    success "Saved $name"
  fi

  cd $original_path
}

function list_configs()
{
  local -r dot_configs_dir="$config_files_path/configs"

  if [[ ! -d $dot_configs_dir ]]; then
    say "There's no tracked .config file"
    exit 0
  fi

  printf "%-30s | %-30s\n" "Name" "Description"
  echo
  for filename in $dot_configs_dir/$metadata_dir/*; do
    local name=$(basename $filename)
    local content=$(cat $filename)
    printf "%-30s | %-30s\n" "$name" "$content"
  done
}

# Remove and Get operation in the configm has similar criteria for working,
# because of this, basic_config_validations centralize the basic requirement
# validation.
#
# @target File name of the target config file
# @force Force option. If set, it will ignores the warning message.
# @operation You can specify the operation name here
# @message Customized message to be showed to the users
#
# Returns:
# Return 0 if everything ends well, otherwise return an errno code.
function basic_config_validations()
{
  local target=$1
  local force=$2
  local operation=$3 && shift 3
  local message=$@
  local -r dot_configs_dir="$config_files_path/configs/configs"

  if [[ ! -f $dot_configs_dir/$target ]]; then
    complain "No such file or directory: $target"
    exit 2 # ENOENT
  fi

  if [[ $force != 1 ]]; then
    warning $message
    if [[ $(ask_yN "Are you sure that you want to proceed?") =~ "0" ]]; then
      complain "$operation operation aborted"
      exit 0
    fi
  fi
}

# This function retrieves from one of the config files under the control of kw
# and put it in the current directory. This operation can be dangerous since it
# will override the existing .config file; because of this, it has a warning
# message.
#
# @target File name of the target config file
# @force Force option. If it is set and the current name was already saved,
#        this option will override the '.config' file under the 'name'
#        specified by '-n' without any message.
#
# Returns:
# Exit with 0 if everything ends well, otherwise exit an errno code.
function get_config()
{
  local target=$1
  local force=$2
  local -r dot_configs_dir="$config_files_path/configs/configs"
  local -r msg="This operation will override the current .config file"

  # If we does not have a local config, there's no reason to warn the user
  if [[ -f $PWD/.config ]]; then
    force=1
  fi

  basic_config_validations $target $force "Get" $msg

  cp $dot_configs_dir/$target .config
  say "Current config file updated based on $target"
}

# Remove a config file under kw management
#
# @target File name of the target config file
# @force Force option.
#
# Returns:
# Exit 0 if everything ends well, otherwise exit an errno code.
function remove_config()
{
  local target=$1
  local force=$2
  local original_path=$PWD
  local -r dot_configs_dir="$config_files_path/configs"
  local -r msg="This operation will remove $target from kw management"

  basic_config_validations $target $force "Remove" $msg

  cd $dot_configs_dir
  git rm $configs_dir/$target $dot_configs_dir/$metadata_dir/$target > /dev/null 2>&1
  git commit -m "Removed $target config: $USER - $(date)" > /dev/null 2>&1
  cd $original_path

  say "The $target config file was removed from kw management"

  # Without config file, there's no reason to keep config directory
  if [ ! "$(ls $dot_configs_dir)" ]; then
    rm -rf /tmp/$configs_dir
    mv $dot_configs_dir /tmp
  fi
}

# TODO: Documentar
function fetch_config()
{
  local ip=$1
  local port=$2
  local optimize=$3
  local force=$4
  local -r msg="This operation will override the current .config file"

  # TODO: Alterar o basic_config_validations para ser util no fetch_config.
  # Note que copiei e colei o trecho abaixo
  # basic_config_validations "" $force "Fetch" $msg
  if [[ $force != 1 ]]; then
    warning $msg
    if [[ $(ask_yN "Are you sure that you want to proceed?") =~ "0" ]]; then
      complain "fetch operation aborted"
      exit 0
    fi
  fi

  . $src_script_path/remote.sh --source-only
  distro_info=$(which_distro "$ip" "$port" "root")
  distro=$(detect_distro "/" "$distro_info")

  . "$plugins_path/config_fetch/$distro.sh"
  get_config_from_remote $ip $port $optimize

  # TODO: TEM QUE VERIFICAR ANTES DE USAR, SENAO PODE USAR O LSMOD LOCAL
  if [[ "$optimize" == "1" ]]; then
    say "Kw is optimizing your config file, be patient"
    make olddefconfig
    make localmodconfig LSMOD=REMOTE_LSMOD
  fi
}

# This function handles the options available in 'configm'.
#
# @* This parameter expects a list of parameters, such as '-n', '-d', and '-f'.
#
# Returns:
# Return 0 if everything ends well, otherwise return an errno code.
function execute_config_manager()
{
  local name_config
  local description_config
  local force=0
  local optimize=0

  for arg do
    shift
    [[ "$arg" =~ ^-f$ ]] && force=1 && continue
    set -- "$@" "$arg"
  done

  case $1 in
    --save)
      shift # Skip '--save' option
      name_config=$1
      # Validate string name
      if [[ "$name_config" =~ ^- || -z "${name_config// }" ]]; then
        complain "Invalid argument"
        exit 22 # EINVAL
      fi
      # Shift name and get '-d'
      shift 2 && description_config=$@
      save_config_file $force $name_config "$description_config"
      ;;
    --ls)
      list_configs
      ;;
    --get)
      shift # Skip '--get' option
      if [[ -z "$1" ]]; then
        complain "Invalid argument"
        return 22 # EINVAL
      fi

      get_config $1 $force
      ;;
    --rm)
      shift # Skip '--rm' option
      if [[ -z "$1" ]]; then
        complain "Invalid argument"
        return 22 # EINVAL
      fi

      remove_config $1 $force
      ;;
# kw configm --fetch
# kw configm --fetch --optimize
# kw configm --fetch IP:PORT
# kw configm --fetch IP:PORT --optimize
    --fetch)
      shift # Remove '--fetch'

      for arg do
        shift
        [[ "$arg" =~ ^(--optimize|-f) ]] && optimize=1 && continue
        set -- "$@" "$arg"
      done

      if [[ ! -z "$@" ]]; then
        input="$@"
        # PARSER
        ip=$(get_from_colon "$input" 1)
        port=$(get_from_colon "$input" 2)
        if [[ "$port" == "$ip" ]]; then
          port="22"
        fi
      else
        ip=${configurations[ssh_ip]}
        port=${configurations[ssh_port]}
      fi

      fetch_config $ip $port $optimize $force
      # TODO
      # 1) Descobrir a distro
      # 2) Pegar o .config no local certo
      # 3) Se tiver otimizacao tmb pegar o lsmod
      # 4) Salvar localmente
      ;;
    *)
      complain "Unknown option"
      exit 22 #EINVAL
      ;;
  esac
}
