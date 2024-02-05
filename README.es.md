# PiChAK

Raspberry Pi con ClusterHat administrado con Ansible para trabajar con Kubernetes.

## Hardware

- [Raspberry Pi 4 B (2 Go de RAM)](https://www.elektor.fr/raspberry-pi-4-b-2-gb-ram)
- [Official EU Power Supply for Raspberry Pi 4 (black)](https://www.elektor.fr/official-eu-power-supply-for-raspberry-pi-4-black)
- [Carte MicroSD Kingston SDC10/32GB X 2](https://www.kubii.fr/carte-sd-et-stockage/3344-carte-microsd-kingston-sdc1032gb-x-2-0740617298888.html)
- [Kit Cluster Hat + 4 Pi Zero + 4 SDCards](https://www.kubii.fr/cartes-extension-cameras-raspberry-pi/2112-kit-cluster-hat-4-pi-zero-kubii-3272496009943.html)
- [4-Piece Raspberry Pi 4 Heatsink Set](https://thepihut.com/products/4-piece-raspberry-pi-4-heatsink-set)
- [Miniature 5V Cooling Fan for Raspberry Pi](https://thepihut.com/products/miniature-5v-cooling-fan-for-raspberry-pi-and-other-computers)
- [Cluster HAT Case v3.0](https://thepihut.com/products/cluster-hat-case)

### Montado

Segui los pasos de la [gia de montado de la carcasa](https://thepihut.com/blogs/raspberry-pi-tutorials/cluster-hat-case-assembly-guide), el paso 3; agregue los disipadores de calor al RaspberryPi y el ventilador al panel frontal, pare incluirlo en los siguientes paso de montado ya que esta muy justo como para ponerlo despues.

## Software

- Cualquier distribución de linux.
- Ansible

### Instalación

#### Etapa 1 - Preparacion de SD

1. Descargar la imagen [CBRIDGE - Lite Controller](https://dist.8086.net/clusterctrl/buster/2020-12-02/2020-12-02-1-ClusterCTRL-armhf-lite-CBRIDGE.zip)
2. Descargar el [usbboot](https://dist2.8086.net/clusterctrl/usbboot/buster/2020-12-02/2020-12-02-1-ClusterCTRL-armhf-lite-usbboot.tar.xz)
3. Instalar la imagen en la SD
4. Redimensionar la SD para tener mas espacio libre
5. Montar el OS de la SD
6. Instalar y configurar los USB boots
7. Autorizar ssh
8. Agregar el inicio de los RPiZero

```bash
$ sudo bash ./create_sd.sh
```

#### Etapa 2 - Primer inicialización de Pi

1. Insertar la SD creada en el paso anterior en la RP4
2. Conectela la RP4 a la corriente
3. Esperar 5 minutos
4. Desconectar la RP4 de la corriente
5. Conectela la RP4 a la corriente

Esto permite que el script de ClusterHAT incialise lo necesario para el NetBoot y permita iniciar las RPZ.

#### Etapa 3 - Cargar K3s

**_REQUISITO:_** RaspberryPi 4 ejecutando a SD preparada

1. Instalar requerimientos
2. Obtener las IPs del cluster
3. Actualizacion de OS's
4. Instalacion de K3s v1.19.3+k3s3 [1]

[1]: https://github.com/k3s-io/k3s/issues/2699 "Ultima version soportada por Raspberry Pi Zero 1.3"

```bash
$ sudo bash ./shipyard.sh
```

#### Etapa 4 - Validate service status

```bash
$ ansible -i ./piHatAnsible/hosts.ini all -m shell -a "systemctl status k3s*"
```

## Referencias

- [Raspberry Pi ORG](https://www.raspberrypi.org/)
- [Raspberry Pi](https://www.raspberrypi.com/)
- [Cluster CTRL](https://clusterctrl.com/)
- [Ansible](https://www.ansible.com/)
- [Kubernetes](https://kubernetes.io/es/)
- [k3s](https://k3s.io/)

### Comandos

```bash
$ ansible -i ./piHatAnsible/hosts.ini all -m ping
$ ansible -i ./piHatAnsible/hosts.ini all -m shell -a "vcgencmd measure_temp"
```
