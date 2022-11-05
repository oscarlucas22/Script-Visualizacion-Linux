#!/bin/bash

# Crea una imagen nueva, que utilice bullseye-base.qcow2 como imagen base y tenga 5 GiB de tamaño máximo. Esta imagen se denominará maquina1.qcow2.
echo "-----------------------------------------------------"
echo "Creando la imagen de maquina1..."
echo "-----------------------------------------------------"
qemu-img create -f qcow2 -b bullseye-base-sparsify.qcow2 maquina1.qcow2 5G &> /dev/null 
cp maquina1.qcow2 newmaquina1.qcow2 &> /dev/null
virt-resize --expand /dev/sda1 maquina1.qcow2 newmaquina1.qcow2 &> /dev/null
mv newmaquina1.qcow2 maquina1.qcow2 &> /dev/null
sleep 5s

# Crea una red interna de nombre intra con salida al exterior mediante NAT que utilice el direccionamiento 10.10.20.0/24.
echo "-----------------------------------------------------"
echo "Creando la red intra..."
echo "-----------------------------------------------------"
virsh -c qemu:///system net-define intra.xml &> /dev/null
virsh -c qemu:///system net-start intra &> /dev/null
virsh -c qemu:///system net-autostart intra &> /dev/null
sleep 5s

# Crea una máquina virtual (maquina1) conectada a la red intra, con 1 GiB de RAM, que utilice como disco raíz maquina1.qcow2 y que se inicie automáticamente. Arranca la máquina. Modifica el fichero /etc/hostname con maquina1.
echo "-----------------------------------------------------"
echo "Creando la maquina virtual maquina1..."
echo "-----------------------------------------------------"
virt-install --connect qemu:///system \
             --name maquina1 \
             --ram 1024 \
             --vcpus 1 \
             --disk path=maquina1.qcow2 \
             --network network=intra \
             --os-type linux \
             --os-variant debian10 \
             --import \
             --noautoconsole &> /dev/null
sleep 5s
echo "-----------------------------------------------------"
echo "Arrancando la maquina..."
echo "-----------------------------------------------------"
virsh -c qemu:///system start maquina1 &> /dev/null
sleep 20s
echo "-----------------------------------------------------"
echo "Modificando el fichero /etc/hostname..."
echo "-----------------------------------------------------"
ip=$(virsh -c qemu:///system domifaddr maquina1 | grep -oP '10.10.20.\d{1,3}')
ssh -i id_ecdsa debian@$ip -o "StrictHostKeyChecking no" "sudo -- bash -c 'echo 'maquina1' > /etc/hostname'" &> /dev/null
sleep 5s

# Crea un volumen adicional de 1 GiB de tamaño en formato RAW ubicado en el pool por defecto
echo "-----------------------------------------------------"
echo "Creando un volumen de 1GiB..."
echo "-----------------------------------------------------"
virsh -c qemu:///system vol-create-as default vol01 1G --format raw &> /dev/null
sleep 5s

# Una vez iniciada la MV maquina1, conecta el volumen a la máquina, crea un sistema de ficheros XFS en el volumen y móntalo en el directorio /var/www/html. Ten cuidado con los propietarios y grupos que pongas, para que funcione adecuadamente el siguiente punto.
echo "-----------------------------------------------------"
echo "Conectando el volumen a la maquina..."
echo "-----------------------------------------------------"
virsh -c qemu:///system attach-disk maquina1 /var/lib/libvirt/images/vol01 vdb --targetbus virtio --persistent &> /dev/null
sleep 5s
echo "-----------------------------------------------------"
echo "Creando sistema de ficheros XFS en vol01 y montandolo en /var/www/html..."
echo "-----------------------------------------------------"
ssh -i id_ecdsa debian@$ip "sudo -- bash -c '/usr/sbin/mkfs.xfs -f /dev/vdb && mkdir -p /var/www/html && mount /dev/vdb /var/www/html'" &> /dev/null
sleep 5s
echo "-----------------------------------------------------"
echo "Configurando los procedimientos..."
echo "-----------------------------------------------------"
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'echo "/dev/vdb /var/www/html xfs defaults 0 0" >> /etc/fstab'" &> /dev/null
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'chown -R www-data:www-data /var/www/html'" &> /dev/null
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'chmod -R 755 /var/www/html'" &> /dev/null
sleep 5s

# Instala en maquina1 el servidor web apache2. Copia un fichero index.html a la máquina virtual.
echo "-----------------------------------------------------"
echo "Instalando servidor web apache2 en maquina1..."
echo "-----------------------------------------------------"
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'apt update'" &> /dev/null
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'apt install apache2 -y'" &> /dev/null
sleep 5s

echo "-----------------------------------------------------"
echo "Creando fichero index.html en maquina1..."
echo "-----------------------------------------------------"
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'echo "Hello World!" > index.html'" &> /dev/null
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'mv index.html /var/www/html/'" &> /dev/null
sleep 5s

echo "-----------------------------------------------------"
echo "Reseteando servicio de apache2..."
echo "-----------------------------------------------------"
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'systemctl restart apache2'" &> /dev/null
sleep 5s

# Muestra por pantalla la dirección ip de máquina1. Pausa el script y comprueba que puedes acceder a la página web.
echo "-----------------------------------------------------"
echo "Obteniendo la Ip de maquina1..."
echo "-----------------------------------------------------"
sleep 3s
echo "Ip Obtenida -->" $ip
sleep 5s
clear
echo "-----------------------------------------------------"
echo "Hacemos una pausa en el script para acceder a la página web"
echo "-----------------------------------------------------"
echo "Introduce http://$ip en el navegador para acceder a la página web"
echo ""
read -p "Pulsa ENTER para continuar"

# Instala LXC y crea un linux container llamado container1.
echo "-----------------------------------------------------"
echo "Instalando LXC..."
echo "-----------------------------------------------------"
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'apt install lxc -y'" &> /dev/null
sleep 5s
echo "-----------------------------------------------------"
echo "Creando linux container..."
echo "-----------------------------------------------------"
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'lxc-create -n container1 -t debian -- -r bullseye'" &> /dev/null
sleep 5s

# Añade una nueva interfaz a la máquina virtual para conectarla a la red pública (al punte br0).
echo "-----------------------------------------------------"
echo "Añadiendo una nueva interfaz a maquina1..."
echo "-----------------------------------------------------"
virsh -c qemu:///system shutdown maquina1 &> /dev/null
sleep 3s 
virsh -c qemu:///system attach-interface maquina1 bridge br0 --model virtio --config &> /dev/null
sleep 5s
virsh -c qemu:///system start maquina1 &> /dev/null
sleep 20s

# Muestra la nueva ip que ha recibido.
echo "-----------------------------------------------------"
echo "Obteniendo la nueva Ip que ha optenido..."
echo "-----------------------------------------------------"
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'chmod 646 /etc/network/interfaces'"
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'echo " " >> /etc/network/interfaces'"
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'echo "auto enp8s0" >> /etc/network/interfaces'"
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'echo "iface enp8s0 inet dhcp" >> /etc/network/interfaces'"
ssh -i id_ecdsa debian@$ip "sudo -- bash -c 'systemctl restart networking'"
br0=$(ssh -i id_ecdsa debian@$ip "ip a | grep 'enp8s0' | grep -oP 'inet \K[\d.]+'")
sleep 5s
echo "Ip Obtenida -->" $br0 

# Apaga maquina1 y auméntale la RAM a 2 GiB y vuelve a iniciar la máquina.
echo "-----------------------------------------------------"
echo "Apagando maquina1..."
echo "-----------------------------------------------------"
virsh -c qemu:///system shutdown maquina1 &> /dev/null
sleep 5s
echo "-----------------------------------------------------"
echo "Incrementando el tamaño de la RAM a 2 GiB..."
echo "-----------------------------------------------------" 
virsh -c qemu:///system setmaxmem maquina1 2G --config && virsh -c qemu:///system setmem maquina1 2G --config &> /dev/null
sleep 5s
echo "-----------------------------------------------------"
echo "Iniciando maquina1..."
echo "-----------------------------------------------------"
virsh -c qemu:///system start maquina1 &> /dev/null
sleep 20s

# Crea un snapshot de la máquina virtual.
echo "-----------------------------------------------------"
echo "Apagando maquina1..."
echo "-----------------------------------------------------"
virsh -c qemu:///system shutdown maquina1 &> /dev/null
sleep 5s
echo "-----------------------------------------------------"
echo "Creando snapshot de maquina1..."
echo "-----------------------------------------------------"
virsh -c qemu:///system snapshot-create-as maquina1 --name snapshot1 --disk-only --atomic
