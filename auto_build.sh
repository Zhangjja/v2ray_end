#!/usr/bin/env bash
#/bin/bash
#date 2019-4-30
#author zjj
#describe 监控vlutr的使用率，达到50G时候自动重新搭建服务器，销毁老服务器，建立新服务器
key="API-Key: QYLPNWSVQW6KQSJD4ES3R3QDZXMJD3IXIK2A"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "                                                                              "
gws=("gw" "ggww" "dns")
echo "                                                                              "
for gw in ${gws[@]}
do
    echo `date +"%Y-%m-%d %H:%M:%S"` "检测的网关名为$gw"
    MONITOR_IP=`ansible $gw -m shell -a 'cat /etc/v2ray/config.json' | grep "address"|sed -n '1p' |awk -F '"' '{print$4}'`
    echo `date +"%Y-%m-%d %H:%M:%S"` "获取的v2ray服务器IP地址为$MONITOR_IP"

    echo `date +"%Y-%m-%d %H:%M:%S"` "收集vultr的服务器列表"
    curl -H "$key" https://api.vultr.com/v1/server/list | python -m json.tool | grep  -E "\blabel\b|\bSUBID\b|\bmain_ip\b|\bDCID\b" |awk '{print$1 $2}' > serverlist.log
    if [ $? -gt 0 ]
    then
        echo `date +"%Y-%m-%d %H:%M:%S"`  "$gw 与vultr连接失败，调用API失败"
    else
        echo `date +"%Y-%m-%d %H:%M:%S"`  "$gw 调用API成功，开始执行监控程序"
        MONITOR_SUBID=`cat serverlist.log | grep -E "\bSUBID\b|\bmain_ip\b" | sed -n "/$MONITOR_IP/{x;p};h" | awk -F '"' '{print$4}'`
        echo `date +"%Y-%m-%d %H:%M:%S"` "获取的v2ray服务器subid为 $MONITOR_SUBID"
       
  	    DCID=`cat serverlist.log | grep -E "\bDCID\b|\bSUBID\b" | sed -n "/$MONITOR_SUBID/{x;p};h" | awk -F '"' '{print$4}'`
        echo `date +"%Y-%m-%d %H:%M:%S"` "获取的v2ray服务器DCID为 $DCID"

        LABEL=`cat serverlist.log | grep -E "\blabel\b|\bmain_ip\b" |sed -n "/$MONITOR_IP/{x;p};h" |awk -F '"' '{print$4}'`
        echo `date +"%Y-%m-%d %H:%M:%S"` "获取的v2ray服务器label为$LABEL"

        rm serverlist.log
        #获取宽带使用量
        curl -H "$key" https://api.vultr.com/v1/server/bandwidth?SUBID=$MONITOR_SUBID | python -m json.tool > log1
        all_count=`cat log1 |wc -l`
        half_count=`expr $all_count / 2`
        cat log1 | grep -A $half_count "outgoing_bytes"  > log2
        rm log1
        sed -i '$d' log2
        sed -i '1d' log2
        sed -i '$d' log2
        sed -i '/,/d' log2
        sed -i '1~2d' log2
        BANDWIDTH=`awk -F '"' '{sum+=$2};END {print sum}' log2`
        rm log2
        echo `date +"%Y-%m-%d %H:%M:%S"` "获取v2ray服务器宽带使用率为 $BANDWIDTH 字节"

        i=`expr 1024 \* 1024 \* 1024`
        BANDUSAGE=`echo "sclae=2;$BANDWIDTH/$i" | bc`
        echo `date +"%Y-%m-%d %H:%M:%S"` "获取的宽带使用率为$BANDUSAGE G"
	if [ $BANDUSAGE -gt 100 ]
	then
        echo `date +"%Y-%m-%d %H:%M:%S"` "触发重新搭建服务器条件,同时将keepalived服务停用"
        echo `date +"%Y-%m-%d %H:%M:%S"` "正在停用keepalived服务"
        ansible $gw -m shell -a 'service keepalived stop'
        echo `date +"%Y-%m-%d %H:%M:%S"` "$gw 的keepalived服务停用成功"
        echo `date +"%Y-%m-%d %H:%M:%S"` "正在销毁v2ray服务器"
        curl -H "$key" https://api.vultr.com/v1/server/destroy --data "SUBID=$MONITOR_SUBID"
        echo `date +"%Y-%m-%d %H:%M:%S"` "等待删除$LABEL"
        sleep 30
        echo `date +"%Y-%m-%d %H:%M:%S"` "删除$LABEL 成功"
        echo `date +"%Y-%m-%d %H:%M:%S"` "获取$gw 使用的v2ray服务器的label	$LABEL"

        #reinstall
        echo `date +"%Y-%m-%d %H:%M:%S"` "重新安装v2ray服务器"
        SSHKEYID=`curl -H "$key" https://api.vultr.com/v1/sshkey/list |python -m json.tool |grep -E "\bSSHKEYID\b|\bname\b" | sed -n '/252/{x;p};h' | awk -F '"' '{print$4}'`
        curl -H "$key" https://api.vultr.com/v1/server/create --data "DCID=39" --data 'VPSPLANID=201' --data 'OSID=193'  --data "label=$LABEL" --data "SSHKEYID=$SSHKEYID" > subid.txt
        echo `date +"%Y-%m-%d %H:%M:%S"` "installing server......"
        INSTALL_SUBID=`cat subid.txt | awk -F '"' '{print$4}'`
        echo `date +"%Y-%m-%d %H:%M:%S"` "正在安装的v2ray服务器的subid为$INSTALL_SUBID"

        sleep 20
        ip=""
        while true
        do
            ip=`curl -H "$key" https://api.vultr.com/v1/server/list?SUBID=$INSTALL_SUBID | python -m json.tool | grep -E "\bmain_ip\b"  |awk -F '"' '{print$4}'`
            if [ $ip == "0.0.0.0" ]
            then
                echo `date +"%Y-%m-%d %H:%M:%S"` "getting ip......sleep 20"
                sleep 20
            else
                echo `date +"%Y-%m-%d %H:%M:%S"` "新建的v2ray服务器IP地址为$ip"
                break
            fi
        done

        pwd=""
        while true
        do
            pwd=`curl -H "$key" https://api.vultr.com/v1/server/list?SUBID=$INSTALL_SUBID  | python -m json.tool | grep -E  "\bdefault_password\b" |awk -F '"' '{print$4}'`
            if [ -z $pwd ]
            then
                echo `date +"%Y-%m-%d %H:%M:%S"` "getting pwd......"
                sleep 20
            else
                echo `date +"%Y-%m-%d %H:%M:%S"` "获取的v2ray服务器的密码为$pwd"
                break
            fi
        done

        rm subid.txt
        echo `date +"%Y-%m-%d %H:%M:%S"` "sleep 60"
        sleep 60

	i=1
        while [ $i -lt 3 ]
        do
            ping -c 2 -W 2 $ip >> /dev/null
            if [ $? -eq 0 ]
            then
                echo `date +"%Y-%m-%d %H:%M:%S"` "检查v2ray服务器ip地址存在！"
                echo `date +"%Y-%m-%d %H:%M:%S"` "------------------------"
                echo `date +"%Y-%m-%d %H:%M:%S"` "清理本地已经存在$ip 的密钥"
                ssh-keygen -f "/root/.ssh/known_hosts" -R $ip
                echo `date +"%Y-%m-%d %H:%M:%S"` "重新添加$ip 的密钥，正在添加密钥！"

                LOCALSSHKEY=`cat /root/.ssh/id_rsa.pub`
                sshpass -p $pwd ssh root@$ip "echo $LOCALSSHKEY >> /root/.ssh/authorized_keys"
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

                echo `date +"%Y-%m-%d %H:%M:%S"` "-------------------"
                echo `date +"%Y-%m-%d %H:%M:%S"` "开始安装v2ray服务端,并且进行配置，使用ansible的script模块拷贝配置文件"
                ansible $LABEL -m script -a "/root/v2ray/v2ray_server_install.sh"
                ansible $LABEL -m copy -a "src=/root/v2ray/server_config.json dest=/etc/v2ray/config.json owner=root group=root mode=0644"
                echo `date +"%Y-%m-%d %H:%M:%S"` "v2ray服务端安装完毕！"
                echo `date +"%Y-%m-%d %H:%M:%S"` "获取v2ray服务器的IP\PORT\ID"
                ip=`ansible $LABEL -m shell -a "ifconfig" | sed -n '3p'|awk '{print$2}'|awk -F ':' '{print$2}'`
                port=`ansible $LABEL -m shell -a "cat /root/config.json.bak" |sed -n '4p'`
                id=`ansible $LABEL -m shell -a "cat /root/config.json.bak" |sed -n '9p'`
                ansible $LABEL -m shell -a "cat  /root/config.json.bak"
                ansible $LABEL -m shell -a "cat  /etc/v2ray/config.json"
                echo `date +"%Y-%m-%d %H:%M:%S"` "$ip" "$port"  "$id"
                echo `date +"%Y-%m-%d %H:%M:%S"` "正在修改-----------------"
                ansible $LABEL -m shell -a "sed -i '8i\\$port' /etc/v2ray/config.json"
                ansible $LABEL -m shell -a "sed -i '9d' /etc/v2ray/config.json"
                ansible $LABEL -m shell -a "sed -i '13i\\$id' /etc/v2ray/config.json"
                ansible $LABEL -m shell -a "sed -i '14d' /etc/v2ray/config.json"
                echo `date +"%Y-%m-%d %H:%M:%S"` "修改完毕，v2ray服务端配置成功!重启v2ray服务器"
                ansible $LABEL -m shell -a "service v2ray restart"
                echo `date +"%Y-%m-%d %H:%M:%S"` "v2ray服务重启成功！"
                echo `date +"%Y-%m-%d %H:%M:%S"` "-------------------"
                break
            else
                echo `date +"%Y-%m-%d %H:%M:%S"` "连接超时，重新安装服务器"
		let i++
                curl -H "$key" https://api.vultr.com/v1/server/reinstall --data "SUBID=$INSTALL_SUBID"
		sleep 90
		if [ $i -eq 3 ]
		then
			echo "重试2次无效，退出"
			exit 1
		fi
            fi
        done
	
	sleep 60
	
        echo `date +"%Y-%m-%d %H:%M:%S"` "更新局域网的网关服务"
        echo `date +"%Y-%m-%d %H:%M:%S"` "正在验证$gw 分组是否存在,请稍后..."
        count1=`ansible "$gw" -m ping|grep SUCCESS|wc -l`
        if [ $count1 -gt 0 ]
        then
            echo `date +"%Y-%m-%d %H:%M:%S"` "验证成功gw分组存在！分组名为$gw"
        else
            echo `date +"%Y-%m-%d %H:%M:%S"` "gw分组不存在，请重新输入......"
            exit 1
        fi

	sleep 60

        echo `date +"%Y-%m-%d %H:%M:%S"` "正在验证$LABEL 分组是否存在,请稍后..."
        count2=`ansible $LABEL -m ping|grep SUCCESS|wc -l`
        if [ $count2 -gt 0 ]
        then
            echo `date +"%Y-%m-%d %H:%M:%S"` "验证成功$LABEL 分组存在！分组名为$LABEL"
        else
            echo `date +"%Y-%m-%d %H:%M:%S"` "$LABEL 分组不存在，请重新输入......"
            exit 1
        fi

        server_address=`ansible $LABEL -m shell -a "ifconfig" | sed -n '3p'|awk '{print$2}'|awk -F ':' '{print$2}'`
        echo `date +"%Y-%m-%d %H:%M:%S"` "v2ray_server的IP是$server_address"
        server_port=`ansible $LABEL -m shell -a "cat /etc/v2ray/config.json" | grep port | sed -n '1p'`
        echo `date +"%Y-%m-%d %H:%M:%S"` "$server_port"
        server_id=`ansible $LABEL -m shell -a "cat /etc/v2ray/config.json" | grep id`
        echo `date +"%Y-%m-%d %H:%M:%S"` "$server_id"

        echo `date +"%Y-%m-%d %H:%M:%S"` "下一步需要修改$gw 组的配置文件，现在正在形成参数"
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

        echo `date +"%Y-%m-%d %H:%M:%S"` "执行修改局域网GW的配置文件"
        echo `date +"%Y-%m-%d %H:%M:%S"` "配置ip地址"
        ansible "$gw" -m shell -a "sed -i '13i\\$address' /etc/v2ray/config.json"
        ansible "$gw" -m shell -a "sed -i '14d' /etc/v2ray/config.json"

        echo `date +"%Y-%m-%d %H:%M:%S"` "配置端口"
        ansible "$gw" -m shell -a "sed -i '14i\\$port' /etc/v2ray/config.json"
        ansible "$gw" -m shell -a "sed -i '15d' /etc/v2ray/config.json"

        echo `date +"%Y-%m-%d %H:%M:%S"` "配置id"
        ansible "$gw" -m shell -a "sed -i '17i\\$id' /etc/v2ray/config.json"
        ansible "$gw" -m shell -a "sed -i '18d' /etc/v2ray/config.json"

        echo `date +"%Y-%m-%d %H:%M:%S"` "配置防火墙"
        echo `date +"%Y-%m-%d %H:%M:%S"` "1.拼接防火墙"
        fire_wall="iptables -t nat -A V2RAY -d  $server_address -j RETURN"
        echo `date +"%Y-%m-%d %H:%M:%S"` $fire_wall
        ansible "$gw" -m shell -a "sed -i '14i\\$fire_wall' /opt/v2ray-firewall"
        ansible "$gw" -m shell -a "sed -i '15d' /opt/v2ray-firewall"

        echo `date +"%Y-%m-%d %H:%M:%S"` "重启gw的v2ray服务"
        ansible "$gw" -m shell -a "service v2ray restart"
        ansible "$gw" -m shell -a "service dnsmasq restart"
        ansible "$gw" -m shell -a "service keepalived restart"
        echo `date +"%Y-%m-%d %H:%M:%S"` "服务重启成功！"
        echo `date +"%Y-%m-%d %H:%M:%S"` "配置完毕！"
	else
	echo `date +"%Y-%m-%d %H:%M:%S"` "流量小于10G，监控结束！"
	fi
        echo "                                                                              "
    fi
done
