# NOTES:
# https://github.com/PHOENIX-MEDIA/vagrant-k3s/blob/master/scripts/install-services.sh
# https://dev.to/mattdark/a-custom-vagrant-box-with-packer-13ke
# https://www.suse.com/support/kb/doc/?id=000020082
# https://docs.rancherdesktop.io/how-to-guides/setup-NGINX-Ingress-Controller/
# https://dev.to/mattdark/building-immutable-infrastructure-with-packer-and-gitlab-ci-5105
# https://codingpackets.com/blog/self-hosted-vagrant-cloud/
# https://github.com/hollodotme/Helpers/blob/master/Tutorials/vagrant/self-hosted-vagrant-boxes-with-versioning.md

# Author: S. Teodorani

cd /tmp

# Install base packages
echo "*** Install requirements"
ufw disable
apt-get update 
apt-get -y upgrade
apt-get -y install curl wget
apt-get -y install dkms build-essential linux-headers-`uname -r`
apt-get -y install libxt6 libxmu6
apt-get -y install nfs-kernel-server
apt-get -y install net-tools

# Enable net.bridge
# echo "*** Configure VM"
# tee -a /etc/sysctl.d/99-kubernetes.conf <<EOF
# net.bridge.bridge-nf-call-iptables  = 1
# net.ipv4.ip_forward                 = 1
# net.bridge.bridge-nf-call-ip6tables = 1
# EOF

# Applica le modifiche
# sysctl --system

# Add google dns
echo "*** Add google dns server"
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Install k3s
echo "*** Install k3s"
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="600" INSTALL_K3S_EXEC="server --disable traefik --disable servicelb" INSTALL_K3S_VERSION="v1.25.9+k3s1" sh -s - || (journalctl -xe && exit 1)

sleep 30s
kubectl get nodes -o wide
kubectl get pods -A

# Install k9s
# curl -sS https://webinstall.dev/k9s | bash
echo "*** Install k9s"
wget https://github.com/derailed/k9s/releases/download/v0.27.4/k9s_Linux_amd64.tar.gz
tar xvf k9s_Linux_amd64.tar.gz
chmod 7777 ./k9s
mv ./k9s /usr/local/bin/
sleep 10s

# Setup cluster access for root user
echo "*** Setup cluster access for root user @see https://rancher.com/docs/k3s/latest/en/cluster-access/"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
grep -q KUBECONFIG /root/.profile || echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /root/.profile
#chown vagrant:vagrant /etc/rancher/k3s/k3s.yaml

# Setup cluster access for vagrant user
echo "*** Setup cluster access for vagrant user @see https://rancher.com/docs/k3s/latest/en/cluster-access/"
echo "alias k9s='k9s --logFile /home/vagrant/.k9s-vagrant.log'" >> /home/vagrant/.profile
grep -q KUBECONFIG /home/vagrant/.profile || echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /home/vagrant/.profile
chown vagrant:vagrant /etc/rancher/k3s/k3s.yaml
chown vagrant:vagrant /home/vagrant/.profile

# Install Helm
echo "*** Install HELM3"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh
sleep 4s

### Add the helm repos
echo "*** Add the helm repos"
helm repo add stable https://charts.helm.sh/stable
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
helm repo update
chown -R  vagrant:vagrant /home/vagrant/.config/helm/
chown -R  vagrant:vagrant /home/vagrant/.cache/helm

# Configure NFS
mkdir -p /data
chown nobody:nogroup /data
echo "/data    *(rw,sync,no_subtree_check)" >> /etc/exports
systemctl restart nfs-kernel-server
IP=$(hostname -I | awk '{print $1}')
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=$IP \
    --set nfs.path=/data

# Install nginx controller
echo "Install nginx ingress without load balancer by using host port binds"
helm install nginx ingress-nginx/ingress-nginx --namespace kube-system --set rbac.create=true,controller.hostNetwork=true,controller.dnsPolicy=ClusterFirstWithHostNet,controller.kind=DaemonSet,controller.ingressClass=nginx,controller.ingressClassResource.default=true

echo "*** DONE"

