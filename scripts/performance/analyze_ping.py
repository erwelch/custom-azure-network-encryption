import re
import collections

pattern = "[^\|]+\| Ping ([^-]+)->([^\s]+)\s*\| ([0-9]+)/([0-9]+) packets"

total_map = collections.defaultdict(dict)
received_map = collections.defaultdict(dict)

ips = set()
i = 0
with open("ping.log", "rt") as f:
    for line in f.readlines():
        data = re.findall(pattern, line)

        if data[0][0] not in total_map or data[0][1] not in total_map[data[0][0]]:
            total_map[data[0][0]][data[0][1]] = 0

        if data[0][0] not in received_map or data[0][1] not in received_map[data[0][0]]:
            received_map[data[0][0]][data[0][1]] = 0

        total_map[data[0][0]][data[0][1]] += 1
        if int(data[0][2]) != 0:
            received_map[data[0][0]][data[0][1]] += int(data[0][2])
        ips.add(data[0][0])
        ips.add(data[0][1])

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
            line += "," + str(received_map[ip1][ip2])
        else:
            line += ",-1"
    line += "\n"
    lines.append(line)

with open("ping_result.csv", "wt") as f:
    f.writelines(lines)

# for ip1 in total_map.keys():
#     for ip2 in total_map[ip1].keys():
#         if total_map[ip1][ip2] == 0:
#             print(ip1, ip2)
#         if retry_map[ip1][ip2] == 0:
#             print("Retries:", ip1, ip2)