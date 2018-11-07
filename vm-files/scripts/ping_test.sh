ip_filename=$1

function test_host(){
    result_filename=/var/log/ping_result.txt

    ip=$(host $(hostname) | cut -d ' ' -f 4)
    received=$(ping -c $2 $1 | grep received | cut -d ' ' -f 4)
    echo $(printf '%s | Ping %s->%s | %d/%d packets' $(date +"%T.%N") $ip $1 $received $2) >> $result_filename
    return $(expr $received)
}

send=15

export -f test_host

while true; do
    /usr/local/bin/parallel -j20 test_host ::: $(shuf -n 99 $ip_filename) ::: $send
done