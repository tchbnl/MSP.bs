MSP.bs is a mail server log parser written in Bash. It's modeled after cPanel's excellent MSP.

Right now there's ready-ish support for Postfix and a WIP version for Exim that I'm too ashamed to share. It currently implements the two "main" features most people tend to use MSP for, checking sender stats and RBLs. Here's what it looks like:

```
[root@cwp ~]# MSP.bs --auth
Getting cool Postfix facts...

📨 Queue Size: 7
There's nothing else to show here. Have a llama: 🦙

🔑 Authenticated Senders
      6 no-reply@cwpsite.tchbnl.net
      3 hello@cwpsite.tchbnl.net

🧔 User Senders
      9 root
      1 cwpsite

💌 The Usual Subjects™
      2 Test email
      1 Testing stuff
      1 "Now with quotes!"
      1 New from ScamCo!
      1 HI ITS GREG AGAIN DID YOU WANT THE LIZARD OR NOT?
```

```
[root@cwp ~]# MSP.bs --rbl
Running RBL checks...

5.161.207.83
        b.barracudacentral.org  GOOD
        bl.spamcop.net          GOOD
        dnsbl.sorbs.net         GOOD
        spam.dnsbl.sorbs.net    GOOD
        ips.backscatterer.org   GOOD
        zen.spamhaus.org        GOOD
```

MSP.bs was originally written because I needed something like MSP for CWP servers. This is probably the best code to ever run on a CWP server. CWP is horrible. Please do not use it. But feel free to use MSP.bs.
