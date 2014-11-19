#!/bin/bash

YCSB_HOME=/scratch/Confluence/modelCheckingYCSB/YCSB

usage()
{
  echo "usage: $1 -n numnode -h hosts [-l (load data) | -t (run test)]"
  exit -1
}

get_hosts()
{
  hosts=$(
    for (( i = 0; i < $numnode; i++)); do
      ssh sonnbc@node-0$i.riak.confluence.emulab.net -C "
        ifconfig | grep 10\.1\.1 | tr ':' ' ' | awk '{print \$3}'
      "
    done | tr "\\n" ",")
  echo $hosts
}

load()
{
  echo "Load $numnode"

  echo $hosts
  ssh sonnbc@node-00.riak.confluence.emulab.net -C "
    java -cp $YCSB_HOME/core/target/*:$YCSB_HOME/lib/*:$YCSB_HOME/cassandra/target/cassandra-binding-0.1.4.jar \
    com.yahoo.ycsb.Client -load -db com.yahoo.ycsb.db.CassandraClient10 \
    -p cassandra.writeconsistencylevel=QUORUM -p cassandra.readconsistencylevel=QUORUM \
    -P $YCSB_HOME/workloads/modelCheckingWorkload -threads 1\
    -p hosts=\"$hosts\"
  "
}

run_test()
{
  echo "Run test $numnode"

  for (( i = 0; i < 1; i++)); do #TODO: change back to numnode
    ssh sonnbc@node-0$i.riak.confluence.emulab.net -C "
      java -cp $YCSB_HOME/core/target/*:$YCSB_HOME/lib/*:$YCSB_HOME/cassandra/target/cassandra-binding-0.1.4.jar \
      com.yahoo.ycsb.Client -t -db com.yahoo.ycsb.db.CassandraClient10 \
      -p cassandra.writeconsistencylevel=QUORUM -p cassandra.readconsistencylevel=QUORUM \
      -P $YCSB_HOME/workloads/modelCheckingWorkload -threads 50 \
      -p hosts=\"$hosts\"
    " 2> node-0$i.log &
  done

  wait

  cat node-0*.log
  #rm node-0*.log
}

while getopts "ltn:" opt; do
  case "$opt" in
    l) action='load';;
    t) action='run_test';;
    n) numnode=$OPTARG;;
  esac
done

if [ -z "$numnode" ] || [ -z "$action" ]; then
    usage $0
fi

hosts=$(get_hosts)

$action
