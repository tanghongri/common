#!/bin/sh
#脚本路径
readonly PROGDIR=$(readlink -m $(dirname $0))
#制作脚本版本
MP_VERSION=1.0.0.1
#是否加入授权
ISCHECK=1
#文件数量
FILECOUNT=2
#HEADER脚本行数
SKIP=0
#解包脚本位置
HEADER="$PROGDIR/header.sh"
#安装包文件名称
FILENAME=""
#目标包名称
TARNAME=""
#额外数据包名称
EXDATA=""
#配置文件路径
CONFIGPATH="/etc/csp/"
#校验程序名称
CHECKNAME="systool"
CHECKPATH="$PROGDIR/pre_install"
CHECKTEMPFILE="$PROGDIR/CheckTemp.dat"
#打包加密程序
PACKPATH="$PROGDIR/packtool"
#安装脚本名称
INSTALLNAME="install.sh"
#安装参数
INSTALL_ARGS=""
#临时文件路径
TEMPFILE="$PROGDIR/Temp.dat"
#许可协议
LICENSE=""
#文件大小，多个中间用空格隔开
FILESIZES=""
#空间大小（K），多个中间用空格隔开
USIZES=""
#md5列表，多个中间用空格隔开
MD5S=""
#压缩等级
COMPRESS_LEVEL=9
#压缩和解压缩命令
GZIP_CMD="gzip -c$COMPRESS_LEVEL"
GUNZIP_CMD="gzip -cd"
TAR_ARGS="cf"

###################帮助信息###################
Help()
{
  	echo "使用: $0"
    echo "参数配置: \$1 安装资源文件夹,\$2 目标包名,\$3 额外包路径"
    echo "可选参数可以下列参数组合:"
    echo "    --help|-h        : 帮助信息"
    echo "    --license|-l     : 软件许可协议(默认LICENSE.txt)"
	echo "    --install|-i     : 启动安装脚本名称(默认install.sh)"
	echo "    --check|-c	   : 是否添加授权检测"
	echo "    --args|-a	       : 添加执行参数"
    exit 1
}
###################处理可选参数###################
while true
do
	case "$1" in
	--help|-h)
	Help
		;;
	--license|-l)
		LICENSE=$(cat $2)
		if ! shift 2; then Help; exit 2; fi
		;;
	--install|-i)
		INSTALLNAME=$2
        if ! shift 2; then Help; exit 2; fi
        ;;
	--check|-c)
		ISCHECK=$2
        if ! shift 2; then Help; exit 2; fi
        ;;
	--args|-a)
		INSTALL_ARGS=$2
        if ! shift 2; then Help; exit 2; fi
        ;;
	-*)
	echo "未知参数 : $1"
		Help
		;;
   	*)
		break
		;;
    esac
done
###################参数判断###################
if test $# -lt 2
then
	Help	
fi
	
#参数数量检查
if test $ISCHECK -gt 0
then
	#校验程序
	if test ! -d "$CHECKPATH"
	then
		echo "WARNING: 校验程序 $CHECKPATH 不存在." >&2
		ISCHECK=0
	fi
	#打包程序
	if test ! -f "$PACKPATH"
	then
    	echo "WARNING: 打包程序 $PACKPATH 不存在." >&2
	fi
fi


#安装包资源文件夹
if test -d "$1"
then
	FILENAME="$1"
else
	echo "Error:资源文件夹 $1 不存在." >&2
	exit 3
fi

#目标包名称
TARNAME=$2
EXDATA=$3
#用户uid
if test $ISCHECK -gt 0
then
	FILECOUNT=2
else
	FILECOUNT=1
	CHECKNAME=""
fi

#LICENSE
if test "$LICENSE" = ""
then
	if test -f "$PROGDIR/LICENSE.txt"
	then
		LICENSE=$(cat "$PROGDIR/LICENSE.txt")
	else
		echo "WARNING: $PROGDIR/LICENSE.txt不存在." >&2
	fi
fi

#查找md5sum
MD5_PATH=`exec <&- 2>&-; command -v md5sum || which md5sum || type md5sum`
if test ! -x "$MD5_PATH"
then  		
    echo "MD5: 未找到 md5sum 命令"
	exit 5		
fi

#计算HEADER脚本行数
if test -f "$HEADER"
then
	OLDTARNAME="$TARNAME"
	TARNAME="$TEMPFILE"
	SKIP=0
	. "$HEADER"
	SKIP=`cat "$TEMPFILE" |wc -l`
	rm -f "$TEMPFILE"
	echo "Header 文件 $SKIP 行" >&2
	TARNAME="$OLDTARNAME"
else
	echo "打开 header 文件失败: $HEADER" >&2
	exit 6
fi

#
if test -f "$TARNAME"
then
   	echo "WARNING: 覆盖已存在包: $TARNAME" >&2
fi

MD5_CODE=00000000000000000000000000000000
##########################################################################处理校验程序
if test $ISCHECK -gt 0
then
	#空间
	USIZE=`du -ks "$CHECKPATH" | awk '{print $1}'`
	echo "安装文件: $CHECKPATH $USIZE KB"
	echo "开始压缩文件 $CHECKPATH"
	exec 3<> "$CHECKTEMPFILE"
	(cd "$CHECKPATH" && ( tar -$TAR_ARGS - . | eval "$GZIP_CMD" >&3 ) ) || { echo Aborting: 安装文件目录未找到或无法创建临时文件: "$CHECKTEMPFILE"; exec 3>&-; rm -f "$CHECKTEMPFILE"; exit 1; }
	exec 3>&- # try to close the archive
	#计算文件大小
	FSIZE=`wc -c "$CHECKTEMPFILE" | awk '{printf $1}'`
	#计算md5
	MD5_CODE=`eval "$MD5_PATH $CHECKTEMPFILE" | awk '{printf $1}'`
	echo "$CHECKPATH MD5: $MD5_CODE"	
	USIZES=$USIZE
	FILESIZES=$FSIZE;
	MD5S=$MD5_CODE	
	

	#空间
	USIZE=`du -ks "$FILENAME" | awk '{print $1}'`
	echo "安装文件: $FILENAME $USIZE KB"
	echo "开始压缩文件 $FILENAME"
	#打包程序
	$PACKPATH "$FILENAME" "$TEMPFILE" 
	#计算文件大小
	FSIZE=`wc -c "$TEMPFILE" | awk '{printf $1}'`
	#计算md5
	MD5_CODE=`eval "$MD5_PATH $TEMPFILE" | awk '{printf $1}'`
	echo "$FILENAME MD5: $MD5_CODE"	

	USIZES=`expr $USIZES + $USIZE`
	FILESIZES="$FILESIZES $FSIZE"
	MD5S="$MD5S $MD5_CODE"
else
##########################################################################处理安装包
	#空间
	USIZE=`du -ks "$FILENAME" | awk '{print $1}'`
	echo "安装文件: $FILENAME $USIZE KB"
	echo "开始压缩文件 $FILENAME"
	exec 3<> "$TEMPFILE"
	(cd "$FILENAME" && ( tar -$TAR_ARGS - . | eval "$GZIP_CMD" >&3 ) ) || { echo Aborting: 安装文件目录未找到或无法创建临时文件: "$TEMPFILE"; exec 3>&-; rm -f "$TEMPFILE"; exit 1; }
	exec 3>&- # try to close the archive
	#计算文件大小
	FSIZE=`wc -c "$TEMPFILE" | awk '{printf $1}'`
	#计算md5
	MD5_CODE=`eval "$MD5_PATH $TEMPFILE" | awk '{printf $1}'`
	echo "$FILENAME MD5: $MD5_CODE"	
	USIZES=$USIZE
	FILESIZES=$FSIZE;
	MD5S=$MD5_CODE	
fi

#添加数据压缩包
if test "x$EXDATA" != "x"
then
	USIZE=`du -ks "$EXDATA" | awk '{print $1}'`
	echo "额外数据文件: $EXDATA $USIZE KB"
	#计算文件大小
	FSIZE=`wc -c "$EXDATA" | awk '{printf $1}'`
	#计算md5
	MD5_CODE=`eval "$MD5_PATH $EXDATA" | awk '{printf $1}'`
	echo "$EXDATA MD5: $MD5_CODE"
	
	USIZES=`expr $USIZES + $USIZE`
	FILESIZES="$FILESIZES $FSIZE"
	MD5S="$MD5S $MD5_CODE"
	
	FILECOUNT=`expr $FILECOUNT + 1`
fi

#生成HEADER脚本
. "$HEADER"
#复制一份方便查看问题
cp $TARNAME $PROGDIR/InstallTemp.sh
#连接文件

if test $ISCHECK -gt 0
then
	echo "复制 $CHECKPATH"
	cat "$CHECKTEMPFILE" >> "$TARNAME"
fi

echo "复制 $FILENAME"
cat "$TEMPFILE" >> "$TARNAME"

if test "x$EXDATA" != "x"
then
	echo "复制 $EXDATA"
	cat "$EXDATA" >> "$TARNAME"
fi

chmod +x "$TARNAME"
rm -f "$TEMPFILE"
echo "安装包： \"$TARNAME\" 制作成功."


