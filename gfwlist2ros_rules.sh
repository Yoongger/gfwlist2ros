#!/bin/bash
_green() {
    printf '\033[1;31;32m'
    printf -- "%b" "$1"
    printf '\033[0m'
}

_red() {
    printf '\033[1;31;31m'
    printf -- "%b" "$1"
    printf '\033[0m'
}

_yellow() {
    printf '\033[1;31;33m'
    printf -- "%b" "$1"
    printf '\033[0m'
}

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
  sudoCmd="sudo"
else
  sudoCmd=""
fi

#copied & modified from atrandys trojan scripts
#copy from 秋水逸冰 ss scripts
if [[ -f /etc/redhat-release ]]; then
  release="centos"
  systemPackage="yum"
elif cat /etc/issue | grep -Eqi "debian"; then
  release="debian"
  systemPackage="apt-get"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
  release="ubuntu"
  systemPackage="apt-get"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
  release="centos"
  systemPackage="yum"
elif cat /proc/version | grep -Eqi "debian"; then
  release="debian"
  systemPackage="apt-get"
elif cat /proc/version | grep -Eqi "ubuntu"; then
  release="ubuntu"
  systemPackage="apt-get"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
  release="centos"
  systemPackage="yum"
fi

if [ ${systemPackage} == "yum" ]; then
    ${sudoCmd} ${systemPackage} install bind-utils wget nginx -y -q
else
    ${sudoCmd} ${systemPackage} install dnsutils wget nginx -y -qq
fi

wget -N --no-check-certificate https://raw.githubusercontent.com/cokebar/gfwlist2dnsmasq/master/gfwlist2dnsmasq.sh && chmod +x gfwlist2dnsmasq.sh && sh ./gfwlist2dnsmasq.sh -l -o ./gfwlist_domain.rsc

#增加额外需要加入gfwlist的域名
echo "libreswan.org" >> gfwlist_domain.rsc
echo "download.mikrotik.com" >> gfwlist_domain.rsc
_green 'add some domains to gfwlist.\n'

_green 'start resolve domain.\n'

if [ ${release} == "centos" ]; then
    nginx_root="/usr/share/nginx/html"
else
    nginx_root="/var/www/html"
fi

rm -f ${nginx_root}/gfwlist_ip.rsc

#解析gfwlist域名并验证解析结果是否为合法的ip地址
#用ipcalc验证ip地址合法性（如果dig的结果为非ip地址，如CNAME，则判定为非合法的ip地址）
#ipcalc只适用centos，其他系统用脚本判断（脚本判断耗时为ipcalc的3倍左右）
if [ ${release} == "centos" ]; then
    while read -r line
    do
      #将读取的每一行域名删除回车符、换行符
      line=$(echo ${line} | tr -d '\n' | tr -d '\r')
      #取dig answer段的最后一行解析结果（解析出来如果是有CNAME记录和ip记录，则ip记录是在最后行）
      ip=$(dig ${line} +short | tail -n 1)
      ipcalc -cs ${ip}
           if [[ $? -eq 0  && ${ip} != "0.0.0.0" && -n ${ip} ]]; then
             echo ${ip} >> ${nginx_root}/gfwlist_ip.rsc
           fi
     done < gfwlist_domain.rsc
else 
     while read -r line
     do
       #将读取的每一行域名删除回车符、换行符
       line=$(echo ${line} | tr -d '\n' | tr -d '\r')
       #取dig answer段的最后一行解析结果（解析出来如果是有CNAME记录和ip记录，则ip记录是在最后行）
       ip=$(dig ${line} +short | tail -n 1)
       #其他系统用脚本判断
       VALID_CHECK=$(echo ${ip}|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
           if [[ ${VALID_CHECK:-no} == "yes" && ${ip} != "0.0.0.0" && -n ${ip} ]]; then
              echo ${ip} >> ${nginx_root}/gfwlist_ip.rsc
           fi
      done < gfwlist_domain.rsc
fi

sort -n ${nginx_root}/gfwlist_ip.rsc | uniq > ${nginx_root}/gfwlist_ip_final.rsc

gfwlist_ip_filename="gfwlist_ip_final.rsc"

#开始处理 gfwlist_ip_filename 内容
#方法1
sed -i 's/\(.*\)/add address=\1 list=gfwlist/g' ${nginx_root}/${gfwlist_ip_filename}

#方法2
#1、每行行首增加字符串"add action=lookup dst-address="
#sed -i 's/^/add action=lookup dst-address=&/g' ${nginx_root}/${gfwlist_ip_filename}

#2、每行行尾增加字符串" table=gfw"
#sed -i 's/$/& table=gfw/g' ${nginx_root}/${gfwlist_ip_filename}

#3、在文件第1行前插入新行"/log info "Loading gfwlist ipv4 route rules"
sed -i '1 i/log info "Loading gfwlist ipv4 route rules"' ${nginx_root}/${gfwlist_ip_filename}

#4、在文件第2行前插入新行"/ip firewall address-list remove [/ip firewall address-list find list=gfwlist]"
sed -i '2 i/ip firewall address-list remove [/ip firewall address-list find list=gfwlist]' ${nginx_root}/${gfwlist_ip_filename}

#5、在文件第3行前插入新行"/ip route rule"
sed -i '3 i/ip firewall address-list' ${nginx_root}/${gfwlist_ip_filename}

_green 'all is done.\n'
