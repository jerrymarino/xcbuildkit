#!/usr/local/bin/python3

import msgpack
import service
import sys
import fcntl
import os
import time

import datetime

global log_file
global log_path


if len(sys.argv) > 1:
    log_path = sys.argv[1]
else:
    log_path = "/tmp/xcbuild.diags"

log_file = None


def unpack(unpacker, data=[]):
    state = unpacker.tell()
    log("AT", state)
    try:
        obj = unpacker.unpack()
        log(obj)
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



def log(*args, **kwargs):
    global log_file
    global log_path

    now = datetime.datetime.now()
    if log_file == None:
        log_file = open(log_path,"w", 512) 
    log_file.write(str(now) + " INFO: "+" ".join(map(str,args))+"\n", **kwargs)


def dump_protocol(path, sanitize=False):
    global log_path
    log_path = path + ".diags"
    data_file = open(path, 'rb')
    data = data_file.read()
    log("Data:", data)
    unpacker = service.get_unpacker()
    unpacker.feed(data)
    if sanitize:
        data = service.sanitize(data)

    while True:
        if not unpack(unpacker, data):
            return

def loop():
    global log_file
    log("Start")
    unpacker = service.get_unpacker()
    buff = None
    last_byte = None
    byte = None
    i = 0
    while True:
        last_byte = byte
        byte = sys.stdin.buffer.read(1)
        log_file.flush()
        if not byte:
            i = i + 1
            if i > 10:
                log("Waiting")
                time.sleep(2.0)
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
            unpacker = service.get_unpacker()

orig_fl = fcntl.fcntl(sys.stdin, fcntl.F_GETFL)
fcntl.fcntl(sys.stdin, fcntl.F_SETFL, orig_fl | os.O_NONBLOCK)
loop()

