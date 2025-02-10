#!/data/data/com.termux/files/usr/bin/bash
set -e

# 配置颜色输出
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

# 输入验证函数
validate_username() {
  if [[ ! "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    echo -e "${RED}错误：用户名不符合Linux命名规则！${RESET}"
    echo "- 只能包含小写字母、数字、连字符(-)和下划线(_)"
    echo "- 首字符必须是小写字母或下划线"
    echo "- 长度1-32字符"
    return 1
  fi
  return 0
}

validate_password() {
  if [ -z "$1" ]; then
    echo -e "${RED}错误：密码不能为空！${RESET}"
    return 1
  fi
  return 0
}

# 用户输入部分
echo -e "${GREEN}>>> 用户配置 ${RESET}"
while : 
do
  read -p "请输入Debian用户名（默认debianuser）: " DEB_USER
  DEB_USER=${DEB_USER:-debianuser}
  validate_username "$DEB_USER" && break
done

read -p "请输入用户全名（可留空）: " FULL_NAME

while :
do
  read -sp "请输入用户密码: " DEB_PASS
  echo
  read -sp "请再次确认密码: " DEB_PASS_CONFIRM
  echo
  if [ "$DEB_PASS" != "$DEB_PASS_CONFIRM" ]; then
    echo -e "${RED}两次输入的密码不一致！${RESET}"
  else
    validate_password "$DEB_PASS" && break
  fi
done

# 状态显示函数
status() { echo -e "${BLUE}[*] $1${RESET}"; }
success() { echo -e "${GREEN}[√] $1${RESET}"; }
error() { echo -e "${RED}[X] $1${RESET}" >&2; exit 1; }

# 检查Termux环境
if [ ! -d "/data/data/com.termux/files/usr" ]; then
  error "必须在 Termux 环境中运行！"
fi

# 阶段1: 安装必要组件
status "正在配置Termux环境..."
{
  pkg update -y
  pkg install x11-repo -y
  pkg install termux-x11-nightly -y
  pkg install pulseaudio -y
  pkg install proot-distro -y
} || error "组件安装失败"

# 阶段2: 安装Debian容器
status "正在安装Debian容器..."
{
  proot-distro install debian || {
    echo -e "${YELLOW}检测到可能存在的现有安装，尝试强制安装...${RESET}"
    proot-distro reset debian
    proot-distro install debian
  }
} || error "Debian安装失败"

# 阶段3: 容器基础配置
status "正在配置Debian容器..."
proot-distro login debian -- /bin/bash <<EOF
set -e

# 配置镜像源
echo -e "${YELLOW}配置阿里云镜像源...${RESET}"
cat > /etc/apt/sources.list <<'MIRROR'
deb https://mirrors.aliyun.com/debian bookworm main contrib non-free non-free-firmware
deb-src https://mirrors.aliyun.com/debian bookworm main contrib non-free non-free-firmware
deb https://mirrors.aliyun.com/debian bookworm-updates main contrib non-free non-free-firmware
deb-src https://mirrors.aliyun.com/debian bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.aliyun.com/debian bookworm-backports main contrib non-free non-free-firmware
deb-src https://mirrors.aliyun.com/debian bookworm-backports main contrib non-free non-free-firmware
deb https://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src https://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
MIRROR

# 更新软件源
echo -e "${YELLOW}更新软件源...${RESET}"
apt update && apt upgrade -y

# 安装基础软件
echo -e "${YELLOW}安装必要组件...${RESET}"
apt install -y nano adduser sudo locales

# 创建用户
echo -e "${YELLOW}创建用户 $DEB_USER...${RESET}"
if [ -z "$FULL_NAME" ]; then
  adduser --gecos "" --disabled-password $DEB_USER
else
  adduser --gecos "$FULL_NAME" --disabled-password $DEB_USER
fi
echo "$DEB_USER:$DEB_PASS" | chpasswd

# 配置sudo权限
echo -e "${YELLOW}配置sudo权限...${RESET}"
usermod -aG sudo $DEB_USER
echo "$DEB_USER ALL=(ALL:ALL) ALL" >> /etc/sudoers

# 中文环境配置
echo -e "${YELLOW}配置中文支持...${RESET}"
echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen zh_CN.UTF-8
update-locale LANG=zh_CN.UTF-8

# 安装中文字体
echo -e "${YELLOW}安装中文字体...${RESET}"
apt install -y fonts-wqy-microhei fonts-wqy-zenhei xfonts-wqy

# 时区配置
echo -e "${YELLOW}配置时区...${RESET}"
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 安装桌面环境
echo -e "${YELLOW}安装Xfce4...${RESET}"
apt install -y xfce4 dbus-x11

# 清理缓存
echo -e "${YELLOW}清理安装缓存...${RESET}"
apt autoremove -y
apt clean
EOF

# 阶段4: 创建启动脚本
status "创建启动脚本..."
cat > $PREFIX/bin/startxfce <<EOF
#!/data/data/com.termux/files/usr/bin/bash

# 清理已有进程
pkill -9 termux-x11 || true
rm -rf /data/data/com.termux/files/usr/tmp/*pulse*

# 启动音频服务
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

# 准备X11环境
export XDG_RUNTIME_DIR=\${TMPDIR}
termux-x11 :0 >/dev/null &

# 等待X11启动
sleep 1

# 启动X11应用
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1

# 进入容器启动桌面
proot-distro login debian --shared-tmp -- /bin/bash -c \\
  'export PULSE_SERVER=127.0.0.1 && \\
   export XDG_RUNTIME_DIR=\${TMPDIR} && \\
   su - $DEB_USER -c "env DISPLAY=:0 dbus-launch --exit-with-session startxfce4"' &>/dev/null &

# 清理临时文件并退出
sleep 1
rm -rf \$TMPDIR/pulse-* && exit &>/dev/null &
exit 0
EOF

chmod +x $PREFIX/bin/startxfce

# 最终输出
success "安装完成！"
echo -e "${GREEN}使用以下命令启动桌面："
echo -e "startxfce${RESET}"

# 作者信息
echo -e "\n${YELLOW}==================================================="
echo -e "感谢使用本安装脚本！"
echo -e "脚本作者：纆泽"
echo -e "B站UID: 321858860"
echo -e "QQ：834080913"
echo -e "模拟器交流群：962180826"
echo -e "GitHub发布页："
echo -e "https://github.com/moze30?tab=repositories"
echo -e "===================================================${RESET}\n"
