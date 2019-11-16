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

global log_file
log_file = open("/tmp/xcbuild.diags","w", 512) 

def log(*args, **kwargs):
    log_file.write("INFO: "+" ".join(map(str,args))+"\n", **kwargs)

class MessageContext:
    def __init__(self):
        self.packer = msgpack.Packer()
        self.buff = io.BytesIO()
        self.did_write = False

    def write(self, obj):
        data = self.packer.pack(obj)
        self.buff.write(data)
        log("write", data)
        self.did_write = True

    def writeb(self, obj):
        self.buff.write(obj)
        log("writeb", obj)
        self.did_write = True

    def dump(self):
        log("Dump", self.buff.getvalue())
        with os.fdopen(sys.stdout.fileno(), "wb", closefd=False) as stdout:
            stdout.write(self.buff.getvalue())
            stdout.flush()

        log("AfterDump", self.buff.getvalue())

    def end(self, offset):
        if offset == 1:
           return
        self.write(offset)

    def inspect(self):
        print(self.buff.getvalue())

def handle_obj(obj, unpacker):
    ctx = MessageContext()
    log("OBJ", obj)
    if obj == 1:
        return True
    elif obj == [0] or obj == 32:
        log("Skipping")
    elif obj == "CREATE_SESSION":
        # '\x01\x00\x00\x00\x00\x00\x00\x00\x0b\x00\x00\x00\xa6STRING\x91\xa2S0\x02\x00\x00\x00\x00\x00\x00\x00\x9b\x00\x00\x00\
        # This string with the gap in it noops behavior for the first transfer PIF request
        ctx.writeb(b"\x01\x00\x00\x00\x00\x00\x00\x00\x0b\x00\x00\x00\xa6STRING\x91\xa2S0\x02\x00\x00\x00\x00\x00\x00\x00 \x00\x00\x00")
        ctx.dump()
    elif obj == "TRANSFER_SESSION_PIF_REQUEST":
        # Sometimes:
	# Note: the result here is different depending on how we create the session
        # info = unpacker.unpack()
        ctx.writeb(b"\xbdTRANSFER_SESSION_PIF_RESPONSE\x91\x90\x03")
        ctx.dump()
    elif obj == "SET_SESSION_SYSTEM_INFO":
        info = unpacker.unpack()
        minor_version = unpacker.unpack()
        version_hash = unpacker.unpack()
        arch = unpacker.unpack()
        log("Info", info, minor_version, version_hash, arch)

        ctx = MessageContext()
        ctx.writeb(b'\x00\x00\x00\x00\x00\x00\x00')
        msg = ctx.packer.pack("PING")
        msg += ctx.packer.pack(None)
        ctx.write(len(msg))
        ctx.writeb(b'\x00\x00\x00')
        ctx.writeb(msg)
        ctx.dump()
        # ctx.write(  b"\x00\x00\x00\x00\x06\x00\x00\x00\xa4PING\xc0\x04\x00\x00\x00\x00")
        # 11 Beta 2
        # ctx.writeb(b"\x00\x00\x00\x00\x07\x00\x00\x00\xa4BOOL\x91\xc3\x04\x00\x00\x00")
    elif obj == "SET_SESSION_USER_INFO":
        info  = unpacker.unpack()
        ctx = MessageContext()
        log("SET_SESSION_USER_INFO Info", info)
        ctx = MessageContext()
        ctx.writeb(b"\x04\x00\x00\x00\x00\x00\x00\x00\x06\x00\x00\x00\xa4PING\xc0\x06\x00\x00\x00\x00\x00\x00\x00\x18")
        ctx.dump()
    elif obj == "CREATE_BUILD":
        info = unpacker.unpack()
        # It seems to take the session ID from here
        # as all messages for the build are proceeded with this ID
        #session_id = info[1]
        ctx = MessageContext()
        ctx.writeb(b'\x00\x00\x00\x00\x00\x00\x00')
        msg = ctx.packer.pack("BUILD_CREATED")
        msg += ctx.packer.pack([0])
        msg += ctx.packer.pack(7)
        msg += '\x00\x00\x00'
        msg += '\x00\x00\x00'
        msg += ctx.packer.pack(0)
        msg += ctx.packer.pack(7)

        ctx.write(len(msg))
        ctx.writeb(b'\x00\x00\x00')
        ctx.writeb(msg)
        ctx.dump()

        ctx.dump()
    elif obj == "BUILD_START":
        info = unpacker.unpack()
        log("BUILD_START Info", info)
        ctx.writeb(b"\x00\x00\x00\x00\x00\x00\x00\x07\x00\x00\x00\xa4BOOL\x91\xc3\x05")
        ctx.dump()

        # After the build has started, the build system is in control of the
        # entire process
        ctx = MessageContext()
        ctx.writeb(b'\x00\x00\x00\x00\x00\x00\x00H\x00\x00\x00\xbdPLANNING_OPERATION_WILL_START\x92\xa2S0\xd9$FC5F5C50-8B9C-43D6-8F5A-031E967F5CC0\x05')
        ctx.dump()

        # Example of using msgpack to write BUILD_PROGRESS_UPDATED messages.
        ctx = MessageContext()
        # Start with padding
        ctx.writeb(b'\x00\x00\x00\x00\x00\x00\x00')
        msg = ctx.packer.pack("BUILD_PROGRESS_UPDATED")
        msg += ctx.packer.pack([None, "Getting that inspiration'", -1.0, True])

        # This the len of the message is written prior to the data type
        ctx.write(len(msg))
        ctx.writeb(b'\x00\x00\x00')
        ctx.writeb(msg)
        ctx.write(False)
        ctx.dump()

        # The above code produces the same output
        #ctx = MessageContext()
        #ctx.writeb(b'\x00\x00\x00\x00\x00\x00\x002\x00\x00\x00\xb6BUILD_PROGRESS_UPDATED\x94\xc0\xaeInspiration...\xcb\xbf\xf0\x00\x00\x00\x00\x00\x00\xc3\xc2')
        #ctx.dump()

        time.sleep(2)
        ctx = MessageContext()
        ctx.writeb(b'\x00\x00\x00\x00\x00\x00\x00F\x00\x00\x00\xbbPLANNING_OPERATION_FINISHED\x92\xa2S0\xd9$FC5F5C50-8B9C-43D6-8F5A-031E967F5CC0\x05')
        ctx.dump()

        #ctx = MessageContext()
        #ctx.writeb(b'\x00\x00\x00\x00\x00\x00\x00F\x00\x00\x00\xb6BUILD_PROGRESS_UPDATED\x94\xc0\xd9!to create a life you love ;)     \xcb\xbf\xf0\x00\x00\x00\x00\x00\x00\xc3\x05')
        #ctx.dump()
        #time.sleep(2)
    
        ctx = MessageContext()
        ctx.writeb(b'\x00\x00\x00\x00\x00\x00\x00\x1d\x00\x00\x00\xbbBUILD_PREPARATION_COMPLETED\xc0\x05\x00\x00\x00\x00\x00\x00\x00"')
        ctx.dump()

        ctx = MessageContext()
        ctx.writeb(b'\x00\x00\x00\xb7BUILD_OPERATION_STARTED\x91\xd3')
        ctx.dump()

        ctx = MessageContext()
        ctx.writeb(b'\x00\x00\x00\x00\x00\x00\x00\x00\x05\x00\x00\x00\x00\x00\x00\x00#\x00\x00\x00\xbfBUILD_OPERATION_REPORT_PATH_MAP\x92\x80\x80\x05\x00\x00\x00\x00\x00\x00\x00Y\x00\x00\x00\xb5BUILD_TARGET_UPTODATE\x91\xd9@86b383703cee5911294a732c1f582133a6b8608e8d79fa8addd22be62fee6ac8\x05\x00\x00\x00\x00\x00\x00\x00*\x00\x00\x00\xb5BUILD_OPERATION_ENDED\x93\xd3\x00\x00\x00\x00\x00\x00\x00\x00\xd3\x00\x00\x00\x00\x00\x00\x00\x00\xc0')
        ctx.dump()

        sys.exit(0)

    log("Ended", ctx.did_write)

def unpack(unpacker, data=[]):
    state = unpacker.tell()
    log("AT", state)
    try:
        obj = unpacker.unpack()
        #log(obj)
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


def ext_hook(self, code, data):
    service.log("ext_hook", code, data)
    return msgpack.ExtType(code, data)


def get_unpacker():
    unpacker = msgpack.Unpacker(use_list=True, read_size=1024*1024, raw=False,
            max_buffer_size=1024*1024*1024,
            ext_hook=ext_hook, unicode_errors="ignore")
    return unpacker


# Read stdin byte by byte and defer to msgpack unpacker to handle unpacking
def loop():
    global log_file
    log("Start")
    unpacker = get_unpacker()
    buff = None
    byte = None
    i = 0
    while True:
        byte = sys.stdin.buffer.read(1)
        log_file.flush()
        if not byte:
            i = i + 1
            if i > 10:
                log("Waiting")
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
    orig_fl = fcntl.fcntl(sys.stdin, fcntl.F_GETFL)
    fcntl.fcntl(sys.stdin, fcntl.F_SETFL, orig_fl | os.O_NONBLOCK)
    log("START")
    loop()
    

if __name__ == "__main__":
    main()
