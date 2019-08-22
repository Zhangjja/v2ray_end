#!/bin/bash

#2019-4-15
#author zhangjunjie
echo "一键更新局域网的网关和DNS服务"
key="API-Key: QYLPNWSVQW6KQSJD4ES3R3QDZXMJD3IXIK2A"

GW_DNS="$1"
echo "您输入的GW_DNS分组为"$GW_DNS",正在验证GW_DNS分组是否存在,请稍后..."
count1=`ansible "$GW_DNS" -m ping|grep SUCCESS|wc -l`
if [ $count1 -gt 0 ]
then
	echo "验证成功GW_DNS分组存在！分组名为"$GW_DNS""
else
	echo "GW_DNS分组不存在，请重新输入......"
	exit 1
fi

LABEL="$2"
echo "您输入的LABEL分组为$LABEL,正在验证LABEL分组是否存在,请稍后..."
count2=`ansible $LABEL -m ping|grep SUCCESS|wc -l`
if [ $count2 -gt 0 ]
then
	echo "验证成功LABEL分组存在！分组名为$LABEL"
else
        echo "LABEL分组不存在，请重新输入......"
	exit 1
fi

#获取v2ray服务端的IP，PORT，ID
server_address=`ansible $LABEL -m shell -a "ifconfig" | sed -n '3p'|awk '{print$2}'|awk -F ':' '{print$2}'`
echo "v2ray_server的IP是$server_address"
server_port=`ansible $LABEL -m shell -a "cat /etc/v2ray/config.json" | grep port | sed -n '1p'`
echo "$server_port"
server_id=`ansible $LABEL -m shell -a "cat /etc/v2ray/config.json" | grep id`
echo "$server_id"

echo `date +"%Y-%m-%d %H:%M:%S"` "下一步需要修改$gw 组的配置文件，现在正在形成参数"
echo `date +"%Y-%m-%d %H:%M:%S"` "修改gw的配置文件/etc/v2ray/config.json,/opt/v2ray-firewall"
echo `date +"%Y-%m-%d %H:%M:%S"` "1.拼接ip地址"
address="                \"address\"":"\"$server_ip\"",""
echo `date +"%Y-%m-%d %H:%M:%S"` $address
echo `date +"%Y-%m-%d %H:%M:%S"` "2.拼接端口号"
port="            "$server_port
echo `date +"%Y-%m-%d %H:%M:%S"` $server_port
echo `date +"%Y-%m-%d %H:%M:%S"` "3.拼接id"
id="          "$server_id
echo `date +"%Y-%m-%d %H:%M:%S"` $id

echo `date +"%Y-%m-%d %H:%M:%S"` "执行修改局域网GW的配置文件"
echo `date +"%Y-%m-%d %H:%M:%S"` "配置ip地址"
sed -i '13i\\$address' ./config/client_config.json
sed -i '14d' ./config/client_config.json

echo `date +"%Y-%m-%d %H:%M:%S"` "配置端口"
sed -i '14i\\$port' ./config/client_config.json
sed -i '15d' ./config/client_config.json

echo `date +"%Y-%m-%d %H:%M:%S"` "配置id"
sed -i '17i\\$id' ./config/client_config.json
sed -i '18d' ./config/client_config.json
ansible $gw -m copy -a "src=./config/client_config.json dest=/etc/v2ray/config.json owner=root group=root mode=0644"
echo `date +"%Y-%m-%d %H:%M:%S"` "配置防火墙"
echo `date +"%Y-%m-%d %H:%M:%S"` "1.拼接防火墙"
fire_wall="iptables -t nat -A V2RAY -d  $server_address -j RETURN"
echo `date +"%Y-%m-%d %H:%M:%S"` $fire_wall
sed -i '14i\\$fire_wall' ./config/v2ray-firewall
sed -i '15d' ./config/v2ray-firewall
ansible $gw -m copy -a "src=./config/v2ray-firewall dest=/opt/v2ray-firewall owner=root group=root mode=0644"

echo `date +"%Y-%m-%d %H:%M:%S"` "重启gw的v2ray、keepalived服务"
ansible "$gw" -m shell -a "reboot"
echo `date +"%Y-%m-%d %H:%M:%S"` "配置完毕！ 服务重启成功！"
