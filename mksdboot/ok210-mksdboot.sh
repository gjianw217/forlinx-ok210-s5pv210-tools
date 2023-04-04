#! /bin/sh
#I.MX6 SD卡启动系统烧写脚本


#Uboot默认值
bl1='ok210.bin'
bl2='u-boot.bin'
#execute执行语句成功与否打印
execute ()
{
    $* >/dev/null
    if [ $? -ne 0 ]; then
        echo
        echo "错误: 执行 $*"
        echo
        exit 1
    fi
}





#测试制卡包当前目录下是否缺失制卡所需要的文件
device=$1

#判断选择的块设备是否存在及是否是一个块设备
if [ -z $device  ]; then
  echo "错误: please assige $device "
  exit 1
fi

#判断选择的块设备是否存在及是否是一个块设备
if [ ! -e $device  ]; then
  echo "错误: $device 不存在"
  exit 1
fi

#判断选择的块设备是否存在及是否是一个块设备
if [ ! -b $device ]; then
  echo "错误: $device 不是一个块设备文件"
  exit 1
fi

#这里防止选错设备，否则会影响Ubuntu系统的启动
if [ $device = '/dev/sda' ];then
  echo "请不要选择sda设备，/dev/sda通常是您的Ubuntu硬盘!
继续操作你的系统将会受到影响！脚本已自动退出"
  exit 1 
fi


####################################################
sdkdir=$PWD

if [ ! -d $sdkdir ]; then
   echo "错误: $sdkdir目录不存在"
   exit 1
fi

if [ ! -f $sdkdir/rootfs/*.tar.* ]; then
  echo "错误: $sdkdir/filesystem/下找不到文件系统压缩包"
  exit 1
fi

if [ ! -f $sdkdir/kernel/uImage ]; then
  echo "错误: $sdkdir/kernel/下找不到uImage"
  exit 1
fi

if [ ! -f $sdkdir/kernel/*.dtb ]; then
  echo "错误: $sdkdir/kernel/下找不到设备树"
  exit 1
fi

if [ ! -f $sdkdir/uboot/$bl1 ]; then
  echo "错误: $sdkdir/uboot/下找不到$bl1"
  exit 1
fi
if [ ! -f $sdkdir/uboot/$bl2 ]; then
  echo "错误: $sdkdir/uboot/下找不到$bl2"
  exit 1
fi


echo "即将进行制作SD系统启动卡，大约花费几分钟时间,请耐心等待!"
echo "************************************************************"
echo "*         注意：这将会清除$device所有的数据               *"
echo "*         在脚本执行时请不要将$device拔出                 *"
echo "*             请按<Enter>确认继续                          *"
echo "************************************************************"
read enter
####################################################
#格式化前要卸载
for i in `ls -1 $device?`; do
 echo "卸载 device '$i'"
 umount $i 2>/dev/null
done

#执行格式化$device
execute "dd if=/dev/zero of=$device bs=1024 count=1024"

####################################################
#第一个分区为64M用来存放设备树与内核镜像文件，因为设备树与内核都比较小，不需要太大的空间
#第二个分区为SD卡的总大小-64M，用来存放文件系统
cat << END | fdisk -H 255 -S 63 $device
n
p
1

+64M
n
p
2


t
1
c
a
1
w
END
####################################################
#两个分区处理
PARTITION1=${device}1
if [ ! -b ${PARTITION1} ]; then
        PARTITION1=${device}1
fi

PARTITION2=${device}2
if [ ! -b ${PARTITION2} ]; then
        PARTITION2=${device}2
fi
####################################################
#第一个分区创建为Fat32格式
echo "格式化 ${device}1 ..."
if [ -b ${PARTITION1} ]; then
	mkfs.vfat -F 32 -n "boot" ${PARTITION1}
else
	echo "错误: /dev下找不到 SD卡 boot分区"
fi
#第二个分区创建为ext3格式
echo "格式化${device}2 ..."
if [ -b ${PARITION2} ]; then
	mkfs.ext3 -F -L "rootfs" ${PARTITION2}
else
	echo "错误: /dev下找不到 SD卡 rootfs分区"
fi
####################################################
while [ ! -e $device ]
do
sleep 1
echo "wait for $device appear"
done
####################################################
echo "正在烧写${bl1},${bl2}到${device}"
#execute "dd if=$sdkdir/uboot/$Uboot of=$device seek=1 conv=fsync"
execute "dd iflag=dsync oflag=dsync if=$sdkdir/uboot/$bl1 of=$device seek=1"
execute "dd iflag=dsync oflag=dsync if=$sdkdir/uboot/$bl2 of=$device seek=49"
#sudo dd iflag=dsync oflag=dsync if=ok210.bin of=/dev/sdb seek=1
#sudo dd iflag=dsync oflag=dsync if=u-boot.bin of=/dev/sdb seek=49

sync
echo "烧写${bl1},${bl2}到${device}完成！"

####################################################
echo "正在复制设备树与内核到${device}1，请稍候..."
execute "mkdir -p /tmp/boot/$$"
execute "mount ${device}1 /tmp/boot/$$"
execute "cp -r $sdkdir/kernel/*.dtb /tmp/boot/$$/"
execute "cp -r $sdkdir/kernel/uImage /tmp/boot/$$/"
#execute "cp $sdkdir/boot/alientek.bmp /tmp/sdk/$$/"
sync
echo "复制设备树与内核到${device}1完成！"
echo "卸载${device}1"
execute "umount /tmp/boot/$$"
execute "rm -rf /tmp/boot/$$"
sleep 1

####################################################
#解压文件系统到文件系统分区
#挂载文件系统分区
execute "mkdir -p /tmp/rootfs/$$"
execute "mount ${device}2 /tmp/rootfs/$$"

echo "正在解压文件系统到${device}2 ，请稍候..."
rootfs=`ls -1 rootfs/*.tar.*`
execute "tar jxfm $rootfs -C /tmp/rootfs/$$"
sync
echo "解压文件系统到${device}2完成！"

echo "卸载${device}2"
execute "umount /tmp/rootfs/$$"
execute "rm -rf /tmp/rootfs/$$"
sync
####################################################
echo "SD卡启动系统烧写完成！"



