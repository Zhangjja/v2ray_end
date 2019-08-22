#!/bin/bash
key="API-Key: QYLPNWSVQW6KQSJD4ES3R3QDZXMJD3IXIK2A"
LABEL=""
if [ -z "$1" ]
then
	LABEL="default"
else
	LABEL="$1"
fi

SSHKEYID=`curl -H "$key" https://api.vultr.com/v1/sshkey/list |python -m json.tool |grep -E "\bSSHKEYID\b|\bname\b" | sed -n '/252/{x;p};h' | awk -F '"' '{print$4}'`

#curl -H "$key" https://api.vultr.com/v1/server/create --data 'DCID=25' --data 'VPSPLANID=201' --data 'OSID=193' --data 'SSHKEYID=5cc15103d9f4d' --data "label=$LABEL" --data "SSHKEYID=$SSHKEYID" > subid.txt
cat subid.txt
echo `date +"%Y-%m-%d %H:%M:%S"` "installing server......"

#SUBID=`cat subid.txt | awk -F '"' '{print$4}'`
SUBID="27873033"
echo `date +"%Y-%m-%d %H:%M:%S"` $SUBID

sleep 24
ip=""
while true
do
	ip=`curl -H "$key" https://api.vultr.com/v1/server/list?SUBID=$SUBID | python -m json.tool | grep -E "\bmain_ip\b"  |awk -F '"' '{print$4}'`
	if [ $ip == "0.0.0.0" ]
	then
		echo `date +"%Y-%m-%d %H:%M:%S"` "getting ip......		sleep 20"
		sleep 24
	else
		echo `date +"%Y-%m-%d %H:%M:%S"` $ip
		break
	fi
done


pwd=""
while true
do
	pwd=`curl -H "$key" https://api.vultr.com/v1/server/list?SUBID=$SUBID  | python -m json.tool | grep -E  "\bdefault_password\b" |awk -F '"' '{print$4}'`
	if [ -z $pwd ]
	then
		echo `date +"%Y-%m-%d %H:%M:%S"` "getting pwd......		sleep 20"
		sleep 60
	else
		echo `date +"%Y-%m-%d %H:%M:%S"` $pwd
		break
	fi
done

rm subid.txt

sleep 30
while true
do
    ping -c 2 -W 15  $ip >> /dev/null
    if [ $? = 0 ]
    then
        echo `date +"%Y-%m-%d %H:%M:%S"` "ip地址存在！"
        echo `date +"%Y-%m-%d %H:%M:%S"` "清理$ip 已经存在的密钥"
        ssh-keygen -f "/root/.ssh/known_hosts" -R $ip
        LOCALSSHKEY=`cat /root/.ssh/id_rsa.pub`
        sshpass -p $pwd ssh root@$ip "echo  $LOCALSSHKEY >> /root/.ssh/authorized_keys"

        echo `date +"%Y-%m-%d %H:%M:%S"` "正在添加密钥！"

        echo `date +"%Y-%m-%d %H:%M:%S"` "v2ray_server安装ssh密钥"
        while true
        do
            ssh -o stricthostkeychecking=no root@$ip "ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa -q"
            if [ $? -eq 0 ]
                break
            then
                ssh -o stricthostkeychecking=no root@$ip "ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa -q"
            fi
        done

        echo `date +"%Y-%m-%d %H:%M:%S"` "------------"
        echo `date +"%Y-%m-%d %H:%M:%S"` "正在配置ansible主控端"

        jugde=`cat /etc/ansible/hosts | grep -E "\b$LABEL\b"| wc -l`
        if [ $jugde -gt 0 ]
        then
            echo `date +"%Y-%m-%d %H:%M:%S"` "$LABEL 已存在"
            sed  -i "/$LABEL/{n;d}" /etc/ansible/hosts
            sed -i "/$LABEL/a$ip ansible_ssh_user=root ansible_sudo_pass=$pwd" /etc/ansible/hosts
        else
            echo `date +"%Y-%m-%d %H:%M:%S"` "$LABEL 不存在"
            sed -i "\$a\\[$LABEL\]" /etc/ansible/hosts
                    sed -i "/$LABEL/a$ip ansible_ssh_user=root ansible_sudo_pass=$pwd" /etc/ansible/hosts
        fi
        echo `date +"%Y-%m-%d %H:%M:%S"` "主控端配置完毕！"
        echo `date +"%Y-%m-%d %H:%M:%S"` "------------"
        echo `date +"%Y-%m-%d %H:%M:%S"` "测试ansible被控端"
        ansible $LABEL -m ping
        command=`ansible $LABEL -m ping | grep "SUCCESS"|wc -l`
        if [ $command -gt 0 ]
        then
            echo `date +"%Y-%m-%d %H:%M:%S"` "主控端配置成功！"
        else
            echo `date +"%Y-%m-%d %H:%M:%S"` "主控端配置失败！"
            exit 1
        fi

        echo `date +"%Y-%m-%d %H:%M:%S"` "开始安装v2ray服务端"
        #配置v2ray服务端脚本,使用ansible script模块路径为./v2ray_server_install.sh,开始安装v2ray服务端
        ansible $LABEL -m script -a "./v2ray_server_install.sh"
        ansible $LABEL -m copy -a "src=./server_config.json dest=/etc/v2ray/config.json owner=root group=root mode=0644"
        echo `date +"%Y-%m-%d %H:%M:%S"` "v2ray服务端安装完毕！"
        echo `date +"%Y-%m-%d %H:%M:%S"` "-------------------"
        echo `date +"%Y-%m-%d %H:%M:%S"` "开始配置v2ray服务端配置文件"
        ip=`ansible $LABEL -m shell -a "ifconfig" | sed -n '3p'|awk '{print$2}'|awk -F ':' '{print$2}'`
        echo `date +"%Y-%m-%d %H:%M:%S"` "修改配置文件的ip，port，id"
        port=`ansible $LABEL -m shell -a "cat /root/config.json.bak" |sed -n '4p'`
        id=`ansible $LABEL -m shell -a "cat /root/config.json.bak" |sed -n '9p'`
        ansible $LABEL -m shell -a "cat  /root/config.json.bak"
        ansible $LABEL -m shell -a "cat  /etc/v2ray/config.json"
        echo `date +"%Y-%m-%d %H:%M:%S"` "$ip"  "$port"   "$id"
        echo `date +"%Y-%m-%d %H:%M:%S"` "正在修改-----------"
        ansible $LABEL -m shell -a "sed -i '8i\\$port' /etc/v2ray/config.json"
        ansible $LABEL -m shell -a "sed -i '9d' /etc/v2ray/config.json"
        ansible $LABEL -m shell -a "sed -i '13i\\$id' /etc/v2ray/config.json"
        ansible $LABEL -m shell -a "sed -i '14d' /etc/v2ray/config.json"
        echo `date +"%Y-%m-%d %H:%M:%S"` "修改完毕-----------"
        echo `date +"%Y-%m-%d %H:%M:%S"` "v2ray服务端配置成功!开始重启v2ray服务器"
        ansible $LABEL -m shell -a "service v2ray restart"
        echo `date +"%Y-%m-%d %H:%M:%S"` "重启成功！"
        echo `date +"%Y-%m-%d %H:%M:%S"` "-------------------"
	break
    else
        echo `date +"%Y-%m-%d %H:%M:%S"` "连接超时，重新安装服务器"
        curl -H "$key" https://api.vultr.com/v1/server/reinstall --data "SUBID=$SUBID"
    fi
done
