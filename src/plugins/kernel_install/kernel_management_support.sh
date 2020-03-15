function list_installed_kernels()
{
  local option="$1"
  local output
  local ret
  local super=0
  local available_kernels=()
  local prefix="$2"
  local grub_cfg=""

  grub_cfg="$prefix/boot/grub/grub.cfg"

  output=$(awk -F\' '/menuentry / {print $2}' "$grub_cfg")

  if [[ "$?" != 0 ]]; then
    if ! [[ -r "$grub_cfg" ]] ; then
      echo "For showing the available kernel in your system we have to take" \
           "a look at '/boot/grub/grub.cfg', however, it looks like that" \
           "that you have no read permission."
      if [[ $(ask_yN "Do you want to proceed with sudo?") =~ "0" ]]; then
        echo "List kernel operation aborted"
        return 0
      fi
      super=1
    fi
  fi

  if [[ "$super" == 1 ]]; then
    output=$(sudo awk -F\' '/menuentry / {print $2}' "$grub_cfg")
  fi

  output=$(echo "$output" | grep recovery -v | grep with |  awk -F" "  '{print $NF}')

  while read kernel
  do
    if [[ -f "$prefix/boot/vmlinuz-$kernel" ]]; then
       available_kernels+=( "$kernel" )
    fi
  done <<< "$output"

  echo

  if [[ -z "$option" ]]; then
    printf '%s\n' "${available_kernels[@]}"
    return 0
  fi

  case "$option" in
    --single-line)
      echo -n ${available_kernels[0]}
      available_kernels=("${available_kernels[@]:1}")
      printf ',%s' "${available_kernels[@]}"
      echo ""
      ;;
    *)
      echo "Invalid option "$option""
      return 22 # EINVAL
      ;;
  esac
}

