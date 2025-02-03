# termux-debian
用于在termux上使用proot容器安装Linux发行版debian的流程，包括了升级kali linux的步骤
# 注意事项
请检查是否已经给予termux储存权限，如果没有请输入以下命令并回车，不起作用请手动给予

    termux-setup-storage

# 首先更换termux的包源
输入命令回车后找到中国的镜像源进行更换

    termux-change-repo
    pkg update
    pkg install git -y

# 安装x11与声音组件的依赖

    pkg update -y
    pkg install x11-repo -y
    pkg install termux-x11-nightly -y
    pkg install pulseaudio -y
    
# 安装proot容器后下载debian并登录

    pkg install proot-distro -y
    proot-distro install debian
    proot-distro login debian

# 配置debian

    apt update
    apt install nano adduser -y
    apt install sudo

添加普通用户（此处的用户名是以我自己的习惯配置，可根据你自己的喜好更改用户名，但是要保证后面的流程中用户名的一致）

    adduser moze

创建密码，输入两次确认，接着创建用户名，我会只创建用户名纆泽，然后一直回车，其他的信息可留空，如果有提升字符问题，不必理会，输入y确认

    nano /etc/sudoers
    moze ALL=(ALL:ALL) ALL

Ctrl+o Ctrl+x

# 切换用户检查权限是否配置正确

    su - moze
    sudo whoami

# 安装桌面环境（此处选择xfce4）

    sudo apt install xfce4

# 配置中文环境

    sudo apt install locales
    sudo dpkg-reconfigure locales

选择314，再选择3

    sudo apt install fonts-wqy-microhei fonts-wqy-zenhei xfonts-wqy

# 配置启动桌面环境命令

在termux中输入以下命令添加软连接方便访问usr

    ln -s /data/user/0/com.termux/files/usr/ /data/user/0/com.termux/files/home/usr
进入指定文件夹

    cd usr/bin

创建启动脚本

    nano startx11

把这段脚本粘贴进去（脚本中也有对应用户名，请注意更改）
    #!/data/data/com.termux/files/usr/bin/bash
    rm -rf /data/data/com.termux/files/usr/tmp/*pulse*
    pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

    export XDG_RUNTIME_DIR=${TMPDIR}
    termux-x11 :0 >/dev/null &

    sleep 1
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1

    proot-distro login debian --shared-tmp -- /bin/bash -c  'export PULSE_SERVER=127.0.0.1 && export XDG_RUNTIME_DIR=${TMPDIR} && su - moze -c "env DISPLAY=:0 startxfce4"' &>/dev/null &
    sleep 1
    rm -rf $TMPDIR/pulse-* && exit &>/dev/null &

    exit 0

Ctrl+o Ctrl+x

给予权限

    chmod +x startx11

然后输入startx11即可进入桌面
# 升级kali linux具体步骤
kali linux是基于debian的发行版，所以在termux的proot容器中，我们可以直接让debian升级到kali

先添加kali的中国镜像源（方案一）

    nano /etc/apt/sources.list

在底下添加

    deb http://mirrors.aliyun.com/kali kali-rolling main non-free contrib
    deb-src http://mirrors.aliyun.com/kali kali-rolling main non-free contrib

Ctrl+o Ctrl+x
添加密钥

    sudo apt install gnupg
    sudo gpg --keyserver keyserver.ubuntu.com --recv-keys ED444FF07D8D0BF6
    sudo gpg --export --armor ED444FF07D8D0BF6 | sudo tee /etc/apt/trusted.gpg.d/kali-archive-keyring.asc

中国镜像源（方案二）

    deb [trusted=yes] https://mirrors.ustc.edu.cn/kali kali-rolling main non-free contrib



更新包源并升级

    sudo apt update
    sudo apt full-upgrade

等待下载解压完毕即可升级完成

查看系统发行版本

    lsb_release -a

# 注意
如果说在刚开始配置容器更新包源的时候更新速度比较慢，实在受不了的建议更换debian的国内镜像源

    apt update
    apt install nano
    nano /etc/apt/sources.list

把原来的官方源全部#掉，添加以下源

    deb https://mirrors.aliyun.com/debian/ bookworm main non-free non-free-firmware contrib
    deb-src https://mirrors.aliyun.com/debian/ bookworm main non-free non-free-firmware contrib
    deb https://mirrors.aliyun.com/debian-security/ bookworm-security main
    deb-src https://mirrors.aliyun.com/debian-security/ bookworm-security main
    deb https://mirrors.aliyun.com/debian/ bookworm-updates main non-free non-free-firmware contrib
    deb-src https://mirrors.aliyun.com/debian/ bookworm-updates main non-free non-free-firmware contrib
    deb https://mirrors.aliyun.com/debian/ bookworm-backports main non-free non-free-firmware contrib
    deb-src https://mirrors.aliyun.com/debian/ bookworm-backports main non-free non-free-firmware contrib

Ctrl+o Ctrl+x

更新包源

    apt update

# 如果又黑屏问题请安装此依赖

    apt install dbus-x11
