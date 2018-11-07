prefix=$(hostname | cut -d '-' -f 1)
ip_filename=cluster-ips.txt
rm -f $ip_filename

sleep 5m

hosts_found=0

function decimal_to_base36(){
    BASE36=($(echo {0..9} {A..Z}));
    arg1=$@;
    for i in $(bc <<< "obase=36; $arg1"); do
    echo -n ${BASE36[$(( 10#$i ))]}
    done && echo
}

pattern=000000

for i in $(seq 0 200); do 
    iperf3 -s -p $(expr 50000 + $i) -D
done

while [ $hosts_found != 100 ]; do
    hosts_found=0
    for i in $(seq 0 200); do 
        b36num=$(decimal_to_base36 $i)
        aligned=$(echo "${pattern:0:-${#b36num}}$b36num")
        handle=$(printf '%s-%s' $prefix $aligned)
        host=$(host $handle)
        result=$?
        if [ $result -eq 0 ]; then
            hosts_found=$(expr $hosts_found + 1)
        fi
    done
done

for i in $(seq 0 200); do 
    b36num=$(decimal_to_base36 $i)
    aligned=$(echo "${pattern:0:-${#b36num}}$b36num")
    handle=$(printf '%s-%s' $prefix $aligned)
    if [ "$handle" == "$(hostname)" ]; then
        continue
    fi

    host=$(host $handle)
    result=$?
    if [ $result -eq 0 ]; then
        ip=$(echo $host | cut -d ' ' -f 4)
        echo $ip >> $ip_filename
    fi
done

bash scripts/ping_test.sh $ip_filename &
bash scripts/iperf_test.sh $ip_filename &