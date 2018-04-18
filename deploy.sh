#!/bin/bash 
# Writer: no_kill_linux
# ----------------------------------------
# Variable area
# ----------------------------------------
#/opt/ytd_scripts/deploy.sh [deploy|run] $Build_Tag $Project_Name $Service_Name $Active_Profile
Goal=$1
Build_Tag=$2
Project_Name=$3
Service_Name=$4
Active_Profile=$5
Current_Date='-'`date +%F-%T`'.bak' # test system
Log_Date=`date +%Y-%m-%d`
Workshop=/opt/ytd_bak/update/$Service_Name/$Build_Tag/
Up_Code_Dir=/opt/ytd_data/
Play_Code_Dir=/opt/ytd_web/
Log_Dir=/opt/ytd_logs/$Project_Name/catalina.$Log_Date'.out'
Bak_Dir=/opt/ytd_bak/update/$Service_Name/$Build_Tag$Current_Date
NumPro=`ps -ef |grep $Service_Name|grep -v grep |grep java|awk '{print $2}'|wc -l`
ProRes=`ps -ef |grep $Service_Name|grep -v grep |grep java|awk '{print $2}'`
# ----------------------------------
# 
# ----------------------------------
function get_Proc_Count(){
    return `ps -ef |grep $Service_Name|grep -v grep |grep java|awk '{print $2}'|wc -l`
}

function get_Proc_Num(){
    return `ps -ef |grep $Service_Name|grep -v grep |grep java|awk '{print $2}'`
}

function plink() {
    cd $Play_Code_Dir$Project_Name && `ln -s /opt/ytd_nas/share_data/upload upload`
    cd $Play_Code_Dir$Project_Name && `ln -s /opt/ytd_nas/share_data/user user`
}
function deploy_general() {
    cd $Workshop
    echo "== Start to uncompress the war file to $Workshop$Project_Name"
    buildFileCount=$(ls *.war|wc -l)
    if [ $buildFileCount -gt 1 ];then
   	echo "$buildFileCount files found!"
	exit 1
    elif [ $buildFileCount -eq 1 ];then
        unzip -d  $Workshop$Project_Name *.war
    elif [ $buildFileCount -eq 0 ];then
    	echo "Warning! No *.war file exists!"
    fi
    echo "== Backup the current build to $Bak_Dir"
    cd $Play_Code_Dir && mv $Project_Name $Bak_Dir
    echo "== Deploy the uncompressed build to $Play_Code_Dir$Project_Name"
    `mv -f $Workshop$Project_Name $Play_Code_Dir`
    #Copy the staging configuration files
    echo "== Implement the configurations under $Play_Code_Dir$Project_Name/WEB-INF/classes/$Active_Profile/"
    if [ -d $Play_Code_Dir$Project_Name/WEB-INF/classes/$Active_Profile/ ];then
        `cp $Play_Code_Dir$Project_Name/WEB-INF/classes/$Active_Profile/* $Play_Code_Dir$Project_Name/WEB-INF/classes/`
    else
        echo "== $Active_Profile configuration files not found!"
        exit 1
    fi
}

function deploy_news() {
    cd $Workshop
    echo "== Backup the current build to $Bak_Dir"
    cd $Play_Code_Dir && mv $Project_Name $Bak_Dir
    echo "== Deploy the WebContent to $Play_Code_Dir$Project_Name"
    `mv -f $Workshop'WebContent' $Play_Code_Dir$Project_Name`
    echo "== Deploy the news_bak to $Play_Code_Dir$Project_Name"
    `cp -rf  $Play_Code_Dir'news_bak/'* $Play_Code_Dir'news/'`
}

function deploy_portal() {
    echo "== copy static files to share folder"
    `cp -rf /opt/ytd_web/portal/*.* /opt/ytd_nas/share_data/`
    `cp -rf /opt/ytd_web/portal/css /opt/ytd_nas/share_data/`
    `cp -rf /opt/ytd_web/portal/img /opt/ytd_nas/share_data/`
    `cp -rf /opt/ytd_web/portal/js /opt/ytd_nas/share_data/`
    `cp -rf /opt/ytd_web/portal/lvjs /opt/ytd_nas/share_data/`
    `cp -rf /opt/ytd_web/portal/new /opt/ytd_nas/share_data/`
    `cp -rf /opt/ytd_web/portal/static /opt/ytd_nas/share_data/`
}

function deploy() {
    deploy_prepare
    case $Project_Name in
	news)
	    deploy_news
	    ;;
  	portal)
    	    deploy_general
	    deploy_portal
	    ;;
	*)
    	    deploy_general
    esac
    deploy_complete
}

function deploy_prepare() { 
    #if [ -d $Workshop ]; then
    #    `/bin/rm -r $Workshop`
    #	echo "$Workshop removed!"
    #else
    #	echo "$Workshop doens't exist!"
    #fi
    #`mkdir -p $Workshop`
    if [ ! -d $Workshop ];then
    	echo "$Workshop doesn't exist!"
	exit 1
    fi
    echo "== Prepare to stop service /etc/init.d/$Service_Name"
    sudo service $Service_Name stop
    NumPro=`ps -ef |grep $Service_Name |grep -v grep |grep java|awk '{print $2}'|wc -l`
    if [ $NumPro -eq 0 ];then
        echo "== service $Service_Name process has been down"
    else
    	echo  "== Stopping $Service_Name with process $ProRes" && sleep 3
    	`kill -9 $ProRes && sleep 5`
	NumPro=`ps -ef |grep $Service_Name |grep -v grep |grep java|awk '{print $2}'|wc -l`
        if [ $NumPro -eq 0 ];then
           echo "== Service $Service_Name is killed" && sleep 3 
        else
	   echo "== Failed to stop the current service"
           exit 1
        fi
    fi 
}
function deploy_complete() {
    if [ $Project_Name == 'platform' ]; then
        plink
        echo "== softlink created for platform"
    elif [ $Project_Name == 'portal' ]; then
        plink
        echo "== softlink created for portal"
    elif [ $Project_Name == 'mobile' ]; then
        plink
        echo "== softlink created for mobile"
    elif [ $Project_Name == 'api-client' ]; then
        plink
        echo "== softlink created for api-client"
    else
        echo "== No soft link needed"
    fi
    echo "== Start to launch service $Service_Name"
    #nohup sudo service $Service_Name start >$Workshop'deploy.log' 2>&1 &
    nohup /opt/ytd_soft/${Service_Name}/bin/startup.sh >$Workshop'deploy.log' 2>&1 &
}

function run() {
    cd $Workshop
    echo "== Start to run $Service_Name"
    source /opt/ytd_scripts/run.sh restart $Service_Name $Active_Profile
}

function rollback() {
    echo "== Prepare to stop $Service_Name"
    sudo /etc/init.d/$Service_Name stop 
    sleep 5
    echo "== Backup the current build $Project_Name.bak"
    cd $Play_Code_Dir && mv $Project_Name $Project_Name'.bak'
    echo "== Restore the previous build $Bak_Dir"
    cp -rf $Bak_Dir $Play_Code_Dir$Project_Name
    echo "== Destroy the legacy build $Play_Code_Dir$Project_Name'.bak'"
    rm -rf $Play_Code_Dir$Project_Name'.bak'
    echo "== Prepare to start service /etc/init.d/$Service_Name"
    #nohup sudo /etc/init.d/$Service_Name start 2>&1
    nohup /opt/ytd_soft/${Service_Name}/bin/startup.sh >$Workshop'deploy.log' 2>&1 &
    sleep 5
}

function verify() {
    sleep 10
    NumPro=`ps -ef |grep $Service_Name |grep -v grep |grep java|awk '{print $2}'|wc -l`
    if [ $NumPro -eq 0 ];then
	echo "Service is not running!"
    	exit 1
    fi
}

case $Goal in 
    deploy)
        deploy 2>>$Workshop'deploy.log'
	echo "======================================"
	echo "=========  Deploy Log ================="
	echo "======================================"
        cat $Workshop'deploy.log'
	echo "============ End ====================="
	verify
        ;;
    run)
        run 2>>$Workshop'run.log'
	echo "======================================"
	echo "=========  Run Log ================="
	echo "======================================"
        cat $Workshop'run.log'
	echo "============ End ====================="
	verify
        ;;
    rollback)
        rollback 2>>$Workshop'rollback.log'
	echo "======================================"
	echo "=========  Rollback Log ================="
	echo "======================================"
        cat $Workshop'rollback.log'
	echo "============ End ====================="
	verify
        ;;
    *)
        echo 'Usage: $0 {deploy|rollback} BUILD_TAG Project_Name Service_Name'
esac
