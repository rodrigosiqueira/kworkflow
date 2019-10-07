function get_config_from_remote()
{
    ip=$1
    port=$2
    optimize=$3
    user=$4

    user=${user:-"root"}

    scp -P $port $user@$ip:/boot/config-5.0.0-27-generic .config

    if [[ "$optimize" == "1"  ]]; then
      ssh -p $port $user@$ip 'lsmod' > REMOTE_LSMOD
    fi
}
