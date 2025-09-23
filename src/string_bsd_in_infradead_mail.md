# No, lists.infradead.org doesn't run on BSD

So days earlier, I was reading through mails forwarded by
`linux-riscv@lists.infradead.org` as usual, and occasionally opened the RAW mbox
file (an easy action in mutt, just press `e`). Examining the RFC 822 header,
I found there're some strange extension fields starting with `X-CRM114` like

```
X-CRM114-Version: 20100106-BlameMichelson ( TRE 0.8.0 (BSD) ) MR-646709E3
X-CRM114-CacheID: sfid-20250923_043801_252533_90EC9209
X-CRM114-Status: GOOD (  11.31  )
```

and string `TRE 0.8.0 (BSD)` in field `X-CRM114-Version` caught my eyes. As
a Linux distribution maintainer, `BSD` instantly reminded me of distribution
names. And it is definitely ~~a little~~ very striking to see Linux's mailing
list running on BSD systems.

## So I was excited to dig the string further

`CRM114` really doesn't sound like a technology or something. Thus I searched
it in Duckduckgo, and the first result was Wikipedia's page
[CRM 114 (fictional device)](https://en.wikipedia.org/wiki/CRM_114_(fictional_device)).
Although I was not looking for something fictional art works, I still opened the
page and saw a statement of disambiguation,

```
For the computer program, see CRM114 (program).
```

So [CRM114 (program)](https://en.wikipedia.org/wiki/CRM114_(program)) is likely
the origin of these extension RFC 822 fields. And I considered its name
originates from the fictional film, which is confirmed by the page later.

So I learnt `CRM114` is a spam e-mail filter. It makes much sense that such an
anti-spam program had scanned the e-mail I read, permitted it, and left some
fields.

But STFW, I didn't find any materials describing the exact meaning of
`X-CRM114-Version`, thus it really looked like the time to read through the code.

## So I was trying to get CRM114's source

It was a little hard, since as indicated by `20100106` part in field
`X-CRM114-Version`, it seems a project that hasn't been maintained for more than
a decade. Searching `CRM114 source` yielded no useful information.

But while I was looking for some description of `X-CRM114-Version`, I
ocassionally opened its manpage hosted by Debian. As you could see, Debian
requires original source of the package to be provided along with its control
scripts, which makes it very likely a place that I could get a recent enough
version (`20100106`, exactly matching `X-CRM114-Version` produced by
`lists.infradead.org`) of `CRM114`'s source.

## So I was reading through the code of CRM114

`grep -R X-CRM114-Version .` resulted in many lines, and I was most interested
in ones with suffix `.crm`. Some looks like RAW content, and I noticed one
interesting result in `paolo_ov2.crm`,

```
X-CRM114-Version: 20050415.BlameTheIRS ( TRE 0.7.2 (GPL) ) MF-A10FFB4C\n
```

an alternative value of string "BSD" in `X-CRM114-Version` isn't `Linux`, but
instead, `GPL`. Now I realized it's probably a license identifier, instead of
indicaion of the host system. But I wanted to make sure.

Aside from ones looking like RAW RFC 822 content, I chose `mailfilter.crm`,
which refers to `X-CRM114-Version` in form of

```
call /:mungmail_add:/ [X-CRM114-Version: :*:_crm_version: MF-:*:_pgm_hash: ]
# syscall (:*:_dw:) (:_dw:) /formail -A "X-CRM114-Version: :*:_crm_version: MF-:*:_pgm_hash: " -A "X-CRM114-Status: Good  ( :*:pr: \)"/
call /:mungmail_add:/ [X-CRM114-Version: :*:_crm_version: MF-:*:_pgm_hash: [:*:pr:]]
```

So I turned to grep `_crm_version`, it's referred in `crm_var_hash_table.c` as

```
  //   put the version string in as a variable.
  {
    char verstr[1025];
    verstr[0] = 0;
    strcat (verstr, VERSION);
    strcat (verstr, " ( ");
    strcat (verstr, crm_regversion());
    strcat (verstr, " )");
    crm_set_temp_var (":_crm_version:", verstr);
  };
```

So it became more clear, `.crm` files are some types of scripts, which may make
use of variables, and `_crm_version` is a preset variable that contains the
string I found earlier.

You see, the interesting part of `X-CRM114-Version` is inside a pair of braces,
so `crm_regversion` is what I was really looking for. It's defined as

```
char *crm_regversion ()
{
  return (tre_version());
};
```

I was pretty sure I had seen `tre` when looking for CRM114's source tarball in
Debian's package tracker. And yes, Debian
[describes it as](https://packages.debian.org/sid/libtre5)

```
regexp matching library with approximate matching
```

## So I was grepping a regex engine

I was able to find the definition of `tre_version()` in `lib/tre-compile.c`, it
looks like

```
char *
tre_version(void)
{
  static char str[256];
  char *version;

  if (str[0] == 0)
    {
      (void) tre_config(TRE_CONFIG_VERSION, &version);
      (void) snprintf(str, sizeof(str), "TRE %s (BSD)", version);
    }
  return str;
}
```

so the string `BSD` in `X-CRM114-Version` definitely has nothing to do with the
host OS.

In the `NEWS` file of TRE, I found an entry mentioning TRE used to licensed
under LGPL, not BSD,

```
Version 0.7.6
  - The license is changed from LGPL to a BSD-style license.  The new
    license is essentially the same as the "2 clause" BSD-style
    license used in NetBSD.  See the file LICENSE for details.
```

which also explains the `TRE 0.7.2 (GPL)` string I had seen earlier. TRE 0.7.2
was still licensed under LGPL. I am (not) really sorry for the bad title.

## So doesn't lists.infradead.org run on BSD?

Honestly saying, I don't know, even after spending my breakfast time grepping
through all these decade-old source tarballs.

The good news is that, at least the `X-CRM114-Version` field doesn't provide any
information on the host system.

The bad news is that, I haven't had any clues that `lists.infradead.org` runs on
Linux, not Windoge, *BSD or MacOS, either.

As a Linux kernel developer, I really hopes it's Linux. Or it'll really be a
breaking news.
