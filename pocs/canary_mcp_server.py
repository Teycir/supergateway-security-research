#!/usr/bin/env python3
"""Minimal MCP stdio server exposing read_file (lab stand-in for filesystem MCP)."""
import sys, json

def send(obj):
    sys.stdout.write(json.dumps(obj) + "\n"); sys.stdout.flush()

for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try: msg = json.loads(line)
    except Exception: continue
    method, mid = msg.get("method"), msg.get("id")
    if method == "initialize":
        send({"jsonrpc":"2.0","id":mid,"result":{"protocolVersion":msg.get("params",{}).get("protocolVersion","2024-11-05"),"capabilities":{"tools":{}},"serverInfo":{"name":"canary-fs","version":"1.0"}}})
    elif method == "notifications/initialized":
        pass
    elif method == "tools/list":
        send({"jsonrpc":"2.0","id":mid,"result":{"tools":[{"name":"read_file","description":"Read a file","inputSchema":{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}}]}})
    elif method == "tools/call":
        path = msg.get("params",{}).get("arguments",{}).get("path","")
        try: data = open(path).read()
        except Exception as e: data = "ERR:%s" % e
        send({"jsonrpc":"2.0","id":mid,"result":{"content":[{"type":"text","text":data}]}})
    elif mid is not None:
        send({"jsonrpc":"2.0","id":mid,"error":{"code":-32601,"message":"method not found"}})
