set +e
sudo -E make INSTALL_PATH=${configurations[mount_point]}/boot
release=$(make kernelrelease)
