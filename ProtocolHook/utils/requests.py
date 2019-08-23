# Notes on logical requests early on
# The following is notes and unused
# Xcode request
# "CREATE_SESSION"
# ("<IDEWorkspace:0x7faba636fc10 path:'/Users/jerrymarino/Projects/IDEXCBProgress/ProtocolHook/iOSApp/iOSApp.xcodeproj/project.xcworkspace'>",
# '/Users/jerrymarino/Desktop/Xcode-Beta.app',
# '/Users/jerrymarino/Library/Developer/Xcode/DerivedData/iOSApp-dxsndsmbfrlanxbfeqoqjilvoreh/Build/Intermediates.noindex/XCBuildData',
# None)

# Guess responds
# INFO: STRING
# INFO: ('S0',)


# Xcode request
# "TRANSFER_SESSION_PIF_REQUEST"
#('S0',
#'WORKSPACE@v11_mod=1566239258_hash=b0a9948cd55a526ac9a523f755c20044_subobjects=2AD9319417C9718C14F457346E71E0B4') 

# Guess responds
# INFO: AT 35
# INFO: TRANSFER_SESSION_PIF_RESPONSE
# INFO: ((),)


# Xcode request
# "SET_SESSION_SYSTEM_INFO"
# This has data proceeding it
# ('S0', 10, 14)
# 5
# 18F132
# x86_64h
# 4

# Xcode request
# Guess responds
# INFO: AT 79
# INFO: BOOL
# INFO: (True,)


# Xcode request
# SET_SESSION_USER_INFO
# This is bascially the env and a ton of extra info

# Guess responds
# INFO: AT 98
# INFO: BOOL
# INFO: (True,)


# Xcode request
# "CREATE_BUILD"
# ('S0', 5, (('clean', None, None, None, None, ({'ACTION': 'clean', 'COLOR_DIAGNOSTICS': 'YES', 'ENABLE_PREVIEWS': 'NO', 'diagnostic_message_length': '208'}, {'SDKROOT': 'iphonesimulator13.0'}, {}, {}, None), None), (('86b383703cee5911294a732c1f58213307cc8d7a3ea25dc2e041fef4554fafd5', None),), False, False, False, False, False, True, None, 5, 0, None, True, False))

# Guess responds
# INFO: AT 117
# INFO: BUILD_CREATED
# INFO: (0,)

# Xcode request
# "BUILD_START"
# ('S0', 0)


# Guess responds
# INFO: AT 153
# INFO: BOOL
# INFO: AT 158
# INFO: (True,)


# Xcode request
# "CREATE_BUILD"
# INFO: ('S0', 8, (('build', None, None, None, None, ({'ACTION': 'build', 'COLOR_DIAGNOSTICS': 'YES', 'ENABLE_PREVIEWS': 'NO', 'diagnostic_message_length': '208'}, {'SDKROOT': 'iphonesimulator13.0'}, {}, {}, None), None), (('86b383703cee5911294a732c1f58213307cc8d7a3ea25dc2e041fef4554fafd5', None),), False, False, False, False, False, True, None, 0, 0, None, False, False))

# Xcode request
# INFO: BUILD_START
# INFO: AT 5652
# INFO: ('S0', 1)

# Build only

# Service Request
# INFO: PLANNING_OPERATION_WILL_START
# INFO: AT 202
#I NFO: ('S0', '2871546D-49B0-42FF-8499-A851C8B6D3BE')
#I NFO: AT 244
# INFO: 5

# Xcode Response
# INFO: PROVISIONING_TASK_INPUTS_RESPONSE
# INFO: AT 5361
#INFO: ('S0', '2871546D-49B0-42FF-8499-A851C8B6D3BE', '3680FA3C-3FDE-46D9-BCEB-F2FC35969A63', '-', '-', None, None, None, None, b'bplist00\xd1\x01\x02_\x10!com.apple.security.get-task-allow\t\x08\x0b/\x00\x00\x00\x00\x00\x00\x01\x01\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x000', b'bplist00\xd2\x01\x02\x03\x04_\x10\x16application-identifier_\x10\x16keychain-access-groups_\x10"$(AppIdentifierPrefix)jerry.iOSApp\xa1\x03\x08\r&?d\x00\x00\x00\x00\x00\x00\x01\x01\x00\x00\x00\x00\x00\x00\x00\x05\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00f', 'HWZFLG9PNK.', 'HWZFLG9PNK.', None, (), ())
#INFO: AT 5704
#INFO: Done


# Build system responses
def write_string_res(ctx=MessageContext()):
    """
    expect: b'\xa6STRING\x91\xa2S0'
    """
    ctx.write(b"STRING")
    ctx.write([b"S0"])


def write_transfer_session_pif_response(ctx=MessageContext()):
    #ctx.write(b'\275TRANSFER_SESSION_PIF_RESPONSE\221\220\0')
    # Immediately after, a bool is sent
    # Then another bool is sent
    ctx.write(b'TRANSFER_SESSION_PIF_RESPONSE')
    ctx.write([(),])

def write_empty(ctx):
    ctx.writeb(b"\x00")


def write_bool_res(ctx=MessageContext()):
    """
    note: often the bool response is followed by a number
    expect: b'\xa4BOOL\x91\xc3'
    """
    #ctx.write(b"\x00\x00\x00\xa4BOOL\x91\xc3")
    ctx.write(b"BOOL")
    ctx.write([True,])

def write_build_created_res(ctx=MessageContext()):
    ctx.write(0)
    ctx.write(b"BUILD_CREATED")
    ctx.write((0,))


def write_planning_will_start_res(ctx=MessageContext()):
    ctx.writeb(b"\x00")
    ctx.write(b"PLANNING_OPERATION_WILL_START")
    ctx.write(('S0', '2871546D-49B0-42FF-8499-A851C8B6D3BE'))


def write_planning_finished_res(ctx=MessageContext()):
    ctx.writeb(b"\x00")
    ctx.write(b"PLANNING_OPERATION_FINISHED")
    ctx.write(('S0', '2871546D-49B0-42FF-8499-A851C8B6D3BE'))

def write_build_progress_updated_res(ctx=MessageContext()):
    ctx.writeb(b"\x00")
    ctx.write(b"BUILD_PROGRESS_UPDATED")
    ctx.write((None, 'Planning build', -1.0, True))

# build system requests

def write_get_provisioning_task_inputs_req(ctx):
    ctx.writeb(b"\x00")
    ctx.write(b"GET_PROVISIONING_TASK_INPUTS_REQUEST")
    # Note: The next data is determined by session info


# Note: This is really bad and isn't useful for anything
# Trying to parse the raw data as msgpack fails
# When faced with parsing raw input from clang, the msgpack parser explodes
def sanitize(data):
    data = data.replace(b'\xd9',b'')
    data = data.replace(b'\xb8',b'')
    data = data.replace(b'\xb2',b'')
    data = data.replace(b'\x94',b'')
    data = data.replace(b'\xd3',b'')
    #data = data.replace(b'\xbc',b'')
    #data = data.replace(b'\xd9',b'')
    return data

def end_handle(obj, ctx, close_id, terminate, unpacker):
    if ctx.did_write:
        log("Close", close_id)
        if not close_id:
            try:
                offset = unpacker.unpack()
                ctx.end(offset)
                ctx.write(0)
                ctx.write(0)
            except:
                pass
        else:
            ctx.end(close_id)
            ctx.write(0)
            ctx.write(0)
            ctx.write(0)
        # Ispect what was written to the ctx
        #ctx.inspect()
        ctx.dump()
        log("DidDump")



