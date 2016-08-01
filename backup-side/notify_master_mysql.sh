#!/bin/bash
#by lijiankai 20160321

###当keepalived监测到本机转为MASTER状态时，执行该脚本

change_log=/etc/keepalived/logs/state_change.log
alias mysql_con='mysql -uroot -pxxxxx -e "show slave status\G;" 2>/dev/null'

echo -e "`date "+%F  %H:%M:%S"`   -----keepalived change to MASTER-----" >> $change_log

slave_info() {
    ###统一定义一个函数取得slave的position、running、和log_file等信息
    ###根据函数后面所跟参数来决定取得哪些数据
    if [ $1 = slave_status ];then
        slave_stat=`mysql_con|egrep -w "Slave_IO_Running|Slave_SQL_Running"`
        Slave_IO_Running=`echo $slave_stat|awk '{print $2}'`
        Slave_SQL_Running=`echo $slave_stat|awk '{print $4}'`
    elif [ $1 = log_file -a $2 = pos ];then
        log_file_pos=`mysql_con|egrep -w "Master_Log_File|Read_Master_Log_Pos|Exec_Master_Log_Pos"`
        Master_Log_File=`echo $log_file_pos|awk '{print $2}'`
        Read_Master_Log_Pos=`echo $log_file_pos|awk '{print $4}'`
        Exec_Master_Log_Pos=`echo $log_file_pos|awk '{print $6}'`
    fi
}

action() {
    ###经判断'应该&可以'切换时执行的动作
    echo -e "`date "+%F  %H:%M:%S"`    -----set read_only = 0 on DB2-----" >> $change_log

    ###解除read_only属性
    mysql_con -e "set global read_only = 0;" 2>> $change_log

    echo "DB2 keepalived转为MASTER状态，线上数据库切换至DB2"|/bin/mailx -s "DB2 keepalived change to MASTER"\
    lijiankai@xxxx.com 2>> $change_log

    echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n" >> $change_log
}

slave_info slave_status
if [ $Slave_IO_Running = Yes -a $Slave_SQL_Running = Yes ];then
    i=0    #一个计数器
    slave_info log_file pos
    until [ $Read_Master_Log_Pos = $Exec_Master_Log_Pos ]    #判断从库是否追上了主库
    do
        if [ $i -lt 10 ];then    #将等待exec_pos追上read_pos的时间限制为10s
            echo -e "`date "+%F  %H:%M:%S"`    -----Master_Log_File=$Master_Log_File. Exec_Master_Log_Pos($Exec_Master_Log_Pos) is behind Read_Master_Log_Pos($Read_Master_Log_Pos), wait......" >> $change_log
            i=$(($i+1))
            sleep 1
            slave_info log_file pos
        else
            echo -e "The waits time is more than 10s,now force change. Master_Log_File=$Master_Log_File Read_Master_Log_Pos=$Read_Master_Log_Pos Exec_Master_Log_Pos=$Exec_Master_Log_Pos" >> $change_log
            action
            exit 0
        fi
    done
else
    slave_info log_file pos
    echo -e "DB2's slave status is wrong,now force change. Master_Log_File=$Master_Log_File Read_Master_Log_Pos=$Read_Master_Log_Pos  Exec_Master_Log_Pos=$Exec_Master_Log_Pos" >> $change_log 
    action
fi
