cat << EOF  > "$TARNAME"
#!/bin/sh
# 脚本制作程序版本： $MP_VERSION

#文件数量
FILECOUNT=$FILECOUNT
#md5值
MD5S="$MD5S"
#文件大小
FILESIZES="$FILESIZES"
#额外数据包存放位置
EXDATA_PATH=""
#许可协议
licensetxt="$LICENSE"
#缓存文件夹
TEMPDIR="\$(dirname \$(readlink -f \$0))/CSPTemp"
#配置文件路径
CONFIGPATH="$CONFIGPATH"
#校验程序名称
CHECKNAME="$CHECKNAME"
#安装脚本名称
INSTALLNAME="$INSTALLNAME"
#安装参数
INSTALL_ARGS=$INSTALL_ARGS
#md5sum路径
MD5_PATH=""
#HEADER脚本大小
SKIP=0
#退出清理
OUTCLEAN=true

#许可协议
PrintLicense()
{
  	if test x"\$licensetxt" != x; then
   		echo "\$licensetxt"
    	while true
   		do
			echo "请输入 yes 接受, no 退出安装: "
      		read yn
      		if test x"\$yn" = xno; then
        		exit -1
       	 		break;
      		elif test x"\$yn" = xyes; then
        		break;
      		fi
    	done
  	fi
}

#检查文件数量
checkFileCount()
{
	md5array=(\$MD5S)
	if test \${#md5array[@]} -ne \$FILECOUNT
	then
		echo "MD5S数量错误: \$FILECOUNT, \$MD5S"
		exit -1
	fi

	md5array=(\$FILESIZES)
	if test \${#md5array[@]} -ne \$FILECOUNT
	then
		echo "FILESIZES数量错误: \$FILECOUNT, \$FILESIZES"
		exit -1
	fi
}

#空间
diskspace()
{	
	df -kP "\$1" | tail -1 | awk '{ if (\$4 ~ /%/) {print \$3} else {print \$4} }'
}

#dd进度条
dd_Progress()
{
	file="\$1"
	ddoffset=\$2
	length=\$3
	pos=0
	bsize=4194304
	while test \$bsize -gt \$length
 	do
		bsize=\`expr \$bsize / 4\`
	done
	blocks=\`expr \$length / \$bsize\`
	bytes=\`expr \$length % \$bsize\`
	(
		dd ibs=\$ddoffset skip=1 count=0 2>/dev/null
		pos=\`expr \$pos + \$bsize\`
		printf "     0%% " 1>&2
		if test \$blocks -gt 0 
		then
			while test \$pos -le \$length 
			do
				dd bs=\$bsize count=1 2>/dev/null
				pcent=\`expr \$length / 100\`
				pcent=\`expr \$pos / \$pcent\`
				if test \$pcent -lt 100; then
					printf "\b\b\b\b\b\b\b" 1>&2
					if test \$pcent -lt 10; then
						printf "    \$pcent%% " 1>&2
					else
						printf "   \$pcent%% " 1>&2
					fi
				fi
				pos=\`expr \$pos + \$bsize\`
			done
		fi
		if test \$bytes -gt 0; then
			dd bs=\$bytes count=1 2>/dev/null
		fi
		printf "\b\b\b\b\b\b\b" 1>&2
		printf " 100%%  \n" 1>&2
	) < "\$file"
}

#检查文件
CheckMD5()
{
	echo "开始校验MD5......"
	OFFSET=\$2
	Index=1
	for filesize in \$FILESIZES
	do	
	
		md5=\`echo \$MD5S | cut -d" " -f\$Index\`
		if test x"\$md5" = x00000000000000000000000000000000; then
			echo " \$1 无MD5校验信息." >&2
		else
			md5sum=\`dd_Progress "\$1" \$OFFSET \$filesize | eval "\$MD5_PATH \$MD5_ARG" | cut -b-32\`;
			if test x"\$md5sum" != x"\$md5" 
			then
				echo "MD5 校验失败::\$Index \$md5sum  与 \$md5 不同" >&2
				eval \$OUTCLEAN;exit -1
			else
				echo "文件\$Index MD5 校验成功." >&2
			fi
		fi
		
		Index=\`expr \$Index + 1\`
		OFFSET=\`expr \$OFFSET + \$filesize\`
	done
	echo "所有文件MD5校验成功."  
}

#命令开始
if [ \`id -u\` -ne 0 ]
then
   echo "[ERROR]:Must run as root"
   exit 1
fi
#
if test "\$1" = "-f"
then
	if test "\$2" = ""
	then
		echo "参数错误:-f file"
		exit -1
	fi
	if test ! -f \$2
	then
		echo "配置文件不存在:\$2"
		exit -1
	fi
elif test "\$1" != "-u" -a "\$INSTALL_ARGS" != "-u"
then
	PrintLicense
fi

if test -d \$TEMPDIR 
then
	rm -fr \$TEMPDIR 
fi
mkdir \$TEMPDIR || {
    	echo '创建临时文件夹失败： \$TEMPDIR >&2' 
    	exit -1
}
OUTCLEAN="\$OUTCLEAN ;/bin/rm -rf \$TEMPDIR"

#检查文件数量
checkFileCount

#检查md5环境
#查找md5sum
MD5_PATH=\`exec <&- 2>&-; which md5sum || command -v md5sum || type md5sum\`
if test ! -x "\$MD5_PATH"; then  		
    echo "MD5: 未找到 md5sum 命令"
	eval \$OUTCLEAN;exit -1		
fi
#
trap "echo "捕捉到信号，退出清理！" >&2; eval \$OUTCLEAN; exit 15" 1 2 3 15
#HEADER脚本大小
SKIP=\`head -n $SKIP "\$0" | wc -c | tr -d " "\`
#校验md5
CheckMD5 "\$0" "\$SKIP"

#检测空间
leftspace=\`diskspace \$TEMPDIR\`
if test -n "\$leftspace"; then
	if test "\$leftspace" -lt $USIZES; then
		echo "目录没有足够的空间可用： "\`dirname \$TEMPDIR\`" (\$leftspace KB)来释放 \$0 ($USIZES KB)" >&2
		eval \$OUTCLEAN;exit -1
	fi
fi
#分割文件
Index=1
OFFSET=\$SKIP

for filesize in \$FILESIZES	
do
	if test "x\$EXDATA_PATH" != "x"
	then
		echo "解压额外数据中......" 1>&2
		dd_Progress "\$0" \$OFFSET \$filesize |tar -zxpf - -C \$EXDATA_PATH  >/dev/null 2>&1 
		break
	fi
	mkdir -p \$TEMPDIR/\$Index
	if test \$Index -eq 2 -a "x\$CHECKNAME" != "x"
	then	
		echo "解压安装包中......" 1>&2
		eval "/etc/csp/\$CHECKNAME -p \$0 \$OFFSET \$TEMPDIR/\$Index";res=\$?;
		if test "\$res" -ne 0 
		then
			echo "解密安装包返回错误代码 (\$res)" >&2
			exit -1
		fi
		
	else 
		echo "解压安装程序中......" 1>&2
		dd_Progress "\$0" \$OFFSET \$filesize | eval "$GUNZIP_CMD" |tar -xpf - -C \$TEMPDIR/\$Index >/dev/null 2>&1 
		#修改用户组
		#(cd "\$tmpdir/\$Index"; chown -R \`id -u\` .;  chgrp -R \`id -g\` .)
	fi
	
	#执行安装脚本
	if test x"\$INSTALLNAME" != x
	then   
		chmod +x "\$TEMPDIR/\$Index/\$INSTALLNAME"
		eval "\$TEMPDIR/\$Index/\$INSTALLNAME \$INSTALL_ARGS \$@";res=\$?;
		if test "\$res" -ne 0 
		then
			echo "安装脚本 '\$INSTALLNAME' 返回错误代码 (\$res)" >&2
			exit -1
		fi
	fi
		
	
	#最后一部分为额外数据包跳出
	if test -f "\$TEMPDIR/\$Index/EXDATA_PATH"
	then
		EXDATA_PATH=\`cat \$TEMPDIR/\$Index/EXDATA_PATH \`
	fi
	OFFSET=\`expr \$OFFSET + \$filesize\`
	Index=\`expr \$Index + 1\`
done


echo "****************************************"
echo "*************** 安装成功 ***************"
echo "****************************************"
eval \$OUTCLEAN;
exit 0
EOF
