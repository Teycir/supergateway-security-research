# Vulnerabilities explained in simple terms

This document explains the two supergateway findings (SGW-2026-001 and SGW-2026-002) without jargon, plus how each attack works step by step.

## What supergateway does

Supergateway is a bridge. You run a local program (an MCP server) that can do things like read files, run shell commands, or query databases. Supergateway exposes that local program over HTTP/WebSockets so an AI assistant can remote-control it.

By default it listens on the network and does **not** require a password unless you manually turn on `--apiKey`.

---

## SGW-2026-001 — Crash the gateway with a magic word

### The bug (simple version)

In one mode (SSE), supergateway keeps track of active connections in a simple dictionary keyed by a session ID that the client sends in the web address.

JavaScript dictionaries come with built-in words you can't delete: `toString`, `constructor`, `__proto__`, `hasOwnProperty`, `valueOf`, and others. Because the code never checks whether the session ID is a *real* session or just one of these built-in words, asking for `sessionId=toString` returns something truthy that looks like a session but isn't.

The code then tries to use that fake session to deliver a message, hits `nothing`, throws an error, and because there is no safety net, **the whole program exits**.

### The attack path (step by step)

1. The attacker finds a supergateway instance running (default port, reachable on the network).
2. The attacker sends a single web request: `POST /message?sessionId=toString`
3. No login, no existing session, no special headers needed.
4. The gateway immediately crashes. Every connected AI session dies, and every local program it was bridging dies with it.

### What the attacker gets

Total denial of service. One packet kills the service and everything attached to it.

### Simple analogy

It's like a receptionist who keeps appointments in a notebook. If you ask for the appointment listed under the word "Index" (pre-printed on every page), she looks at it, gets confused, panics, and locks the front door, sending everyone home.

### Simple defense

- Turn on `--apiKey` (the crash only works without authentication).
- Bind supergateway to `127.0.0.1` only so outsiders can't reach it.

---

## SGW-2026-002 — A malicious website remote-controls your local tools

### The bug (simple version)

In WebSocket mode, supergateway accepts incoming connections from **any** website. It does not check the `Origin` header, and it does not require a password by default.

WebSockets are special: browsers let them cross the normal "same-origin" wall. That means a page on `evil.com` can open a raw connection to `ws://127.0.0.1:<port>/ws` on your own computer, and supergateway will accept it.

### The attack path (step by step)

1. The victim runs supergateway locally, bridging to a tool-bearing MCP server (e.g., a filesystem server that can read files).
2. The victim visits an attacker-controlled webpage (`evil.com`).
3. That page silently opens a WebSocket connection to `ws://127.0.0.1:18081/ws` on the victim's own computer.
4. The attacker now controls that connection and sends commands through it: "read this file," "run this command," etc.
5. The local tool obeys and sends the result back over the WebSocket.
6. The attacker's page receives the content and ships it off to their own server.

### What the attacker gets

Full remote control of whatever the local tool can do, using the victim's privileges. Files read, shell commands run, private keys stolen.

### Simple analogy

It's like leaving your house's front door unlocked and not checking who enters. A malicious website is like a con artist who convinces your browser to walk into your house while you're looking at the website, and walk out with your valuables.

### Simple defense

- Turn on `--apiKey` (the attacker can't authenticate).
- Validate `Origin` so only local/trusted pages can connect.
- Bind to loopback only so the port isn't reachable from the network.

---

## Summary table

| ID | What it does | How it's triggered | What the attacker gets |
|----|-------------|-------------------|------------------------|
| SGW-2026-001 | Crashes the whole gateway | One HTTP request with a magic session ID like `toString` | Denial of service — everything dies |
| SGW-2026-002 | Lets any website talk to your local tools | Victim visits a malicious page; browser opens a WebSocket to localhost | Remote control of local files/tools/data |

Both were verified against supergateway **4.2.2**. Both are fixed by enabling authentication (`--apiKey`) and/or not exposing the port to the open network.

---

## GHSA submission record

| Research ID | GHSA ID | Finding | Submitted / Published |
|-------------|---------|---------|----------------------|
| SGW-2026-001 | GHSA-96g7-x7h4-cr9v | Unauthenticated remote DoS via prototype-chain `sessionId` | 2026-11-17T21:04:55Z |
| SGW-2026-002 | GHSA-mw77-x7vj-mfcc | Cross-Site WebSocket Hijacking via missing `Origin` validation | 2026-11-17T21:05:13Z |

Advisories are published under the `Teycir/supergateway` fork (the upstream `supercorp-ai/supergateway` repository could not be written to with the available token). For canonical disclosure, use GitHub's private "Report a vulnerability" flow addressed to the upstream maintainer @Nedomas, referencing upstream PR #178 as prior art for the fix shape.
