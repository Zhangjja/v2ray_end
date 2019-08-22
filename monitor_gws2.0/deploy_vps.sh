#!/bin/bash
key="API-Key: QYLPNWSVQW6KQSJD4ES3R3QDZXMJD3IXIK2A"
LABEL=""
if [ -z "$1" ]
then
	LABEL="default"
else
	LABEL="$1"
fi

SSHKEYID=`curl -H "$key" https://api.vultr.com/v1/sshkey/list |python -m json.tool |grep -E "\bSSHKEYID\b|\bname\b" | sed -n '/253/{x;p};h' | awk -F '"' '{print$4}'`

curl -H "$key" https://api.vultr.com/v1/server/create --data 'DCID=5' --data 'VPSPLANID=201' --data 'OSID=193' --data 'SSHKEYID=5cc15103d9f4d' --data "label=$LABEL" --data "SSHKEYID=$SSHKEYID" > subid.txt
cat subid.txt
echo "installing server......"

SUBID=`cat subid.txt | awk -F '"' '{print$4}'`
echo $SUBID

ip=""
while true
do
	ip=`curl -H "$key" https://api.vultr.com/v1/server/list?SUBID=$SUBID | python -m json.tool | grep -E "\bmain_ip\b"  |awk -F '"' '{print$4}'`
	if [ $ip == "0.0.0.0" ]
	then	
		echo $ip
		echo "getting ip......"
		sleep 5
		ip=`curl -H "$key" https://api.vultr.com/v1/server/list?SUBID=$SUBID | python -m json.tool | grep -E "\bmain_ip\b"  |awk -F '"' '{print$4}'`
	else
		echo $ip
		break
	fi
done


pwd=""
while true
do
	pwd=`curl -H "$key" https://api.vultr.com/v1/server/list?SUBID=$SUBID  | python -m json.tool | grep -E  "\bdefault_password\b" |awk -F '"' '{print$4}'`
	if [ -z $pwd ]
	then
		echo $pwd
		echo "getting pwd......"
		sleep 5
		pwd=`curl -H "$key" https://api.vultr.com/v1/server/list?SUBID=$SUBID  | python -m json.tool | grep -E  "\bdefault_password\b" |awk -F '"' '{print$4}'`
	else
		echo $pwd
		break
	fi
done

rm subid.txt

while true
do
	i=1
	ping -c 1 -W 2 $ip >/dev/null
	if [ $? -eq 0 ]
	then
		break
	else
		sleep 5
		i=$(expr $i + 1)
		echo "$i"
	fi
done

ping -c 2 -W 2 $ip >> /dev/null
if [ $? = 0 ]
then
	echo "ip地址存在！"
	echo "------------"
	echo "清理$ip 已经存在的密钥"
	ssh-keygen -f "/root/.ssh/known_hosts" -R $ip
	echo "$pwd"
	LOCALSSHKEY=`cat /root/.ssh/id_rsa.pub`
    sshpass -p $pwd ssh root@$ip "echo $LOCALSSHKEY >> /root/.ssh/authorized_keys"

	echo "正在添加密钥！"

	echo "v2ray_server安装ssh密钥"
	while true
	do
		ssh -o stricthostkeychecking=no root@$ip "ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa -q"
		if [ $? -eq 0 ]
			break
		then
			ssh -o stricthostkeychecking=no root@$ip "ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa -q"
		fi
	done
#    ssh-copy-id -i /root/.ssh/id_rsa.pub root@$ip
	echo "------------"
	echo "正在配置ansible主控端"

	jugde=`cat /etc/ansible/hosts | grep -E "\b$LABEL\b"| wc -l`
	if [ $jugde -gt 0 ]
	then
		echo "$LABEL 已存在"
		sed  -i "/$LABEL/{n;d}" /etc/ansible/hosts
		sed -i "/$LABEL/a$ip ansible_ssh_user=root" /etc/ansible/hosts
	else
		echo "$LABEL 不存在"
		sed -i "\$a\\[$LABEL\]" /etc/ansible/hosts
                sed -i "/$LABEL/a$ip ansible_ssh_user=root" /etc/ansible/hosts
	fi
	echo "主控端配置完毕！"
	echo "------------"
	echo "测试ansible被控端"
	ansible $LABEL -m ping
	command=`ansible $LABEL -m ping | grep "SUCCESS"|wc -l`
	if [ $command -gt 0 ]
	then
		echo "主控端配置成功！"
	else
		echo "主控端配置失败！"
		exit 1
	fi

	echo "开始安装v2ray服务端"
	#配置v2ray服务端脚本,使用ansible script模块路径为./v2ray_server_install.sh,开始安装v2ray服务端
#	ansible $vps -m script -a "./v2ray_server_install.sh"
#	ansible $vps -m copy -a "src=./server_config.json dest=/etc/v2ray/config.json owner=root group=root mode=0644"
#	echo "v2ray服务端安装完毕！"
#	echo "-------------------"
#	echo "开始配置v2ray服务端配置文件"
#	ip=`ansible $vps -m shell -a "ifconfig" | sed -n '3p'|awk '{print$2}'|awk -F ':' '{print$2}'`
#	echo "修改配置文件的ip，port，id"
#	port=`ansible $vps -m shell -a "cat /root/config.json.bak" |sed -n '4p'`
#	id=`ansible $vps -m shell -a "cat /root/config.json.bak" |sed -n '9p'`
#	ansible $vps -m shell -a "cat  /root/config.json.bak"
#	ansible $vps -m shell -a "cat  /etc/v2ray/config.json"
#	echo "$ip"  "$port"   "$id"
#	echo "正在修改-----------"
#	ansible $vps -m shell -a "sed -i '8i\\$port' /etc/v2ray/config.json"
#	ansible $vps -m shell -a "sed -i '9d' /etc/v2ray/config.json"
#	ansible $vps -m shell -a "sed -i '13i\\$id' /etc/v2ray/config.json"
#	ansible $vps -m shell -a "sed -i '14d' /etc/v2ray/config.json"
#	echo "修改完毕-----------"
#	echo "v2ray服务端配置成功!开始重启v2ray服务器"
#	ansible $vps -m shell -a "service v2ray restart"
#	echo "重启成功！"
#	echo "-------------------"
    echo `date +"%Y-%m-%d %H:%M:%S"` "-------------------"
    echo `date +"%Y-%m-%d %H:%M:%S"` "开始安装v2ray服务端,并且进行配置，使用ansible的fetch模块拷贝配置文件"
    ansible $LABEL -m script -a "./config/v2ray_server_install.sh"
    config_file=`ansible $LABEL -m  fetch -a 'dest=./ src=/etc/v2ray/config.json' | grep dest| awk -F'"' '{print$4}'`
    echo `date +"%Y-%m-%d %H:%M:%S"` "v2ray服务端安装完毕！"
    echo `date +"%Y-%m-%d %H:%M:%S"` "获取v2ray服务器的IP\PORT\ID"
    server_ip=`ansible $LABEL -m shell -a "ifconfig" | sed -n '3p'|awk '{print$2}'|awk -F ':' '{print$2}'`
    server_port=`cat $config_file |sed -n '4p'`
    server_id=`cat $config_file |sed -n '9p'`
    cat  $config_file
    cat  ./config/server_config.json
    echo `date +"%Y-%m-%d %H:%M:%S"` "$server_ip" "$server_port"  "$server_id"
    echo `date +"%Y-%m-%d %H:%M:%S"` "正在修改-----------------"
    sed -i '8i\\$server_port' ./config/server_config.json
    sed -i '9d' ./config/server_config.json
    sed -i '13i\\$server_id' ./config/server_config.json
    sed -i '14d' ./config/server_config.json
    ansible $LABEL -m copy -a "src=./config/server_config.json dest=/etc/v2ray/config.json owner=root group=root mode=0644"
    rm $config_file
    echo `date +"%Y-%m-%d %H:%M:%S"` "修改完毕，v2ray服务端配置成功!重启v2ray服务器"
    ansible $LABEL -m shell -a "service v2ray restart"
    echo `date +"%Y-%m-%d %H:%M:%S"` "v2ray服务重启成功！"
    echo `date +"%Y-%m-%d %H:%M:%S"` "-------------------"
else
	echo "ip error, please check"
	exit 1
fi
