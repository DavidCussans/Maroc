# This Repository is Stale. Go to https://github.com/uob-hep-cad/Maroc instead

# Maroc
Firmware and support scripts to read out pc043 5-Maroc board.

To setup Xilinx software environment (Vivado) on Bristol Linux PCs:
```
. /software/CAD/Xilinx/2019.2/Vivado/2019.2/settings64.sh
```

To build the firmware:

```
mkdir work
cd work
curl -L https://github.com/ipbus/ipbb/archive/v0.5.2.tar.gz | tar xvz
source ipbb-0.5.2/env.sh 
ipbb init build
cd build

ipbb add git https://github.com/ipbus/ipbus-firmware.git -b v1.6
ipbb add git git@github.com:ipbus-contrib/enclustra.git 
https://github.com/stnolting/neo430.git -b 0x0408
ipbb add git git@github.com:DavidCussans/Maroc.git

ipbb proj create vivado top_a35_pc043a Maroc:projects/pc043a_5maroc -t top_pc043a.dep 

cd proj/top_a35_pc043a
ipbb vivado project
ipbb vivado impl
ipbb vivado bitfile
ipbb vivado package
deactivate
```
