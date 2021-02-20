#!/bin/bash

# Update hosts file
echo "[TASK 1] Update /etc/hosts file"
cat >>/etc/hosts<<EOF
172.10.10.100 master.home.lab master
172.10.10.101 node1.home.lab node1
172.10.10.102 node2.home.lab node2
172.10.10.103 node3.home.lab node3
EOF

echo "[TASK 2] Install docker container engine"
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm
dnf install -y docker-ce

# add account to the docker group and configure driver to use systemd
usermod -aG docker vagrant
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Enable docker service
echo "[TASK 3] Enable and start docker service"
mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload
systemctl enable --now docker >/dev/null 2>&1

# Add sysctl settings
echo "[TASK 4] Add sysctl settings"
modprobe br_netfilter
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system >/dev/null 2>&1

# Disable swap
echo "[TASK 5] Disable and turn off SWAP"
sed -i '/swap/d' /etc/fstab
swapoff -a

# Disable SELinux
echo "[TASK 6] Disable and turn off SELinux"
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

# Add kubernetes sources list 
echo "[TASK 7] Add Kubernetes Repo"
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

ls -ltr /etc/yum.repos.d/kubernetes.repo

dnf update -y

# Install Kubernetes
echo "[TASK 8] Install Kubernetes kubeadm, kubelet and kubectl"
dnf install -y kubelet kubeadm kubectl --nobest --allowerasing

# Start and Enable kubelet service
echo "[TASK 9] Enable and start kubelet service"
systemctl enable --now kubelet >/dev/null 2>&1

# Enable ssh password authentication for copy files between master and nodes
echo "[TASK 10] Enable ssh password authentication"
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd

# Set Root password
echo "[TASK 11] Set root password"
echo -e "kubeadmin\nkubeadmin" | passwd root

# Update vagrant user's bashrc file
echo "export TERM=xterm" >> /etc/bashrc
