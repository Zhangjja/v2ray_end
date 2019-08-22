#!/bin/bash

echo "安装v2ray服务端"
echo "bash <(curl -L -s https://install.direct/go.sh)"

while true
do
    bash <(curl -L -s https://install.direct/go.sh)
    if [ $? -eq 0 ]
    then
        echo "v2ray服务端安装成功"
    else
        echo "v2ray安装失败"
        continue
    fi
    echo "cp /etc/v2ray/config.json /root/"
    cp -p /etc/v2ray/config.json /root/config.json.bak
    count=`ls /root/ | grep config | wc -l`
    if [ $count -gt 0 ]
    then
        echo "config文件备份成功"
        break
    else
        echo "config文件不存在，备份失败"
        continue
    fi
done







