ip_filename=$1

function iperf_test(){
    result_filename=/var/log/iperf_result.txt

    ip=$(host $(hostname) | cut -d ' ' -f 4)
    port=$(expr 50000 + $(echo $((36#$(hostname | cut -d '-' -f 2)))))
    data=$(iperf3 -c $1 -p $port -t $2 | grep sender)

    transfer=$(echo $data | cut -d ' ' -f 5,6)
    bandwidth=$(echo $data | cut -d ' ' -f 7,8)
    retry=$(echo $data | cut -d ' ' -f 9)
    echo -e $(date +"%T.%6N")' | '$ip'->'$1':'$port'\t| Transfer: '$transfer'\t| Bandwidth: '$bandwidth'\t| Retry: '$retry'\t|' >> $result_filename
}
export -f iperf_test

time=15

while true; do
    /usr/local/bin/parallel -j3 iperf_test ::: $(shuf -n 99 $ip_filename) ::: $time
done