```bash
ulimit -n # Check the current file descriptor limit
# Read the current value of net.core.somaxconn
sysctl net.core.somaxconn
# Read the current value of net.core.wmem_max
sysctl net.core.wmem_max
# Set net.core.somaxconn to 4096 (temporary until next reboot)
sudo sysctl -w net.core.somaxconn=4096
# Set net.core.wmem_max to 4194304 (4MB) (temporary until next reboot)
sudo sysctl -w net.core.wmem_max=4194304
# Make the changes permanent by adding them to sysctl configuration file: /etc/sysctl.conf
# Alternatively, create a new file in /etc/sysctl.d/ directory (ex: /etc/sysctl.d/99-network.conf)
echo "net.core.somaxconn=4096" | sudo tee -a /etc/sysctl.d/99-network.conf
echo "net.core.wmem_max=4194304" | sudo tee -a /etc/sysctl.d/99-network.conf
# Apply changes from sysctl configuration files
sysctl -p
```
