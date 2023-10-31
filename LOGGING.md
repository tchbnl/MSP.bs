Postfix doesn't log email subjects by default. You can enable it by following these steps.

Uncomment or add this line to the main Postfix configuration file:

```
header_checks = regexp:/etc/postfix/header_checks
```

Then create or edit that file and add to it:

```
/^Subject:/ WARN
```

And then reload or restart Postfix. TADA! You'll now see the subject line logged with the rest of the stuff:

```
Oct 31 01:42:35 cwp postfix/cleanup[5405]: 2B2AA41FBC: warning: header Subject: WHY NOT BUY GREG HE IS A VERY NICE LIZARD? from localhost[127.0.0.1]; from=<hello@cwpsite.tchbnl.net> to=<email@example.com> proto=ESMTP helo=<localhost>
```
