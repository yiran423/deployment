#!/bin/bash

# 运维人员应该在虚拟机里设置 ACTIVE_PROFILE 环境变量
# 针对不同的环境，ACTIVE_PROFILE 有以下选择
#
# development.env   开发人员的本地开发环境
# staging.env       测试部署环境
# preproduction.env 准生产环境
# production.env    生产环境
#

SERVICE_NAME=$2
ACTIVE_PROFILE=$3
BUILD_FILE_COUNT=`ls *.jar|wc -l`
BUILD_FILE=`ls *.jar`
if [ $BUILD_FILE_COUNT -gt 1 ];then
   echo "==Error: multiple build files found!"
   exit 1
else
   echo "== $BUILD_FILE found."
fi

if [ -z "$ACTIVE_PROFILE" ]; then
    ACTIVE_PROFILE=staging.env
fi

INIT_HEAPSIZE=1g
MAX_HEAPSIZE=2g
INIT_PERMSIZE=128m
MAX_PERMSIZE=256m

PROJECT_LOG=/opt/ytd_logs/$SERVICE_NAME
PROJECT_LOG_LEVEL=INFO
GC_LOG_DIR=/opt/ytd_logs/$SERVICE_NAME/gc
HEAPDUMP_DIR=/opt/ytd_logs/$SERVICE_NAME/gc

if [ "production.env" == ${ACTIVE_PROFILE} ]; then
  INIT_HEAPSIZE=2g
  MAX_HEAPSIZE=4g
  INIT_PERMSIZE=256m
  MAX_PERMSIZE=512m

  GC_LOG_DIR=/opt/ytd_logs/$SERVICE_NAME/gc
  HEAPDUMP_DIR=/opt/ytd_logs/$SERVICE_NAME/gc
fi

## 设置gc log目录
export GC_LOG_DIR
export HEAPDUMP_DIR
mkdir -p ${GC_LOG_DIR}
mkdir -p ${HEAPDUMP_DIR}

## 设置jvm参数
jdk_verbose_version=`/opt/ytd_soft/java/bin/java -version 2>&1 | grep version | awk -F"\"" '{print $2}'`
echo "== JDK version: ${jdk_verbose_version}"

jdk_major_version=`/opt/ytd_soft/java/bin/java -version 2>&1 | grep version | awk -F"." '{print $2}'`
if [ $jdk_major_version -gt 7 ];
then
  ### jdk7 之后的版本
  JAVA_OPTS="${JAVA_OPTS} -XX:MetaspaceSize=${INIT_PERMSIZE} -XX:MaxMetaspaceSize=${MAX_PERMSIZE}"
else
  ### jdk7 以及之前的版本
  JAVA_OPTS="${JAVA_OPTS} -XX:PermSize=${INIT_PERMSIZE} -XX:MaxPermSize=${MAX_PERMSIZE}"
  JAVA_OPTS="${JAVA_OPTS} -XX:+UseConcMarkSweepGC -XX:CMSMaxAbortablePrecleanTime=5000"
fi
JAVA_OPTS="${JAVA_OPTS} -Xms${INIT_HEAPSIZE} -Xmx${MAX_HEAPSIZE}"
JAVA_OPTS="${JAVA_OPTS} -Xloggc:${GC_LOG_DIR}/gc.log_$(date +%F) -XX:+PrintGCDetails -XX:+PrintGCDateStamps"
JAVA_OPTS="${JAVA_OPTS} -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=${HEAPDUMP_DIR}/heapdump_$(date +%m-%d_%H:%M:%S).hprof"
JAVA_OPTS="${JAVA_OPTS} -Dfile.encoding=UTF-8"

export JAVA_OPTS

## 具体操作
function start() {
  echo "== Starting $SERVICE_NAME"
  nohup /opt/ytd_soft/java/bin/java $JAVA_OPTS -jar \
    -Dlog.path=${PROJECT_LOG} \
    -Dlog.level=${PROJECT_LOG_LEVEL} \
    -Djava.security.egd=file:/dev/./urandom $BUILD_FILE \
    -DSERVICE_NAME=$SERVICE_NAME \
    --spring.profiles.active=$ACTIVE_PROFILE > run.log &

  sleep 10

  PID=`ps -ef|grep $SERVICE_NAME|grep -v "grep"|grep java|awk '{print $2}'`
  PID_Num=`ps -ef|grep $SERVICE_NAME|grep -v "grep"|grep java|awk '{print $2}'|wc -l`
  if [ $PID_Num -eq 0 ];then
    echo "== $SERVICE_NAME is not running"
  else
    echo "== $SERVICE_NAME ($PID) is running"
  fi
}

function stop() {
  echo "== Stopping $SERVICE_NAME"
  PID=`ps -ef|grep $SERVICE_NAME|grep -v grep|grep java|awk '{print $2}'`
  PID_Num=`ps -ef|grep $SERVICE_NAME|grep -v grep|grep java|awk '{print $2}'|wc -l`
  if [ $PID_Num -eq 0 ];then
    echo "== $SERVICE_NAME is not running"
  else
    echo "== $SERVICE_NAME is running ($PID)"
    `ps -ef|grep $SERVICE_NAME|grep java|grep -v grep|awk '{print $2}'|xargs -I{} kill -9 {}`
    echo "== killed process: $PID"
  fi
}

function status() {
  PID=`ps -ef|grep $SERVICE_NAME|grep -v "grep"|grep java|awk '{print $2}'`
  PID_Num=`ps -ef|grep $SERVICE_NAME|grep -v "grep"|grep java|awk '{print $2}'|wc -l`
  if [ $PID_Num -gt 0 ];then
    echo "== $SERVICE_NAME ($PID) is running..."
  else
    echo "== $SERVICE_NAME is not running"
  fi
}

case $1 in
  start)
    start
    ;;

  stop)
    stop
    ;;

  status)
    status
    ;;

  restart)
    stop
    start
    ;;

  *)
    echo -e "Usage $0 { start | stop | restart | status }"
    ;;
esac
