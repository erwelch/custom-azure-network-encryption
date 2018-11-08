import iperf3
import threading

lock = threading.Lock()
results = []

def run_single_test(hostname, port, duration):
    client = iperf3.Client()
    client.duration = duration
    client.server_hostname = hostname
    client.port = port
    result = client.run()
    with lock:
        results.append("%s %d %d %f", hostname, port, duration, result.sent_Mbps)
    return

#max_workers = 5

ips = ["10.0.0.1", "10.0.0.3"]

threads = []
for ip in ips:
    t = threading.Thread(target=run_single_test, args = (ip, 5003, 10))
    threads.append(t)
    t.start()
    t.join()

for x in threads:
    x.join()

print(results)
