#!/usr/local/bin/python3
import sys

def load(path):
    print(open(path, "rb").read())
    return str(open(path, "rb").read()).split("\\")

a_path = sys.argv[1]
b_path = sys.argv[2]
a = load(a_path)
b = load(b_path)

for i in range(0, max(len(a), len(b))):
    print("i", i)
    print("A", a_path, a[i])
    print("B", b_path, b[i])

    if len(a) <= i or len(b) <= i:
        print("Len:OffAt", i)
        break

    if a[i] != b[i]:
        print("OffAt", i)

        print("A", a_path, a[i-10:i+10])
        print("B", b_path, b[i-10:i+10])
        break

