#!/bin/bash

#2019-4-15
#author zhangjunjie
echo `date +"%Y-%m-%d %H:%M:%S"` "一键更新局域网的网关和DNS服务"
key="API-Key: QYLPNWSVQW6KQSJD4ES3R3QDZXMJD3IXIK2A"

GW_DNS="$1"
echo `date +"%Y-%m-%d %H:%M:%S"` "您输入的GW_DNS分组为"$GW_DNS",正在验证GW_DNS分组是否存在,请稍后..."
count1=`ansible "$GW_DNS" -m ping|grep SUCCESS|wc -l`
if [ $count1 -gt 0 ]
then
	echo `date +"%Y-%m-%d %H:%M:%S"` "验证成功GW_DNS分组存在！分组名为"$GW_DNS""
else
	echo `date +"%Y-%m-%d %H:%M:%S"` "GW_DNS分组不存在，请重新输入......"
	exit 1
fi

LABEL="$2"

if [ -z "$2" ]
then
	LABEL="default"
else
	LABEL="$2"
fi
echo `date +"%Y-%m-%d %H:%M:%S"` "您输入的LABEL分组为$LABEL,正在验证LABEL分组是否存在,请稍后..."
count2=`ansible $LABEL -m ping|grep SUCCESS|wc -l`
if [ $count2 -gt 0 ]
then
	echo `date +"%Y-%m-%d %H:%M:%S"` "验证成功LABEL分组存在！分组名为$LABEL"
else
        echo `date +"%Y-%m-%d %H:%M:%S"` "LABEL分组不存在，请重新输入......"
	exit 1
fi

#获取v2ray服务端的IP，PORT，ID
server_address=`ansible $LABEL -m shell -a "ifconfig" | sed -n '3p'|awk '{print$2}'|awk -F ':' '{print$2}'`
echo `date +"%Y-%m-%d %H:%M:%S"` "v2ray_server的IP是$server_address"
server_port=`ansible $LABEL -m shell -a "cat /etc/v2ray/config.json" | grep port | sed -n '1p'`
echo `date +"%Y-%m-%d %H:%M:%S"` "$server_port"
server_id=`ansible $LABEL -m shell -a "cat /etc/v2ray/config.json" | grep id`
echo `date +"%Y-%m-%d %H:%M:%S"` "$server_id"

echo `date +"%Y-%m-%d %H:%M:%S"` "下一步需要修改gw和dns组的配置文件，现在正在形成参数"
echo `date +"%Y-%m-%d %H:%M:%S"` "修改gw的配置文件/etc/v2ray/config.json,/opt/v2ray-firewall"
echo `date +"%Y-%m-%d %H:%M:%S"` "1.拼接ip地址"
address="                \"address\"":"\"$server_address\"",""
echo `date +"%Y-%m-%d %H:%M:%S"` $address
echo `date +"%Y-%m-%d %H:%M:%S"` "2.拼接端口号"
port="            "$server_port
echo `date +"%Y-%m-%d %H:%M:%S"` $port
echo `date +"%Y-%m-%d %H:%M:%S"` "3.拼接id"
id="          "$server_id
echo `date +"%Y-%m-%d %H:%M:%S"` $id

echo `date +"%Y-%m-%d %H:%M:%S"` "执行修改局域网GW或DNS的配置文件"
echo `date +"%Y-%m-%d %H:%M:%S"` "配置ip地址"
ansible "$GW_DNS" -m shell -a "sed -i '13i\\$address' /etc/v2ray/config.json"
ansible "$GW_DNS" -m shell -a "sed -i '14d' /etc/v2ray/config.json"

echo `date +"%Y-%m-%d %H:%M:%S"` "配置端口"
ansible "$GW_DNS" -m shell -a "sed -i '14i\\$port' /etc/v2ray/config.json"
ansible "$GW_DNS" -m shell -a "sed -i '15d' /etc/v2ray/config.json"

echo `date +"%Y-%m-%d %H:%M:%S"` "配置id"
ansible "$GW_DNS" -m shell -a "sed -i '17i\\$id' /etc/v2ray/config.json"
ansible "$GW_DNS" -m shell -a "sed -i '18d' /etc/v2ray/config.json"

echo `date +"%Y-%m-%d %H:%M:%S"` "配置防火墙"
echo `date +"%Y-%m-%d %H:%M:%S"` "1.拼接防火墙"
fire_wall="iptables -t nat -A V2RAY -d  $server_address -j RETURN"
echo `date +"%Y-%m-%d %H:%M:%S"` $fire_wall
ansible "$GW_DNS" -m shell -a "sed -i '14i\\$fire_wall' /opt/v2ray-firewall"
ansible "$GW_DNS" -m shell -a "sed -i '15d' /opt/v2ray-firewall"

echo `date +"%Y-%m-%d %H:%M:%S"` "重启GW_DNS的v2ray服务"
ansible "$GW_DNS" -m shell -a "reboot"
echo `date +"%Y-%m-%d %H:%M:%S"` "服务重启成功！"
echo `date +"%Y-%m-%d %H:%M:%S"` "配置完毕！"
