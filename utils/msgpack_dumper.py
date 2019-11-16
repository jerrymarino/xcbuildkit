#!/usr/local/bin/python3
# This program is a stand-in for XCBBuildService and replays responses
# Really, it's used for prototyping only

# Note: tested on Python 3.7.3 with 
# pip3 install pyyaml 
# ( PyYAML     5.1.2 )
import msgpack
import sys
import io
import os
import time
import select
import fcntl


def log(*args, **kwargs):
    print("INFO: "+" ".join(map(str,args))+"\n", **kwargs)

def handle_obj(obj, unpacker):
    log("OBJ", obj)

def unpack(unpacker, data=[]):
    state = unpacker.tell()
    log("AT", state)
    try:
        obj = unpacker.unpack()
        log(obj)
        handle_obj(obj, unpacker)
    except msgpack.exceptions.OutOfData as inst:
        # Handle when the file is done
        log("Done")
        return False
    except msgpack.exceptions.StackError  as inst:
        log("StackError", state)
        log("Err", inst)
    except Exception as inst:
        log("Except-state", state)
        log("At", data[state:state+400])
        log("Err", inst)
        try:
            unpacker.skip()
        except:
            pass
    return True


def ext_hook(code, data):
    log("ext_hook", code)
    if code == -1:
        if len(data) == 4:
            secs = int.from_bytes(data, byteorder='big', signed=True)
            nsecs = 0;
        elif len(data) == 8:
            data = int.from_bytes(data, byteorder='big', signed=False)
            secs = data & 0x00000003ffffffff;
            nsecs = data >> 34;
        elif len(data) == 12:
            import struct

            nsecs, secs = struct.unpack('!Iq', data)
        else:
            raise AssertionError("Not reached");

        return datetime.datetime.utcfromtimestamp(secs + nsecs / 1e9)

    else:
        return msgpack.ExtType(code, data)

def get_unpacker():
    unpacker = msgpack.Unpacker(use_list=True, read_size=1024*1024, raw=False,
            strict_map_key=True, max_buffer_size=1024*1024*1024,
            ext_hook=ext_hook)
    return unpacker


# Read stdin byte by byte and defer to msgpack unpacker to handle unpacking
def loop():
    log("Start")
    unpacker = get_unpacker()
    buff = None
    byte = None
    i = 0
    while True:
        byte = sys.stdin.buffer.read(1)
        if not byte:
            i = i + 1
            if i > 10:
                sys.exit(0)
                time.sleep(1.0)
        else:
            i = 0
        if not buff:
            buff = byte
        if byte:
            buff += byte
        if (not byte or byte == b'') and buff:
            unpacker.feed(buff)
            while unpack(unpacker, buff):
                log("Pack")
            buff = None
            byte = None
            unpacker = get_unpacker()


def read_all():
    while True:
        data = sys.stdin.buffer.read()
        log("Read all")
        log("Data", data)
        unpacker = get_unpacker()
        unpacker.feed(data)
        while True:
            if not unpack(unpacker, data):
                return

def main():
    print("Start")
    orig_fl = fcntl.fcntl(sys.stdin, fcntl.F_GETFL)
    fcntl.fcntl(sys.stdin, fcntl.F_SETFL, orig_fl | os.O_NONBLOCK)
    log("START")
    loop()
    

if __name__ == "__main__":
    main()
