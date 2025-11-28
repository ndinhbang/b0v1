# Development Environment Setup

This guide describes how to set up the development environment using **WSL2 + Debian 12**.

---

## 1. Mise Installation (Development Tools Manager)

- Official docs: [Getting Started](https://mise.jdx.dev/getting-started.html), [Walkthrough](https://mise.jdx.dev/walkthrough.html)

```bash
sudo apt update -y && sudo apt install -y curl
sudo install -dm 755 /etc/apt/keyrings
curl -fSs https://mise.jdx.dev/gpg-key.pub | sudo tee /etc/apt/keyrings/mise-archive-keyring.pub 1> /dev/null
echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.pub arch=amd64] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list
sudo apt update
sudo apt install -y mise

# Activate mise
echo 'eval "$(mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

# Verify installation
mise doctor

# List configuration files
mise config ls
```

---

## 2. Install PHP and Composer

```bash
# Install PHP and Composer
mise use -g ubi:adwinying/php@8.4
mise use -g ubi:composer/composer

# Rename composer.phar to composer for easier usage
cd $(mise where ubi:composer/composer)
mv composer.phar composer
```

---

## 3. Docker Installation (Inside WSL2)

- Reference: [How to install Docker in WSL without Docker Desktop](https://daniel.es/blog/how-to-install-docker-in-wsl-without-docker-desktop/)

```bash
# Remove existing Docker versions
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc | cut -f1)

# Add Docker's official GPG key
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository to Apt sources
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update -y

# Install Docker Engine, CLI, and Containerd
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to the Docker group
sudo usermod -aG docker $USER
```
