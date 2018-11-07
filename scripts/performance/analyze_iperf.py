import re
import collections

pattern = "[^\|]+\|\s([^-]+)->([^\s\:]+):([^\s]+)\s+\|\s*Transfer:\s*([^\|\t]+)?\s*\|\s*Bandwidth:\s*([^\|\t]+)?\s*\|\s*Retry:\s*([^\|\t]+)?\s*\|"

total_map = collections.defaultdict(dict)
retry_map = collections.defaultdict(dict)

ips = set()

with open("iperf.log", "rt") as f:
    for line in f.readlines():
        data = re.findall(pattern, line)
#        print(re.findall(pattern, line))
        if data[0][0] not in total_map or data[0][1] not in total_map[data[0][0]]:
            total_map[data[0][0]][data[0][1]] = 0

        if data[0][0] not in retry_map or data[0][1] not in retry_map[data[0][0]]:
            retry_map[data[0][0]][data[0][1]] = 0

        total_map[data[0][0]][data[0][1]] += 1
        if data[0][5] != '':
            retry_map[data[0][0]][data[0][1]] += int(data[0][5])
        ips.add(data[0][0])
        ips.add(data[0][1])

#print(total_map)

print(len(ips))
print(sorted(ips))

print(len(total_map.keys()))

lines = []

line = "target"
for ip in sorted(ips):
    line += "," + ip
line += "\n"
lines.append(line)

for ip1 in sorted(ips):
    line = ip1
    for ip2 in sorted(ips):
        if ip1 in total_map and ip2 in total_map[ip1]:
            line += "," + str(retry_map[ip1][ip2] / total_map[ip1][ip2])
        else:
            line += ",-1"
    line += "\n"
    lines.append(line)

with open("result.csv", "wt") as f:
    f.writelines(lines)

# for ip1 in total_map.keys():
#     for ip2 in total_map[ip1].keys():
#         if total_map[ip1][ip2] == 0:
#             print(ip1, ip2)
#         if retry_map[ip1][ip2] == 0:
#             print("Retries:", ip1, ip2)
