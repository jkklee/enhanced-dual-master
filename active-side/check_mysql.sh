#!/bin/sh
#by lijiankai 20160321 

###判断如果上次检查的脚本还没执行完，则退出此次执行
if [ `ps -ef|grep -w "$0"|grep "/bin/sh*"|grep "?"|grep "?"|grep -v "grep"|wc -l` -gt 2 ];then  #理论上这里应该是1，但是实验的结果却是2
    exit 0
fi
 
alias mysql_con='mysql -uroot -pxxxxx'

###定义一个简单判断mysql是否可用的函数
function excute_query {
    mysql_con -e "select table_name from information_schema.tables limit 1" 2>>/etc/keepalived/logs/check_mysql.err
}
 
###定义无法执行查询，且mysql服务异常时的处理函数
function service_error {
    echo -e "`date "+%F  %H:%M:%S"`    -----mysql service error，now stop keepalived-----" >> /etc/keepalived/logs/check_mysql.err
    /sbin/service keepalived stop &>> /etc/keepalived/logs/check_mysql.err
    echo -e "\n@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n" >> /etc/keepalived/logs/check_mysql.err
}
    
###定义无法执行查询,但mysql服务正常的处理函数
function query_error {
    echo -e "`date "+%F  %H:%M:%S"`    -----query error, but mysql service ok, retry after 45s-----" >> /etc/keepalived/logs/check_mysql.err
    sleep 45
    excute_query
    if [ $? -ne 0 ];then
        echo -e "`date "+%F  %H:%M:%S"`    -----still can't execute query-----" >> /etc/keepalived/logs/check_mysql.err
         
        ###对DB1设置read_only属性
        echo -e "`date "+%F  %H:%M:%S"`    -----set read_only = 1 on DB1-----" >> /etc/keepalived/logs/check_mysql.err
        mysql_con -e "set global read_only = 1;" 2>> /etc/keepalived/logs/check_mysql.err
         
        ###kill掉当前客户端连接
        echo -e "`date "+%F  %H:%M:%S"`    -----kill current client thread-----" >> /etc/keepalived/logs/check_mysql.err
        rm -f /tmp/kill.sql &>/dev/null
        ###这里其实是一个批量kill线程的小技巧
        mysql_con -e 'select concat("kill ",id,";") from  information_schema.PROCESSLIST where command="Query" or command="Execute" into outfile "/tmp/kill.sql";'
        mysql_con -e "source /tmp/kill.sql"
        sleep 2    ###给kill一个执行和缓冲时间
        ###关闭本机keepalived       
        echo -e "`date "+%F  %H:%M:%S"`    -----stop keepalived-----" >> /etc/keepalived/logs/check_mysql.err 
        /sbin/service keepalived stop &>> /etc/keepalived/logs/check_mysql.err
        echo -e "\n@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n" >> /etc/keepalived/logs/check_mysql.err
    else
        echo -e "`date "+%F  %H:%M:%S"`    -----query ok after 30s-----" >> /etc/keepalived/logs/check_mysql.err
        echo -e "\n@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n" >> /etc/keepalived/logs/check_mysql.err
    fi
}
 
###检查开始: 执行查询
excute_query
if [ $? -ne 0 ];then
    /sbin/service mysqld status &>/dev/null
    if [ $? -ne 0 ];then
        service_error
    else
        query_error
    fi
fi