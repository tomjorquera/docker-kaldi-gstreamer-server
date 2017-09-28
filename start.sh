#!/bin/bash

MASTER="localhost"
PORT=80

usage(){
  echo "Creates a worker and connects it to a master.";
  echo "If the master address is not given, a master will be created at localhost:80";
  echo "Usage: $0 -y yaml_file [-m master address] [-p port number]";
}

while getopts "h?m:p:y:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    m)  MASTER=$OPTARG
        ;;
    p)  PORT=$OPTARG
        ;;
    y)  YAML=$OPTARG
        ;;
    esac
done

#yaml file must be specified
if [ "$YAML" == "" ] ; then
  usage;
  exit 1;
fi;

# we expect a certain number of files to be referenced in the yaml
# and those files to exist at the referenced paths

check-file()
{
  FILE=$(grep $1: $YAML | awk '{print $2}');
  if [ "$FILE" == "" ]; then
      echo "Missing $1 in $YAML"
      return 2
  elif [ ! -f $FILE ]; then
      echo "Wrong $1 path $FILE in $YAML"
      return 3
  fi
}

if [ -f $YAML ]; then
    for file in "model" "lda-mat" "word-syms" "fst"; do
        check-file $file
        error=$?
        if [ $error -ne 0 ]; then
            exit $error
        fi
    done
else
    echo "The $YAML file doesn't exist"
    exit 1
fi

# everything is good

if [ "$MASTER" == "localhost" ] ; then
  # start a local master
  python /opt/kaldi-gstreamer-server/kaldigstserver/master_server.py --port=$PORT &
fi

export GST_PLUGIN_PATH=/opt/gst-kaldi-nnet2-online/src/:/opt/kaldi/src/gst-plugin/

NB_WORKERS=${NB_WORKERS:-1}
for i in $(seq 1 $NB_WORKERS)
do
    #start worker and connect it to the master
    python /opt/kaldi-gstreamer-server/kaldigstserver/worker.py -c $YAML -u ws://$MASTER:$PORT/worker/ws/speech &
done

sleep infinity
