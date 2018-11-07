ip=40.121.71.110
ports=($(seq 50000 1 50130))

cd logs_no_ipsec

function download_logs(){
    echo "Loading logs from" $1 $2

    scp -P $2 -i ~/.ssh/id_rsa erwelch@$1:/var/log/iperf_result.txt iperf_result_$2.txt & 
    scp -P $2 -i ~/.ssh/id_rsa erwelch@$1:/var/log/ping_result.txt ping_result_$2.txt & 
    wait
}
export -f download_logs

echo ${ports[*]}

/home/erwelch/bin/parallel -j20 download_logs ::: $ip ::: ${ports[*]}

cat iperf_*.txt | sort >  iperf.log
cat ping_*.txt | sort > ping.log

rm -f iperf_*.txt
rm -f ping_*.txt
