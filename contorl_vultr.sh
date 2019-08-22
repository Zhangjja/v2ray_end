#!/bin/bash




curl -H 'API-Key: QYLPNWSVQW6KQSJD4ES3R3QDZXMJD3IXIK2A' https://api.vultr.com/v1/server/list | python -m json.tool | grep  -E "\blabel\b|\bSUBID\b|\bmain_ip\b" |awk '{print$1 $2}' > logfile

cat logfile

while true
do
	read -p "选择要删除的服务器SUBID 取消输入[n] : " subid
	if [ $subid == "n" ]
	then
		rm logfile
		break
	else
		count=`cat logfile | grep -E "\b$subid\b" |wc -l`
		rm logfile
		if [ $count -gt 0 ]
		then
			curl -H 'API-Key: QYLPNWSVQW6KQSJD4ES3R3QDZXMJD3IXIK2A' https://api.vultr.com/v1/server/destroy --data "SUBID=$subid"
			echo "SUBID: $subid 删除成功"
			break
		else
			echo "$subid 不存在"
		fi
	fi
done

