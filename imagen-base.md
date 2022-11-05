### Crea con virt-install una imagen de Debian Bullseye con formato qcow2 y un tamaño máximo de 3GiB. Esta imagen se denominará bullseye-base.qcow2. El sistema de ficheros del sistema instalado en esta imagen será XFS. La imagen debe estará configurada para poder usar hasta dos interfaces de red por dhcp. El usuario debian con contraseña debian puede utilizar sudo sin contraseña

virt-install --connect qemu:///system \
                         --virt-type kvm \
                         --name bullseye-base \
                         --ram 1024 \
                         --vcpus 1 \
                         --disk path=/var/lib/libvirt/images/bullseye-base.qcow2,size=3 \
                         --os-type linux \
                         --os-variant debian10 \
                         --network network=default \
                         --network network=default \
                         --location /home/oscar/Descargas/isos/debian-11.0.0-amd64-netinst.iso

### Crea un par de claves ssh en formato ecdsa y sin frase de paso y agrega la clave pública al usuario debian

ssh-keygen -t ecdsa -b 521

### Utiliza la herramienta virt-sparsify para reducir al máximo el tamaño de la imagen.

sudo virt-sparsify --compress /var/lib/libvirt/images/bullseye-base.qcow2 /var/lib/libvirt/images/bullseye-base-sparsify.qcow2