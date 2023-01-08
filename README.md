# gfwlist2ros
gfwlist to RouterOS
借鉴 https://github.com/goodffd/tool 修改
#部署条件：
1、一个Liunx系统，并且部署nginx服务，记录ip（例如：192.168.1.4）
2、一个能科学的旁路由，记录ip（例如：192.168.1.2）
3、一台ROS路由，记录ip（例如：192.168.1.1）
#部署步骤：
1、Liunx系统上git本应用
  git clone https://github.com/Yoongger/gfwlist2ros.git
修改 gfwlist2ros.sh，68行 修改 192.168.1.2 为您的旁路由ip
添加定时任务
2、ROS添加脚本
/system script
add dont-require-permissions=no name=update_gfwlist_ip_final owner=lomor policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="# Update gfwlist_ip_final\r\
    \n:local url \"http://192.168.1.4/gfwlist_ip_final.rsc\"\r\
    \n:local filename \"gfwlist_ip_final.rsc\"\r\
    \n\r\
    \n/tool fetch mode=http url=\$url\r\
    \n:if ([:len [/file find name=\$filename]]) do={\r\
    \n  /import \$filename\r\
    \n  /file remove \$filename\r\
    \n  :log info \"import \$filename success!\"\r\
    \n} else={\r\
    \n  :log war \"file \$filename is not exist!\"\r\
    \n}"
add dont-require-permissions=no name=update_gfwlist_domain owner=lomor policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="# Update gfwlist_domain\r\
    \n:local url \"http://192.168.1.4/gfwlist_domain.rsc\"\r\
    \n:local filename \"gfwlist_domain.rsc\"\r\
    \n\r\
    \n/tool fetch mode=http url=\$url\r\
    \n:if ([:len [/file find name=\$filename]]) do={\r\
    \n  /import \$filename\r\
    \n  /file remove \$filename\r\
    \n  :log info \"import \$filename success!\"\r\
    \n} else={\r\
    \n  :log war \"file \$filename is not exist!\"\r\
    \n}"
3、ROS添加定时任务
/system scheduler
add interval=1d name=gfwlist_domain_schedule on-event=update_gfwlist_domain policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-time=startup
add interval=1d name=gfwlist_ip_schedule on-event=update_gfwlist_ip_final policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-time=startup
4、ROS策略设置
/ip firewall mangle
add action=mark-routing chain=prerouting dst-address-list=gfwlist new-routing-mark=proxy passthrough=yes src-address-list=proxy
/ip firewall address-list
add address=192.168.1.101-192.168.1.200 list=proxy
/ip route
add disabled=no distance=1 dst-address=0.0.0.0/0 gateway=192.168.1.2 pref-src="" routing-table=proxy scope=30 suppress-hw-offload=no target-scope=10
